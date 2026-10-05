// lib/presentation/notifications/widgets/notif_banner_listener.dart
import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/notifications/app_badge_sync_service.dart';
import 'package:thix_id/services/notifications/notification_catalog.dart';
import 'package:thix_id/services/notifications/push_fcm_service.dart';

class NotifBannerListener extends StatefulWidget {
  final Widget child;
  const NotifBannerListener({super.key, required this.child});

  @override
  State<NotifBannerListener> createState() => _NotifBannerListenerState();
}

class _NotifBannerListenerState extends State<NotifBannerListener> {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<SectionBadgeCounts>? _countsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;
  StreamSubscription<Map<String, dynamic>>? _pushSub;

  String? _uid;
  bool _firstLoad = true;
  final LinkedHashMap<String, bool> _seen = LinkedHashMap();

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      _bind(s.session?.user.id);
    });
    _bind(Supabase.instance.client.auth.currentUser?.id);
  }

  void _bind(String? uid) {
    if (uid == _uid) return;
    _unsubscribe();
    _uid = uid;
    _firstLoad = true;
    _seen.clear();

    if (uid == null) {
      AppBadgeSyncService.sync(0);
      return;
    }

    // 1) Compteurs → badge icône, partout dans l'app
    _countsSub = NotificationCountersService().streamCounts(uid).listen((c) {
      AppBadgeSyncService.sync(c.total);
    });

    // 2) Flux notifications → bannière in-app
    _notifSub = NotificationService().streamForUser(uid).listen(_onList);

    // 3) Push foreground → bannière in-app
    _pushSub = PushFcmService.instance.foregroundStream.listen(_onPush);
  }

  void _unsubscribe() {
    _countsSub?.cancel();
    _notifSub?.cancel();
    _pushSub?.cancel();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _unsubscribe();
    super.dispose();
  }

  void _onList(List<Map<String, dynamic>> list) {
    if (_firstLoad) {
      _firstLoad = false;
      for (final n in list) {
        _remember(n['id']?.toString());
      }
      return;
    }
    // La plus récente non lue et jamais vue
    for (final n in list) {
      final id = n['id']?.toString() ?? '';
      if (id.isEmpty || _seen.containsKey(id)) continue;
      _remember(id);
      if (n['read'] == true) continue;
      final created = DateTime.tryParse(n['created_at']?.toString() ?? '');
      if (created == null ||
          DateTime.now().difference(created) > const Duration(minutes: 2)) {
        continue;
      }
      _showBanner(n);
      break; // une bannière à la fois
    }
  }

  void _onPush(Map<String, dynamic> data) {
    final id = data['notification_id']?.toString() ??
        data['id']?.toString() ??
        '${DateTime.now().millisecondsSinceEpoch}';
    if (_seen.containsKey(id)) return;
    _remember(id);
    _showBanner({
      'id': id,
      'title': data['title'] ?? 'THIX',
      'body': data['body'] ?? '',
      'type': data['type'],
      'route': data['route'],
      'read': false,
    });
  }

  void _remember(String? id) {
    if (id == null || id.isEmpty) return;
    _seen[id] = true;
    if (_seen.length > 200) _seen.remove(_seen.keys.first);
  }

  void _showBanner(Map<String, dynamic> n) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopBanner(
        notif: n,
        onDismiss: () => entry.remove(),
        onOpen: () {
          entry.remove();
          final route = n['route']?.toString();
          final id = n['id']?.toString();
          if (id != null && _uid != null) {
            NotificationService().markRead(uid: _uid!, notificationId: id);
          }
          if (route != null && route.isNotEmpty && mounted) {
            context.push(route);
          }
        },
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ============================================================================
// BANNIÈRE SLIDE-DOWN (Overlay racine)
// ============================================================================
class _TopBanner extends StatefulWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  const _TopBanner({
    required this.notif,
    required this.onDismiss,
    required this.onOpen,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
    _auto = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    _auto?.cancel();
    if (!mounted) return;
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = notifMeta(widget.notif['type']?.toString());
    final title = widget.notif['title']?.toString() ?? 'THIX';
    final body = widget.notif['body']?.toString() ?? '';
    final top = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onOpen,
            onHorizontalDragEnd: (d) => _dismiss(),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: meta.color.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: meta.color.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: meta.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: ThixPolicy.textMain)),
                        if (body.isNotEmpty)
                          Text(body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: ThixPolicy.textSecondary,
                                  height: 1.3)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: ThixPolicy.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
