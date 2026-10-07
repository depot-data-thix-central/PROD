// lib/services/notifications/app_badge_sync_service.dart
//
// AppBadgeSyncService v2 — Badge d'icône synchronisé (iOS + Android)
//
// ✅ Remplace app_badge_plus par flutter_app_badger (meilleure compatibilité OEM)
// ✅ Fix: AndroidInitializationSettings utilise 'notification_icon' (res/drawable)
//        au lieu de '@mipmap/ic_launcher' qui n'est PAS supporté par le plugin
// ✅ Synchronisation auto depuis Supabase Realtime + polling fallback
// ✅ Déduplication pour éviter le spam de mises à jour
// ✅ Safe Web : toutes les méthodes sont no-op sur Web
// ✅ Cleanup propre avec cancel du stream Realtime

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
  /// qui ne supportent pas nativement le badge via ShortcutBadger
  static const int _kSummaryId = 999999;
  static const String _kChannelId = 'thix_badge_sync_v2';

  /// Stream Realtime Supabase pour les notifications non lues
  static RealtimeChannel? _realtimeChannel;
  static StreamSubscription<List<Map<String, dynamic>>>? _streamSub;
  static Timer? _pollingTimer;
  static bool _isListening = false;

  // ═══════════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════════

  /// Initialise le plugin de notifications locales (nécessaire pour le badge Android).
  ///
  /// **Important** : Utilise `'notification_icon'` (fichier dans res/drawable/)
  /// et NON `'@mipmap/ic_launcher'` qui n'est pas supporté par
  /// flutter_local_notifications et cause un crash silencieux.
  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);

      // Créer le channel silencieux pour le badge Android
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

      // Android 13+ : demander la permission notifications
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

  /// Met à jour le badge partout (iOS natif + Android launchers compatibles).
  ///
  /// Sur Android, si le launcher ne supporte pas le badge natif,
  /// une notification-résumé silencieuse avec `number` est affichée
  /// comme fallback visuel.
  static Future<void> sync(int count) async {
    final safe = count < 0 ? 0 : count;
    if (safe == _lastCount) return; // Évite le spam
    _lastCount = safe;

    if (kIsWeb) return;
    await init();

    // 1) Badge natif via flutter_app_badger (iOS + Samsung, LG, Huawei, Xiaomi, Oppo…)
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

    // 2) Android fallback : notification-résumé silencieuse portant `number`
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

  /// Démarre l'écoute des notifications non lues depuis Supabase.
  ///
  /// Utilise Realtime PostgreSQL avec fallback polling toutes les 10s
  /// si le canal Realtime échoue ou se déconnecte.
  ///
  /// ```dart
  /// // À appeler après authentification réussie
  /// await AppBadgeSyncService.startListening(userId);
  /// ```
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

      _streamSub = _realtimeChannel!
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

  /// Arrête l'écoute et nettoie toutes les ressources.
  ///
  /// ```dart
  /// // À appeler au logout
  /// AppBadgeSyncService.stopListening();
  /// ```
  static void stopListening() {
    _streamSub?.cancel();
    _streamSub = null;
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

  /// Rafraîchit le badge en comptant les notifications non lues en DB.
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

  /// Fallback polling si Realtime échoue.
  static void _startPolling(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshFromDb(userId),
    );
    debugPrint('[BadgeSync] 🔄 Polling started (10s interval)');
  }

  /// Masque un UID pour les logs (RGPD).
  static String _maskUid(String uid) {
    if (uid.length <= 8) return '***';
    return '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS PUBLICS
  // ═══════════════════════════════════════════════════════════════

  /// Force un rafraîchissement immédiat du badge depuis la DB.
  ///
  /// Utile après avoir marqué des notifications comme lues
  /// ou supprimé des notifications depuis le hub.
  static Future<void> refreshNow() async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      await sync(0);
      return;
    }
    await _refreshFromDb(uid);
  }

  /// Nettoie tout : arrête l'écoute, reset le badge, dispose le plugin.
  ///
  /// À appeler au logout complet.
  static Future<void> dispose() async {
    stopListening();
    await sync(0);
    _lastCount = -1;
    _initialized = false;
    debugPrint('[BadgeSync] 🗑️ Disposed');
  }
}
