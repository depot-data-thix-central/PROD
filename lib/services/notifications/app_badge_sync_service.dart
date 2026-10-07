// lib/services/notifications/app_badge_sync_service.dart
//
// AppBadgeSyncService v2.1 — Badge d'icône synchronisé (iOS + Android)
//
// ✅ FIX BUILD WEB : Supprimé _streamSub (type mismatch RealtimeChannel vs StreamSubscription)
// ✅ Cleanup Realtime via removeChannel() uniquement
// ✅ Remplace app_badge_plus par flutter_app_badger (meilleure compatibilité OEM)
// ✅ Fix: AndroidInitializationSettings utilise 'notification_icon' (res/drawable)
// ✅ Synchronisation auto depuis Supabase Realtime + polling fallback
// ✅ Déduplication pour éviter le spam de mises à jour
// ✅ Safe Web : toutes les méthodes sont no-op sur Web

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_config.dart';

class AppBadgeSyncService {
  AppBadgeSyncService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _lastCount = -1;

  /// Notification-résumé silencieuse qui porte le compteur pour les launchers Android
  static const int _kSummaryId = 999999;
  static const String _kChannelId = 'thix_badge_sync_v2';

  // ✅ FIX : Plus de _streamSub. Le channel Realtime se nettoie via removeChannel().
  static RealtimeChannel? _realtimeChannel;
  static Timer? _pollingTimer;
  static bool _isListening = false;

  // ═══════════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════════

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          'Compteur THIX',
          description: 'Maintient le badge chiffré sur l\'icône de l\'application',
          importance: Importance.min,
          showBadge: true,
        ),
      );

      await android?.requestNotificationsPermission();

      _initialized = true;
      debugPrint('[BadgeSync] ✓ Initialized');
    } catch (e) {
      debugPrint('[BadgeSync] ❌ init: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SYNCHRONISATION DU BADGE
  // ═══════════════════════════════════════════════════════════════

  static Future<void> sync(int count) async {
    final safe = count < 0 ? 0 : count;
    if (safe == _lastCount) return;
    _lastCount = safe;

    if (kIsWeb) return;
    await init();

    // 1) Badge natif via flutter_app_badger
    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (supported) {
        if (safe == 0) {
          FlutterAppBadger.removeBadge();
        } else {
          FlutterAppBadger.updateBadgeCount(safe);
        }
      }
    } catch (e) {
      debugPrint('[BadgeSync] ⚠️ AppBadger: $e');
    }

    // 2) Android fallback : notification-résumé silencieuse
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (safe == 0) {
          await _plugin.cancel(_kSummaryId);
        } else {
          await _plugin.show(
            _kSummaryId,
            'THIX Hub',
            safe == 1 ? '1 notification non lue' : '$safe notifications non lues',
            NotificationDetails(
              android: AndroidNotificationDetails(
                _kChannelId,
                'Compteur THIX',
                channelDescription:
                    'Maintient le badge chiffré sur l\'icône de l\'application',
                importance: Importance.min,
                priority: Priority.min,
                silent: true,
                playSound: false,
                enableVibration: false,
                onlyAlertOnce: true,
                showWhen: false,
                number: safe,
              ),
            ),
            payload: 'badge_summary',
          );
        }
      } catch (e) {
        debugPrint('[BadgeSync] ❌ summary: $e');
      }
    }

    debugPrint('[BadgeSync] 🔢 Icon badge → $safe');
  }

  // ═══════════════════════════════════════════════════════════════
  // ÉCOUTE REALTIME SUPABASE
  // ═══════════════════════════════════════════════════════════════

  static Future<void> startListening(String userId) async {
    if (_isListening || kIsWeb) return;
    if (userId.isEmpty) return;

    _isListening = true;
    debugPrint('[BadgeSync] 🎧 Start listening for user ${_maskUid(userId)}');

    // Charger le compte initial immédiatement
    await _refreshFromDb(userId);

    // Essayer Realtime d'abord
    try {
      _realtimeChannel = SupabaseConfig.client.channel('badge_sync:$userId');

      // ✅ FIX : .subscribe() retourne RealtimeChannel, pas StreamSubscription.
      // On ne stocke PAS le résultat. Le cleanup se fait via removeChannel().
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => _refreshFromDb(userId),
          )
          .subscribe((status, [err]) {
            if (status == RealtimeSubscribeStatus.closed || err != null) {
              debugPrint('[BadgeSync] ⚠️ Realtime closed/error, starting polling');
              _startPolling(userId);
            }
          });
    } catch (e) {
      debugPrint('[BadgeSync] ⚠️ Realtime failed, starting polling: $e');
      _startPolling(userId);
    }
  }

  static void stopListening() {
    // ✅ FIX : Plus de _streamSub?.cancel() — le type était incorrect.
    _pollingTimer?.cancel();
    _pollingTimer = null;

    if (_realtimeChannel != null) {
      try {
        SupabaseConfig.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }

    _isListening = false;
    debugPrint('[BadgeSync] 🛑 Stopped listening');
  }

  static Future<void> _refreshFromDb(String userId) async {
    try {
      final count = await SupabaseConfig.client
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('is_read', false)
          .timeout(const Duration(seconds: 10));

      await sync(count);
    } catch (e) {
      debugPrint('[BadgeSync] ❌ Refresh from DB failed: $e');
    }
  }

  static void _startPolling(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshFromDb(userId),
    );
    debugPrint('[BadgeSync] 🔄 Polling started (10s interval)');
  }

  static String _maskUid(String uid) {
    if (uid.length <= 8) return '***';
    return '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS PUBLICS
  // ═══════════════════════════════════════════════════════════════

  static Future<void> refreshNow() async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      await sync(0);
      return;
    }
    await _refreshFromDb(uid);
  }

  static Future<void> dispose() async {
    stopListening();
    await sync(0);
    _lastCount = -1;
    _initialized = false;
    debugPrint('[BadgeSync] 🗑️ Disposed');
  }
}
