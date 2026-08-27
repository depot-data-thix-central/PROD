// lib/presentation/thix_sos/widgets/global_sos_listener.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

import '../pages/chambre_crise_secours_page.dart';

/// Monté une seule fois dans main.dart.
/// - SOS déclenché et je suis cercle 1 → ouvre auto la chambre de crise (foreground)
///   ou affiche une notification locale (background).
/// - Tap sur une notification sos_crisis:* → ouvre la chambre.
class GlobalSosListener extends StatefulWidget {
  final Widget child;
  const GlobalSosListener({super.key, required this.child});

  @override
  State<GlobalSosListener> createState() => _GlobalSosListenerState();
}

class _GlobalSosListenerState extends State<GlobalSosListener> {
  RealtimeChannel? _ch;
  final Set<String> _handled = {};
  void Function(String?)? _prevTap;

  @override
  void initState() {
    super.initState();
    _wrapNotificationTap();
    _subscribe();
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    LocalNotificationService.instance.onNotificationTap = _prevTap;
    super.dispose();
  }

  // Chaîne le tap de notification sans casser celui du chat
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

  void _subscribe() {
    final myId = SupabaseConfig.currentUser?.id;
    if (myId == null) return;

    _ch = Supabase.instance.client
        .channel('global_sos_listener_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thix_sos_events',
          callback: (payload) {
            final rec = payload.newRecord;
            final type = (rec['type'] ?? '').toString();
            if (type != 'SOS_STARTED') return;

            final meta = Map<String, dynamic>.from(
              (rec['payload'] as Map?) ?? {},
            );
            final circle1 = (meta['circle1_user_ids'] as List? ?? [])
                .map((e) => e.toString())
                .toList();
            if (!circle1.contains(myId)) return;

            final incidentId = (rec['incident_id'] ?? '').toString();
            final victimId = (meta['victim_id'] ?? '').toString();
            final publicId = (meta['public_id'] ?? 'SOS').toString();
            if (incidentId.isEmpty || !_handled.add(incidentId)) return;

            final foreground =
                WidgetsBinding.instance.lifecycleState ==
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
