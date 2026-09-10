// lib/presentation/thix_sos/widgets/global_sos_listener.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

import '../pages/chambre_crise_secours_page.dart';

/// SOS_STARTED + je suis dans les user_ids → ouvre la chambre secours.
class GlobalSosListener extends StatefulWidget {
  final Widget child;
  const GlobalSosListener({super.key, required this.child});

  @override
  State<GlobalSosListener> createState() => _GlobalSosListenerState();
}

class _GlobalSosListenerState extends State<GlobalSosListener>
    with WidgetsBindingObserver {
  RealtimeChannel? _ch;
  StreamSubscription<AuthState>? _authSub;
  final Set<String> _handled = {};
  void Function(String?)? _prevTap;
  String? _subscribedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wrapNotificationTap();
    _subscribe();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _subscribe();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _ch?.unsubscribe();
    LocalNotificationService.instance.onNotificationTap = _prevTap;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _subscribe();
    }
  }

  void _wrapNotificationTap() {
    final svc = LocalNotificationService.instance;
    _prevTap = svc.onNotificationTap;
    svc.onNotificationTap = (payload) {
      if (payload != null && payload.startsWith('sos_crisis:')) {
        final parts = payload.split(':');
        if (parts.length >= 3) {
          _openCrisis(parts[1], parts[2]);
          return;
        }
      }
      _prevTap?.call(payload);
    };
  }

  List<String> _ids(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  void _subscribe() {
    final myId = SupabaseConfig.currentUser?.id;
    if (myId == null || myId.isEmpty) {
      _ch?.unsubscribe();
      _ch = null;
      _subscribedFor = null;
      return;
    }
    if (_subscribedFor == myId && _ch != null) return;

    _ch?.unsubscribe();
    _subscribedFor = myId;

    _ch = Supabase.instance.client
        .channel('global_sos_listener_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thix_sos_events',
          callback: (payload) {
            final rec = payload.newRecord;
            final type = (rec['type'] ?? rec['event_type'] ?? '').toString();
            if (type != 'SOS_STARTED') return;

            final rawMeta = rec['payload'] ?? rec['metadata'];
            final meta = rawMeta is Map
                ? Map<String, dynamic>.from(rawMeta)
                : <String, dynamic>{};

            final circle1 = _ids(meta['circle1_user_ids']);
            final all = _ids(meta['all_user_ids']);
            if (!circle1.contains(myId) && !all.contains(myId)) return;

            final incidentId = (rec['incident_id'] ?? '').toString();
            final victimId = (meta['victim_id'] ?? '').toString();
            final publicId = (meta['public_id'] ?? 'SOS').toString();
            if (incidentId.isEmpty || !_handled.add(incidentId)) return;

            final foreground = WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed;

            if (foreground) {
              _openCrisis(incidentId, victimId);
            } else {
              LocalNotificationService.instance.show(
                id: incidentId.hashCode & 0x7fffffff,
                title: '🚨 SOS — $publicId',
                body: 'Ouvrir la chambre de crise pour piloter les secours',
                payload: 'sos_crisis:$incidentId:$victimId',
              );
            }
          },
        )
        .subscribe();
  }

  void _openCrisis(String incidentId, String victimUserId) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => ChambreCriseSecoursPage(
          incidentId: incidentId,
          victimUserId: victimUserId.isEmpty ? null : victimUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
