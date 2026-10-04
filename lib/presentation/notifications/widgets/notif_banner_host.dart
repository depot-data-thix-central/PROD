import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/services/notifications/push_fcm_service.dart';
import 'package:thix_id/services/notifications/notification_catalog.dart';
import '../notification_providers.dart';

/// Overlay global : bannière slide-in à chaque notification entrante
/// (realtime DB ou push foreground). À placer UNE fois dans le shell racine.
class NotifBannerHost extends ConsumerStatefulWidget {
  final Widget child;
  const NotifBannerHost({super.key, required this.child});
  @override
  ConsumerState<NotifBannerHost> createState() => _NotifBannerHostState();
}

class _NotifBannerHostState extends ConsumerState<NotifBannerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  final Set<String> _seen = {};
  StreamSubscription? _pushSub;
  Map<String, dynamic>? _current;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _pushSub = PushFcmService.instance.foregroundStream.listen(_show);
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _hideTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _show(Map<String, dynamic> n) {
    final id = n['id']?.toString() ?? n['notification_id']?.toString() ?? '';
    if (id.isEmpty || _seen.contains(id)) return;
    _seen.add(id);
    if (!mounted) return;
    setState(() => _current = n);
    _ctrl.forward();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Détecte aussi les inserts realtime (nouvel id non vu)
    ref.listen(notificationsStreamProvider, (prev, next) {
      final list = next.valueOrNull;
      if (list == null || list.isEmpty) return;
      final newest = list.first;
      if (newest['read'] == true) return;
      final created = DateTime.tryParse(newest['created_at']?.toString() ?? '');
      if (created == null || DateTime.now().difference(created) > const Duration(minutes: 2)) return;
      _show(newest);
    });

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: SlideTransition(
              position: _slide,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Opacity(opacity: _ctrl.value.clamp(0.0, 1.0), child: _banner()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    final n = _current;
    if (n == null) return const SizedBox.shrink();
    final meta = notifMeta(n['type']?.toString());
    final title = n['title']?.toString() ?? 'THIX';
    final body = n['body']?.toString() ?? '';
    final route = n['route']?.toString();

    return GestureDetector(
      onTap: () {
        _ctrl.reverse();
        if (route != null && route.isNotEmpty) context.push(route);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: meta.color.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 6))],
          border: Border.all(color: meta.color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: meta.color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(meta.icon, color: meta.color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: ThixPolicy.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (body.isNotEmpty) Text(body, style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
