import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'notification_catalog.dart';
import 'notification_providers.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  static const _cats = ['all', 'network', 'messages', 'market', 'money', 'system'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _cats.length, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  String _dayLabel(DateTime d, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return l10n.t('notif_today');
    if (day == today.subtract(const Duration(days: 1))) return l10n.t('notif_yesterday');
    return DateFormat('dd MMM yyyy', Localizations.localeOf(context).languageCode).format(d);
  }

  String _timeAgo(DateTime d, AppLocalizations l10n) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return l10n.t('notif_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stream = ref.watch(notificationsStreamProvider);
    final unread = ref.watch(unreadTotalProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: Row(
          children: [
            Text(l10n.t('notif_hub_title'), style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 18, color: ThixPolicy.textMain)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(10)),
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ],
        ),
        iconTheme: IconThemeData(color: ThixPolicy.textMain),
        actions: [
          IconButton(
            tooltip: l10n.t('notif_mark_all'),
            icon: const Icon(Icons.done_all_rounded),
            onPressed: unread == 0 ? null : () => markAllNotifRead(ref),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textMuted,
          indicatorColor: ThixPolicy.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [for (final c in _cats) Tab(text: kCategoryLabels[c] ?? c)],
        ),
      ),
      body: stream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final byCat = ref.watch(notifByCategoryProvider);
          return TabBarView(
            controller: _tab,
            children: [
              for (final c in _cats)
                _buildList(c == 'all' ? all : (byCat[c] ?? const []), l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, AppLocalizations l10n) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none_rounded, size: 56, color: ThixPolicy.textDisabled),
          const SizedBox(height: 12),
          Text(l10n.t('notif_empty'), style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted)),
        ]),
      );
    }

    // Groupes par jour
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final n in items) {
      final d = DateTime.tryParse(n['created_at']?.toString() ?? '')?.toLocal();
      if (d == null) continue;
      groups.putIfAbsent(_dayLabel(d, l10n), () => []).add(n);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Text(entry.key, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMuted, letterSpacing: 0.6)),
          ),
          Container(
            decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(18), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03)),
            child: Column(
              children: [
                for (int i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: ThixPolicy.border.withOpacity(0.4), indent: 68),
                  _NotifTile(
                    notif: entry.value[i],
                    timeAgo: _timeAgo(
                        DateTime.tryParse(entry.value[i]['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
                        l10n),
                    onTap: () async {
                      await markNotifRead(ref, entry.value[i]['id'].toString());
                      final route = entry.value[i]['route']?.toString();
                      if (route != null && route.isNotEmpty && mounted) context.push(route);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final String timeAgo;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.timeAgo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = notif['type']?.toString() ?? 'system';
    final meta = notifMeta(type);
    final data = (notif['data'] is Map) ? Map<String, dynamic>.from(notif['data'] as Map) : const <String, dynamic>{};
    final actorName = data['actor_name']?.toString();
    final avatar = data['actor_avatar']?.toString();
    final title = notif['title']?.toString() ?? '';
    final body = notif['body']?.toString() ?? '';
    final isRead = notif['read'] == true;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: meta.color.withOpacity(0.12), shape: BoxShape.circle),
                  child: avatar != null && avatar.isNotEmpty
                      ? ClipOval(child: CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(meta.icon, color: meta.color, size: 20)))
                      : Icon(meta.icon, color: meta.color, size: 20),
                ),
                if (!isRead)
                  Positioned(right: 0, top: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actorName != null && actorName.isNotEmpty ? '$actorName • $title' : title,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 13.5, color: ThixPolicy.textMain),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(body, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(timeAgo, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
