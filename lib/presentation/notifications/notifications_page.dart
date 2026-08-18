// lib/presentation/notifications/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/notification/app_notification.dart';
import 'package:thix_id/presentation/common/providers/notification_provider.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _iconFor(String key) {
    switch (key) {
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'money':
        return Icons.account_balance_wallet_rounded;
      case 'live':
        return Icons.live_tv_rounded;
      case 'opportunity':
        return Icons.work_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'market':
        return Icons.storefront_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final uid = SupabaseConfig.currentUser?.id;
    final service = ref.read(notificationServiceProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => service.markAllRead(uid),
              child: const Text('Tout marquer lu',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucune notification pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ThixPolicy.textMuted),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = items[i];
              return _NotificationTile(
                notification: n,
                icon: _iconFor(n.iconKey),
                timeLabel: _timeAgo(n.createdAt),
                onTap: () {
                  if (uid != null && !n.read) {
                    service.markRead(uid: uid, notificationId: n.id);
                  }
                  // TODO: router vers n.data['route'] si présent
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final String timeLabel;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    return Material(
      color: unread ? const Color(0xFFEFF6FF) : ThixPolicy.card,
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(ThixPolicy.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(
              color: unread ? ThixPolicy.primary.withOpacity(0.25) : ThixPolicy.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: ThixPolicy.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: const TextStyle(fontSize: 10, color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: ThixPolicy.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
