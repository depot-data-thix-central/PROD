// lib/presentation/common/notifications_sheet.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/theme.dart';

class NotificationsSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationsSheetBody(),
    );
  }
}

// =============================================================================
// FALLBACK DE CONTENU — pour les notifications sans title/body (anciennes
// données, ou notifs créées directement en SQL / par un module qui n'a pas
// encore rempli ces champs).
// =============================================================================

class _NotificationDisplay {
  final String title;
  final String body;
  final IconData icon;
  final Color accent;

  const _NotificationDisplay({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });
}

_NotificationDisplay _displayFor({
  required String type,
  required String? rawTitle,
  required String? rawBody,
  required Map<String, dynamic> extra,
}) {
  final hasTitle = rawTitle != null && rawTitle.trim().isNotEmpty;
  final hasBody = rawBody != null && rawBody.trim().isNotEmpty;

  switch (type) {
    case 'like':
      return _NotificationDisplay(
        title: hasTitle ? rawTitle : 'Nouveau j’aime',
        body: hasBody ? rawBody : 'Quelqu’un a aimé votre publication.',
        icon: Icons.favorite_rounded,
        accent: const Color(0xFFEF4444),
      );
    case 'follow':
      return _NotificationDisplay(
        title: hasTitle ? rawTitle : 'Nouvel abonné',
        body: hasBody ? rawBody : 'Quelqu’un a commencé à vous suivre.',
        icon: Icons.person_add_rounded,
        accent: const Color(0xFF6366F1),
      );
    case 'connection':
      return _NotificationDisplay(
        title: hasTitle ? rawTitle : 'Demande de connexion',
        body: hasBody ? rawBody : 'Quelqu’un souhaite se connecter avec vous.',
        icon: Icons.people_alt_rounded,
        accent: const Color(0xFF8B5CF6),
      );
    case 'comment':
      return _NotificationDisplay(
        title: hasTitle ? rawTitle : 'Nouveau commentaire',
        body: hasBody ? rawBody : 'Quelqu’un a commenté votre publication.',
        icon: Icons.mode_comment_rounded,
        accent: const Color(0xFF0EA5E9),
      );
    case 'chat':
    case 'message':
      return _NotificationDisplay(
        title: hasTitle ? rawTitle : 'Nouveau message',
        body: hasBody ? rawBody : 'Vous avez reçu un message.',
        icon: Icons.chat_bubble_rounded,
        accent: LightModeColors.accent,
      );
    case 'access_request':
      final name = (extra['requester_name'] ?? '').toString().trim();
      final thixId = (extra['requester_thix_id'] ?? '').toString().trim();
      final bits = <String>[if (name.isNotEmpty) name, if (thixId.isNotEmpty) thixId];
      return _NotificationDisplay(
        title: hasTitle
            ? (bits.isEmpty ? rawTitle : '$rawTitle — ${bits.join(' · ')}')
            : 'Demande d’accès',
        body: hasBody ? rawBody : 'Une demande d’accès est en attente.',
        icon: Icons.lock_open_rounded,
        accent: const Color(0xFFF59E0B),
      );
    default:
      return _NotificationDisplay(
        title: hasTitle ? rawTitle : 'Notification',
        body: hasBody ? rawBody : '',
        icon: Icons.notifications_rounded,
        accent: LightModeColors.accent,
      );
  }
}

String _timeAgo(dynamic rawCreatedAt) {
  if (rawCreatedAt == null) return '';
  DateTime? dt;
  if (rawCreatedAt is DateTime) {
    dt = rawCreatedAt;
  } else {
    dt = DateTime.tryParse(rawCreatedAt.toString());
  }
  if (dt == null) return '';

  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}

// =============================================================================
// SHEET
// =============================================================================

class _NotificationsSheetBody extends StatefulWidget {
  const _NotificationsSheetBody();

  @override
  State<_NotificationsSheetBody> createState() => _NotificationsSheetBodyState();
}

class _NotificationsSheetBodyState extends State<_NotificationsSheetBody> {
  final _notifications = NotificationService();
  final _counters = NotificationCountersService();
  final _access = AccessRequestService();
  final _profiles = ProfileService();

  bool _markingAll = false;
  bool _autoMarked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoMarked) return;

    final me = context.read<AuthController>().currentUser;
    if (me == null) return;

    _autoMarked = true;
    unawaited(_notifications.markAllRead(me.id));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentUser;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    if (me == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: _SheetShell(
          title: 'Notifications',
          subtitle: null,
          actions: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Connectez-vous pour voir vos notifications.',
                style: context.textStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final countsStream = _counters.streamCounts(me.id);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: StreamBuilder<SectionBadgeCounts>(
        stream: countsStream,
        builder: (context, snap) {
          final counts = snap.data ?? SectionBadgeCounts.zero;
          final total = counts.total;

          return _SheetShell(
            title: 'Notifications',
            subtitle: total > 0 ? '$total non lue${total > 1 ? 's' : ''}' : 'Tout est à jour',
            actions: [
              if (total > 0)
                TextButton(
                  onPressed: _markingAll
                      ? null
                      : () async {
                          setState(() => _markingAll = true);
                          try {
                            await _notifications.markAllRead(me.id);
                          } catch (e) {
                            debugPrint('NotificationsSheet: markAllRead failed → $e');
                          } finally {
                            if (mounted) setState(() => _markingAll = false);
                          }
                        },
                  child: Text(
                    'Tout lire',
                    style: context.textStyles.labelLarge?.copyWith(
                      color: LightModeColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
            child: _ReceptionPanel(
              meId: me.id,
              notifications: _notifications,
              access: _access,
              profiles: _profiles,
              counters: _counters,
              countsStream: countsStream,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// RECEPTION PANEL
// =============================================================================

class _ReceptionPanel extends StatelessWidget {
  final String meId;
  final NotificationService notifications;
  final AccessRequestService access;
  final ProfileService profiles;
  final NotificationCountersService counters;
  final Stream<SectionBadgeCounts> countsStream;

  const _ReceptionPanel({
    required this.meId,
    required this.notifications,
    required this.access,
    required this.profiles,
    required this.counters,
    required this.countsStream,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- CHIPS DE SECTIONS ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 14),
            child: StreamBuilder<SectionBadgeCounts>(
              stream: countsStream,
              builder: (context, snap) {
                final counts = snap.data ?? SectionBadgeCounts.zero;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _SectionChip(
                        icon: Icons.mark_chat_unread_rounded,
                        label: 'Messages',
                        count: counts.messages,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.messages);
                          if (context.mounted) context.push(AppRoutes.chat);
                        },
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        icon: Icons.groups_rounded,
                        label: 'Réseau',
                        count: counts.network,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.network);
                          if (context.mounted) {
                            context.pop();
                            context.push('/network');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        icon: Icons.newspaper_rounded,
                        label: 'Infos',
                        count: counts.info,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.info);
                          if (context.mounted) {
                            context.pop();
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Informations'),
                                content: const Text('Voici les dernières informations importantes.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        icon: Icons.event_available_rounded,
                        label: 'Événements',
                        count: counts.events,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.events);
                          if (context.mounted) context.push(AppRoutes.thixEvent);
                        },
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        icon: Icons.school_rounded,
                        label: 'Formations',
                        count: counts.formations,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.formations);
                          if (context.mounted) context.push(AppRoutes.education);
                        },
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        icon: Icons.lightbulb_rounded,
                        label: 'Opportunités',
                        count: counts.opportunities,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.opportunities);
                          if (context.mounted) context.push(AppRoutes.opportunities);
                        },
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        icon: Icons.work_rounded,
                        label: 'Emploi',
                        count: counts.jobs,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.jobs);
                          if (context.mounted) context.push(AppRoutes.jobs);
                        },
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        icon: Icons.storefront_rounded,
                        label: 'Market',
                        count: counts.market,
                        onTap: () async {
                          await counters.markSectionSeen(uid: meId, section: ThixSection.market);
                          if (context.mounted) context.push(AppRoutes.thixMarket);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ---------- DEMANDES D'ACCÈS ----------
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: access.streamIncomingRequests(ownerId: meId, status: 'pending'),
            builder: (context, snap) {
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: LightModeColors.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.lock_open_rounded, color: LightModeColors.accent, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Demandes d’accès',
                            style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: LightModeColors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${rows.length}',
                            style: context.textStyles.labelLarge?.copyWith(
                              color: const Color(0xFF0A2F5C),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final r in rows) ...[
                      _IncomingAccessRequestCard(
                        requestId: (r['id'] ?? '').toString(),
                        requesterId: (r['requester_id'] ?? '').toString(),
                        createdAt: (r['created_at'] ?? '').toString(),
                        profiles: profiles,
                        onApprove: () async {
                          final id = (r['id'] ?? '').toString();
                          if (id.isEmpty) return;

                          await access.approveFor10Minutes(requestId: id);

                          final requester = (r['requester_id'] ?? '').toString();
                          if (requester.trim().isNotEmpty) {
                            try {
                              final requesterProfile = await profiles.fetchPublicProfileByUserId(requester);
                              await notifications.add(
                                toUid: requester,
                                type: 'access_request',
                                title: 'Accès approuvé',
                                body: 'Votre demande d’accès a été approuvée.',
                                data: {
                                  'request_id': id,
                                  'requester_id': requester,
                                  'requester_name': requesterProfile?.displayName,
                                  'requester_thix_id': requesterProfile?.thixId,
                                  'access_minutes': 10,
                                },
                              );
                            } catch (e) {
                              debugPrint('ReceptionPanel: notify approve failed → $e');
                            }
                          }
                        },
                        onReject: () async {
                          final id = (r['id'] ?? '').toString();
                          if (id.isEmpty) return;

                          await access.setStatus(requestId: id, status: 'rejected');

                          final requester = (r['requester_id'] ?? '').toString();
                          if (requester.trim().isNotEmpty) {
                            try {
                              final requesterProfile = await profiles.fetchPublicProfileByUserId(requester);
                              await notifications.add(
                                toUid: requester,
                                type: 'access_request',
                                title: 'Accès refusé',
                                body: 'Votre demande d’accès a été refusée.',
                                data: {
                                  'request_id': id,
                                  'requester_id': requester,
                                  'requester_name': requesterProfile?.displayName,
                                  'requester_thix_id': requesterProfile?.thixId,
                                },
                              );
                            } catch (e) {
                              debugPrint('ReceptionPanel: notify reject failed → $e');
                            }
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              );
            },
          ),

          // ---------- LISTE DES NOTIFICATIONS ----------
          StreamBuilder<SectionBadgeCounts>(
            stream: countsStream,
            builder: (context, countsSnap) {
              final counts = countsSnap.data ?? SectionBadgeCounts.zero;

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: notifications.streamForUser(meId),
                builder: (context, snap) {
                  final docs = snap.data ?? const <Map<String, dynamic>>[];
                  final synthetic = _syntheticNotificationsFromCounts(counts);
                  final merged = <Map<String, dynamic>>[...synthetic, ...docs];

                  if (snap.connectionState == ConnectionState.waiting && merged.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (merged.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 40,
                            color: context.theme.colorScheme.onSurface.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune notification.',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: LightModeColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: merged.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Theme.of(context).dividerColor,
                      height: 1,
                    ),
                    itemBuilder: (context, i) {
                      final data = merged[i];

                      // Notification synthétique (résumé de section)
                      if ((data['__synthetic'] as bool?) == true) {
                        return _SyntheticNotificationRow(
                          title: (data['title'] ?? 'Notification').toString(),
                          body: (data['body'] ?? '').toString(),
                          type: (data['type'] ?? 'generic').toString(),
                          count: (data['count'] as int?) ?? 0,
                          onTap: () async {
                            await _handleSyntheticTap(
                              context: context,
                              section: (data['section'] ?? '').toString(),
                            );
                          },
                        );
                      }

                      // Notification classique
                      final type = (data['type'] as String?) ?? 'generic';
                      final read = (data['read'] as bool?) ?? false;
                      final extra = (data['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
                      final id = (data['id'] ?? '').toString();
                      final createdAt = data['created_at'];

                      final display = _displayFor(
                        type: type,
                        rawTitle: data['title'] as String?,
                        rawBody: data['body'] as String?,
                        extra: extra,
                      );

                      return _NotificationRow(
                        title: display.title,
                        body: display.body,
                        icon: display.icon,
                        accent: display.accent,
                        read: read,
                        timeLabel: _timeAgo(createdAt),
                        onTap: () {
                          if (id.isEmpty) return;
                          notifications.markRead(uid: meId, notificationId: id);
                        },
                        trailing: type == 'access_request'
                            ? _AccessRequestActions(
                                requestId: extra['request_id'] as String?,
                                requesterId: extra['requester_id'] as String?,
                                targetUserId: extra['target_user_id'] as String?,
                                onApprove: (requestId) async {
                                  await access.approveFor10Minutes(requestId: requestId);
                                  final requesterId = extra['requester_id'] as String?;
                                  if (requesterId != null && requesterId.trim().isNotEmpty) {
                                    try {
                                      await notifications.add(
                                        toUid: requesterId,
                                        type: 'access_request',
                                        title: 'Accès approuvé',
                                        body: 'Votre demande d’accès a été approuvée.',
                                        data: {
                                          'request_id': requestId,
                                          'access_minutes': 10,
                                        },
                                      );
                                    } catch (e) {
                                      debugPrint('NotificationsSheet: notify approve failed → $e');
                                    }
                                  }
                                  if (id.isNotEmpty) {
                                    await notifications.markRead(uid: meId, notificationId: id);
                                  }
                                },
                                onReject: (requestId) async {
                                  await access.setStatus(requestId: requestId, status: 'rejected');
                                  final requesterId = extra['requester_id'] as String?;
                                  if (requesterId != null && requesterId.trim().isNotEmpty) {
                                    try {
                                      await notifications.add(
                                        toUid: requesterId,
                                        type: 'access_request',
                                        title: 'Accès refusé',
                                        body: 'Votre demande d’accès a été refusée.',
                                        data: {'request_id': requestId},
                                      );
                                    } catch (e) {
                                      debugPrint('NotificationsSheet: notify reject failed → $e');
                                    }
                                  }
                                  if (id.isNotEmpty) {
                                    await notifications.markRead(uid: meId, notificationId: id);
                                  }
                                },
                              )
                            : null,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------- HELPERS ----------

  List<Map<String, dynamic>> _syntheticNotificationsFromCounts(SectionBadgeCounts counts) {
    Map<String, dynamic> mk({
      required String section,
      required String type,
      required String title,
      required String body,
      required int count,
    }) {
      return {
        '__synthetic': true,
        'section': section,
        'type': type,
        'title': title,
        'body': body,
        'count': count,
      };
    }

    final out = <Map<String, dynamic>>[];

    if (counts.messages > 0) {
      out.add(mk(
        section: ThixSection.messages.name,
        type: 'message',
        title: 'Nouveaux messages',
        body: 'Vous avez ${counts.messages} message(s) non lu(s).',
        count: counts.messages,
      ));
    }
    if (counts.network > 0) {
      out.add(mk(
        section: ThixSection.network.name,
        type: 'network',
        title: 'Activité réseau',
        body: '${counts.network} nouveauté(s) sur Thix Pro.',
        count: counts.network,
      ));
    }
    if (counts.opportunities > 0) {
      out.add(mk(
        section: ThixSection.opportunities.name,
        type: 'opportunity',
        title: 'Opportunités',
        body: '${counts.opportunities} nouveauté(s) à consulter.',
        count: counts.opportunities,
      ));
    }
    if (counts.jobs > 0) {
      out.add(mk(
        section: ThixSection.jobs.name,
        type: 'job',
        title: 'Emploi',
        body: '${counts.jobs} mise(s) à jour.',
        count: counts.jobs,
      ));
    }
    if (counts.events > 0) {
      out.add(mk(
        section: ThixSection.events.name,
        type: 'event',
        title: 'Événements',
        body: '${counts.events} nouveauté(s) événement.',
        count: counts.events,
      ));
    }
    if (counts.formations > 0) {
      out.add(mk(
        section: ThixSection.formations.name,
        type: 'formation',
        title: 'Formations',
        body: '${counts.formations} mise(s) à jour formation.',
        count: counts.formations,
      ));
    }
    if (counts.info > 0) {
      out.add(mk(
        section: ThixSection.info.name,
        type: 'info',
        title: 'Infos',
        body: '${counts.info} information(s) à lire.',
        count: counts.info,
      ));
    }
    if (counts.market > 0) {
      out.add(mk(
        section: ThixSection.market.name,
        type: 'market',
        title: 'THIX Market',
        body: '${counts.market} mise(s) à jour sur le marché.',
        count: counts.market,
      ));
    }

    return out;
  }

  Future<void> _handleSyntheticTap({
    required BuildContext context,
    required String section,
  }) async {
    try {
      final s = ThixSection.values.firstWhere(
        (e) => e.name == section,
        orElse: () => ThixSection.messages,
      );

      await counters.markSectionSeen(uid: meId, section: s);
      if (!context.mounted) return;

      switch (s) {
        case ThixSection.messages:
          context.push(AppRoutes.chat);
          break;
        case ThixSection.info:
          context.pop();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Informations'),
              content: const Text('Voici les dernières informations importantes.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          break;
        case ThixSection.events:
          context.push(AppRoutes.thixEvent);
          break;
        case ThixSection.formations:
          context.push(AppRoutes.education);
          break;
        case ThixSection.opportunities:
          context.push(AppRoutes.opportunities);
          break;
        case ThixSection.jobs:
          context.push(AppRoutes.jobs);
          break;
        case ThixSection.network:
          context.pop();
          context.push('/network');
          break;
        case ThixSection.market:
          context.pop();
          context.push(AppRoutes.thixMarket);
          break;
        case ThixSection.health:
          context.pop();
          context.push(AppRoutes.thixSante);
          break;
        case ThixSection.money:
          context.pop();
          context.push(AppRoutes.thixMoney);
          break;
        case ThixSection.monPays:
          context.pop();
          context.push(AppRoutes.monPays);
          break;
        case ThixSection.reservation:
          context.pop();
          context.push(AppRoutes.reservation);
          break;
        case ThixSection.media:
          context.pop();
          context.push(AppRoutes.thixMedia);
          break;
        default:
          context.pop();
      }
    } catch (e) {
      debugPrint('NotificationsSheet: synthetic tap failed → $e');
    }
  }
}

// =============================================================================
// WIDGETS DE BASE
// =============================================================================

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasCount = count > 0;
    final cs = context.theme.colorScheme;
    final bg = hasCount ? LightModeColors.accent.withValues(alpha: 0.12) : cs.surfaceContainerHighest;
    final fg = hasCount ? LightModeColors.accent : cs.onSurface.withValues(alpha: 0.7);

    return InkWell(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: hasCount ? LightModeColors.accent.withValues(alpha: 0.35) : cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasCount) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: LightModeColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: context.textStyles.labelSmall?.copyWith(
                    color: const Color(0xFF0A2F5C),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncomingAccessRequestCard extends StatelessWidget {
  final String requestId;
  final String requesterId;
  final String createdAt;
  final ProfileService profiles;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const _IncomingAccessRequestCard({
    required this.requestId,
    required this.requesterId,
    required this.createdAt,
    required this.profiles,
    required this.onApprove,
    required this.onReject,
  });

  // Correction : interpolation Dart standard ($) au lieu de la syntaxe
  // \( ... \) invalide qui produisait littéralement ce texte à l'écran.
  String _short(String v) {
    final t = v.trim();
    if (t.length <= 10) return t;
    return '${t.substring(0, 6)}…${t.substring(t.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: profiles.streamPublicProfileByUserId(requesterId),
      builder: (context, snap) {
        final p = snap.data;
        final name = (p?.displayName ?? '').trim();
        final thixId = (p?.thixId ?? '').trim();
        final header = name.isNotEmpty ? 'Demande de: $name' : 'Demande de: ${_short(requesterId)}';
        final sub = <String>[];
        if (thixId.isNotEmpty) sub.add('THIX ID: $thixId');
        sub.add('UID: ${_short(requesterId)}');

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(header, style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                sub.join(' · '),
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID demande: ${_short(requestId)}',
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.secondaryText,
                  height: 1.4,
                ),
              ),
              if (createdAt.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Reçu: $createdAt',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: LightModeColors.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await onReject();
                        } catch (e) {
                          debugPrint('IncomingAccessRequestCard: reject failed → $e');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LightModeColors.error,
                        side: const BorderSide(color: LightModeColors.error),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await onApprove();
                        } catch (e) {
                          debugPrint('IncomingAccessRequestCard: approve failed → $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightModeColors.accent,
                        foregroundColor: const Color(0xFF0A2F5C),
                        elevation: 0,
                      ),
                      child: const Text('Approuver (10 min)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.sm, AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: LightModeColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final bool read;
  final String timeLabel;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NotificationRow({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    required this.read,
    required this.timeLabel,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: read ? context.theme.scaffoldBackgroundColor : accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: context.theme.dividerColor),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: read ? context.theme.colorScheme.onSurface.withValues(alpha: 0.4) : accent,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: context.textStyles.bodyLarge?.copyWith(
                            fontWeight: read ? FontWeight.w500 : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (!read) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyntheticNotificationRow extends StatelessWidget {
  final String title;
  final String body;
  final String type;
  final int count;
  final VoidCallback onTap;

  const _SyntheticNotificationRow({
    required this.title,
    required this.body,
    required this.type,
    required this.count,
    required this.onTap,
  });

  IconData _iconForType() {
    switch (type) {
      case 'message':
        return Icons.mark_chat_unread_rounded;
      case 'opportunity':
        return Icons.lightbulb_rounded;
      case 'job':
        return Icons.work_rounded;
      case 'event':
        return Icons.event_available_rounded;
      case 'formation':
        return Icons.school_rounded;
      case 'info':
        return Icons.newspaper_rounded;
      case 'market':
        return Icons.storefront_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'money':
        return Icons.account_balance_wallet_rounded;
      case 'monPays':
        return Icons.flag_rounded;
      case 'reservation':
        return Icons.confirmation_number_rounded;
      case 'media':
        return Icons.play_circle_filled_rounded;
      case 'network':
        return Icons.groups_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: context.theme.dividerColor),
              ),
              alignment: Alignment.center,
              child: Icon(_iconForType(), color: cs.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: LightModeColors.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessRequestActions extends StatelessWidget {
  final String? requestId;
  final String? requesterId;
  final String? targetUserId;
  final Future<void> Function(String requestId) onApprove;
  final Future<void> Function(String requestId) onReject;

  const _AccessRequestActions({
    required this.requestId,
    required this.requesterId,
    required this.targetUserId,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final id = requestId;
    if (id == null || id.trim().isEmpty) {
      return Text(
        'Action indisponible: demande introuvable.',
        style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.error),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              try {
                await onReject(id);
              } catch (e) {
                debugPrint('AccessRequestActions: reject failed → $e');
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: LightModeColors.error,
              side: const BorderSide(color: LightModeColors.error),
            ),
            child: const Text('Refuser'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              try {
                await onApprove(id);
              } catch (e) {
                debugPrint('AccessRequestActions: approve failed → $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.accent,
              foregroundColor: const Color(0xFF0A2F5C),
              elevation: 0,
            ),
            child: const Text('Approuver'),
          ),
        ),
      ],
    );
  }
}

extension _ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
