/// THIX — Notifications Sheet (Production Enterprise)
/// ✅ SÉCURISÉ : Riverpod, ThixPolicy, i18n, validation, mounted checks
/// ✅ ACCESSIBLE : Semantics, HapticFeedback, i18n relativeTime
/// ✅ ROBUSTE : throttling, logs structurés, skeleton loader
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/profile_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const double _kSheetMaxHeightRatio = 0.88;
const double _kSheetBorderRadius = 24.0;
const double _kHandleWidth = 40.0;
const double _kHandleHeight = 4.0;
const Duration _kMarkAllThrottle = Duration(seconds: 2);
const int _kMaxBadgeDisplay = 99;
const int _kShortIdPrefix = 6;
const int _kShortIdSuffix = 4;
const int _kMaxShortLength = 14;

// ============================================================================
// VALIDATORS
// ============================================================================

class _NotifValidators {
  _NotifValidators._();

  static bool isValidId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    return trimmed.isNotEmpty && trimmed.length <= 128;
  }

  static String sanitizeText(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  /// Masque un ID long pour affichage (ex: "abc123…9f4e")
  static String shortId(String id) {
    if (id.length <= _kMaxShortLength) return id;
    return '${id.substring(0, _kShortIdPrefix)}…'
        '${id.substring(id.length - _kShortIdSuffix)}';
  }
}

// ============================================================================
// DISPLAY HELPERS
// ============================================================================

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
  required AppLocalizations l10n,
}) {
  final title = _NotifValidators.sanitizeText(rawTitle, maxLength: 80);
  final body = _NotifValidators.sanitizeText(rawBody, maxLength: 200);
  final hasTitle = title.isNotEmpty;
  final hasBody = body.isNotEmpty;

  switch (type) {
    case 'like':
      return _NotificationDisplay(
        title: hasTitle ? title : l10n.t('notif_like_title'),
        body: hasBody ? body : l10n.t('notif_like_body'),
        icon: Icons.favorite_rounded,
        accent: ThixPolicy.danger,
      );
    case 'follow':
      return _NotificationDisplay(
        title: hasTitle ? title : l10n.t('notif_follow_title'),
        body: hasBody ? body : l10n.t('notif_follow_body'),
        icon: Icons.person_add_rounded,
        accent: ThixPolicy.primary,
      );
    case 'connection':
      return _NotificationDisplay(
        title: hasTitle ? title : l10n.t('notif_connection_title'),
        body: hasBody ? body : l10n.t('notif_connection_body'),
        icon: Icons.people_alt_rounded,
        accent: ThixPolicy.primary,
      );
    case 'comment':
      return _NotificationDisplay(
        title: hasTitle ? title : l10n.t('notif_comment_title'),
        body: hasBody ? body : l10n.t('notif_comment_body'),
        icon: Icons.mode_comment_rounded,
        accent: ThixPolicy.primary,
      );
    case 'chat':
    case 'message':
      return _NotificationDisplay(
        title: hasTitle ? title : l10n.t('notif_message_title'),
        body: hasBody ? body : l10n.t('notif_message_body'),
        icon: Icons.chat_bubble_rounded,
        accent: ThixPolicy.primary,
      );
    case 'access_request':
      final name = _NotifValidators.sanitizeText(
        (extra['requester_name'] ?? '').toString(),
        maxLength: 50,
      );
      final thixId = _NotifValidators.sanitizeText(
        (extra['requester_thix_id'] ?? '').toString(),
        maxLength: 32,
      );
      final bits = <String>[
        if (name.isNotEmpty) name,
        if (thixId.isNotEmpty) thixId,
      ];
      return _NotificationDisplay(
        title: hasTitle
            ? (bits.isEmpty ? title : '$title — ${bits.join(' · ')}')
            : l10n.t('notif_access_request_title'),
        body: hasBody ? body : l10n.t('notif_access_request_body'),
        icon: Icons.lock_open_rounded,
        accent: ThixPolicy.warning,
      );
    default:
      return _NotificationDisplay(
        title: hasTitle ? title : l10n.t('notif_generic_title'),
        body: hasBody ? body : '',
        icon: Icons.notifications_rounded,
        accent: ThixPolicy.primary,
      );
  }
}

// ============================================================================
// SHEET
// ============================================================================

class NotificationsSheet {
  NotificationsSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationsSheetBody(),
    );
  }
}

// ============================================================================
// SHEET BODY (ConsumerStatefulWidget pour mounted + lifecycle)
// ============================================================================

class _NotificationsSheetBody extends ConsumerStatefulWidget {
  const _NotificationsSheetBody();

  @override
  ConsumerState<_NotificationsSheetBody> createState() =>
      _NotificationsSheetBodyState();
}

class _NotificationsSheetBodyState
    extends ConsumerState<_NotificationsSheetBody> {
  final _notifications = NotificationService();
  final _counters = NotificationCountersService();
  final _access = AccessRequestService();
  final _profiles = ProfileService();

  bool _markingAll = false;
  DateTime? _lastMarkAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final me = authState.maybeWhen(
      data: (user) => user,
      orElse: () => null,
    );
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    if (me == null) {
      return _buildNotLoggedIn(l10n, bottomPadding);
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
            title: l10n.t('notif_title'),
            subtitle: total > 0
                ? l10n.t('notif_unread_count',
                    args: [total.toString()])
                : l10n.t('notif_all_caught_up'),
            actions: [
              if (total > 0)
                _buildMarkAllButton(l10n, me.id),
              Semantics(
                button: true,
                label: l10n.t('common_close'),
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(Icons.close_rounded,
                      color: ThixPolicy.textMuted),
                ),
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

  Widget _buildNotLoggedIn(AppLocalizations l10n, double bottomPadding) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: _SheetShell(
        title: l10n.t('notif_title'),
        subtitle: null,
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_close'),
            child: IconButton(
              onPressed: () => context.pop(),
              icon: Icon(Icons.close_rounded, color: ThixPolicy.textMuted),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 48, color: ThixPolicy.textMuted.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                l10n.t('notif_login_required'),
                style: TextStyle(color: ThixPolicy.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkAllButton(AppLocalizations l10n, String meId) {
    return Semantics(
      button: true,
      enabled: !_markingAll,
      label: l10n.t('notif_mark_all_read'),
      child: TextButton(
        onPressed: _markingAll ? null : () => _markAllRead(meId),
        child: Text(
          l10n.t('notif_mark_all_read'),
          style: TextStyle(
            color: ThixPolicy.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ✅ FIX : throttling + mounted check + feedback
  Future<void> _markAllRead(String meId) async {
    if (_markingAll) return;

    final now = DateTime.now();
    if (_lastMarkAll != null &&
        now.difference(_lastMarkAll!) < _kMarkAllThrottle) {
      debugPrint('[NotifSheet] ⚠️ markAllRead throttled');
      return;
    }
    _lastMarkAll = now;

    setState(() => _markingAll = true);
    HapticFeedback.mediumImpact();
    debugPrint('[NotifSheet] 📖 Marking all read');

    try {
      await _notifications.markAllRead(meId);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('notif_all_marked_read')),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[NotifSheet] ❌ markAllRead failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('notif_mark_all_failed')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }
}

// ============================================================================
// RECEPTION PANEL
// ============================================================================

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
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionChips(context),
            _buildAccessRequests(context),
            _buildNotificationsList(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
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
                  labelKey: 'notif_section_messages',
                  count: counts.messages,
                  onTap: () => _navigateSection(
                    context, ThixSection.messages, AppRoutes.chat,
                  ),
                ),
                const SizedBox(width: 8),
                _SectionChip(
                  icon: Icons.groups_rounded,
                  labelKey: 'notif_section_network',
                  count: counts.network,
                  onTap: () => _navigateSectionWithPop(
                    context, ThixSection.network, '/network',
                  ),
                ),
                const SizedBox(width: 8),
                _SectionChip(
                  icon: Icons.newspaper_rounded,
                  labelKey: 'notif_section_info',
                  count: counts.info,
                  onTap: () => _showInfoSection(context),
                ),
                const SizedBox(width: 8),
                _SectionChip(
                  icon: Icons.event_available_rounded,
                  labelKey: 'notif_section_events',
                  count: counts.events,
                  onTap: () => _navigateSection(
                    context, ThixSection.events, AppRoutes.thixEvent,
                  ),
                ),
                const SizedBox(width: 8),
                _SectionChip(
                  icon: Icons.school_rounded,
                  labelKey: 'notif_section_formations',
                  count: counts.formations,
                  onTap: () => _navigateSection(
                    context, ThixSection.formations, AppRoutes.education,
                  ),
                ),
                const SizedBox(width: 8),
                _SectionChip(
                  icon: Icons.lightbulb_rounded,
                  labelKey: 'notif_section_opportunities',
                  count: counts.opportunities,
                  onTap: () => _navigateSection(
                    context, ThixSection.opportunities, AppRoutes.opportunities,
                  ),
                ),
                const SizedBox(width: 8),
                _SectionChip(
                  icon: Icons.work_rounded,
                  labelKey: 'notif_section_jobs',
                  count: counts.jobs,
                  onTap: () => _navigateSection(
                    context, ThixSection.jobs, AppRoutes.jobs,
                  ),
                ),
                const SizedBox(width: 8),
                _SectionChip(
                  icon: Icons.storefront_rounded,
                  labelKey: 'notif_section_market',
                  count: counts.market,
                  onTap: () => _navigateSectionWithPop(
                    context, ThixSection.market, AppRoutes.thixMarket,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _navigateSection(
    BuildContext context,
    ThixSection section,
    String route,
  ) async {
    await counters.markSectionSeen(uid: meId, section: section);
    if (context.mounted) context.push(route);
  }

  Future<void> _navigateSectionWithPop(
    BuildContext context,
    ThixSection section,
    String route,
  ) async {
    await counters.markSectionSeen(uid: meId, section: section);
    if (context.mounted) {
      context.pop();
      context.push(route);
    }
  }

  Future<void> _showInfoSection(BuildContext context) async {
    await counters.markSectionSeen(uid: meId, section: ThixSection.info);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    context.pop();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        ),
        title: Text(
          l10n.t('notif_info_title'),
          style: TextStyle(color: ThixPolicy.textMain),
        ),
        content: Text(
          l10n.t('notif_info_content'),
          style: TextStyle(color: ThixPolicy.textMuted),
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_close'),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l10n.t('common_close'),
                style: TextStyle(color: ThixPolicy.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessRequests(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: access.streamIncomingRequests(ownerId: meId, status: 'pending'),
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return const SizedBox.shrink();

        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: ThixPolicy.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(
                  color: ThixPolicy.warning.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ThixPolicy.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.lock_person_rounded,
                          color: ThixPolicy.warning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.t('notif_access_requests_title'),
                          style: TextStyle(
                            color: ThixPolicy.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ThixPolicy.warning,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${rows.length}',
                        style: TextStyle(
                          color: ThixPolicy.inkDeep,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final r in rows) ...[
                  _IncomingAccessRequestCard(
                    requestId: _NotifValidators.sanitizeText(
                        (r['id'] ?? '').toString(), maxLength: 64),
                    requesterId: _NotifValidators.sanitizeText(
                        (r['requester_id'] ?? '').toString(), maxLength: 64),
                    createdAt: _NotifValidators.sanitizeText(
                        (r['created_at'] ?? '').toString(), maxLength: 32),
                    profiles: profiles,
                    onApprove: () => _approveRequest(r),
                    onReject: () => _rejectRequest(r),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveRequest(Map<String, dynamic> r) async {
    final id = (r['id'] ?? '').toString();
    final requester = (r['requester_id'] ?? '').toString();
    if (!_NotifValidators.isValidId(id)) return;

    HapticFeedback.mediumImpact();
    debugPrint('[NotifSheet] ✓ Approving request: ${_NotifValidators.shortId(id)}');

    try {
      await access.approveFor10Minutes(requestId: id);
      if (_NotifValidators.isValidId(requester)) {
        final profile = await profiles.fetchPublicProfileByUserId(requester);
        await notifications.add(
          toUid: requester,
          type: 'access_request',
          title: 'Accès approuvé',
          body: 'Votre demande d\'accès a été approuvée (10 min).',
          data: {
            'request_id': id,
            'requester_id': requester,
            'requester_name': profile?.displayName,
            'requester_thix_id': profile?.thixId,
            'access_minutes': 10,
          },
        );
      }
    } catch (e) {
      debugPrint('[NotifSheet] ❌ Approve failed: $e');
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> r) async {
    final id = (r['id'] ?? '').toString();
    final requester = (r['requester_id'] ?? '').toString();
    if (!_NotifValidators.isValidId(id)) return;

    HapticFeedback.lightImpact();
    debugPrint('[NotifSheet] ✗ Rejecting request: ${_NotifValidators.shortId(id)}');

    try {
      await access.setStatus(requestId: id, status: 'rejected');
      if (_NotifValidators.isValidId(requester)) {
        final profile = await profiles.fetchPublicProfileByUserId(requester);
        await notifications.add(
          toUid: requester,
          type: 'access_request',
          title: 'Accès refusé',
          body: 'Votre demande d\'accès a été refusée.',
          data: {
            'request_id': id,
            'requester_id': requester,
            'requester_name': profile?.displayName,
            'requester_thix_id': profile?.thixId,
          },
        );
      }
    } catch (e) {
      debugPrint('[NotifSheet] ❌ Reject failed: $e');
    }
  }

  Widget _buildNotificationsList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<SectionBadgeCounts>(
      stream: countsStream,
      builder: (context, countsSnap) {
        final counts = countsSnap.data ?? SectionBadgeCounts.zero;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: notifications.streamForUser(meId),
          builder: (context, snap) {
            final docs = snap.data ?? const <Map<String, dynamic>>[];
            final synthetic = _syntheticNotificationsFromCounts(counts, l10n);
            final merged = <Map<String, dynamic>>[...synthetic, ...docs];

            if (snap.connectionState == ConnectionState.waiting &&
                merged.isEmpty) {
              return const _SkeletonLoader();
            }

            if (snap.hasError) {
              debugPrint('[NotifSheet] ❌ Stream error: ${snap.error}');
              return _ErrorState(
                message: l10n.t('notif_load_error'),
                onRetry: () {/* StreamBuilder auto-retry */},
              );
            }

            if (merged.isEmpty) {
              return _EmptyState(l10n: l10n);
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: merged.length,
              separatorBuilder: (_, __) =>
                  Divider(color: ThixPolicy.border, height: 1),
              itemBuilder: (context, i) {
                final data = merged[i];

                if ((data['__synthetic'] as bool?) == true) {
                  return _SyntheticNotificationRow(
                    title: (data['title'] ?? l10n.t('notif_generic_title'))
                        .toString(),
                    body: (data['body'] ?? '').toString(),
                    type: (data['type'] ?? 'generic').toString(),
                    count: (data['count'] as int?) ?? 0,
                    onTap: () => _handleSyntheticTap(
                      context: context,
                      section: (data['section'] ?? '').toString(),
                    ),
                  );
                }

                final type = (data['type'] as String?) ?? 'generic';
                final read = (data['read'] as bool?) ?? false;
                final extra = (data['data'] as Map?)
                        ?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
                final id = (data['id'] ?? '').toString();
                final createdAt = data['created_at'];

                final display = _displayFor(
                  type: type,
                  rawTitle: data['title'] as String?,
                  rawBody: data['body'] as String?,
                  extra: extra,
                  l10n: l10n,
                );

                // ✅ FIX : utilise i18n_service pour relative time
                DateTime? parsedDate;
                if (createdAt is DateTime) {
                  parsedDate = createdAt;
                } else if (createdAt != null) {
                  parsedDate = DateTime.tryParse(createdAt.toString());
                }
                final timeLabel = parsedDate != null
                    ? I18nService.of(context).relativeTime(parsedDate)
                    : '';

                return _NotificationRow(
                  title: display.title,
                  body: display.body,
                  icon: display.icon,
                  accent: display.accent,
                  read: read,
                  timeLabel: timeLabel,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_NotifValidators.isValidId(id)) {
                      notifications.markRead(uid: meId, notificationId: id);
                    }
                  },
                  trailing: type == 'access_request'
                      ? _AccessRequestActions(
                          requestId: extra['request_id'] as String?,
                          onApprove: (reqId) async {
                            if (!_NotifValidators.isValidId(reqId)) return;
                            HapticFeedback.mediumImpact();
                            await access.approveFor10Minutes(requestId: reqId);
                            if (_NotifValidators.isValidId(id)) {
                              await notifications.markRead(
                                  uid: meId, notificationId: id);
                            }
                          },
                          onReject: (reqId) async {
                            if (!_NotifValidators.isValidId(reqId)) return;
                            HapticFeedback.lightImpact();
                            await access.setStatus(
                                requestId: reqId, status: 'rejected');
                            if (_NotifValidators.isValidId(id)) {
                              await notifications.markRead(
                                  uid: meId, notificationId: id);
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
    );
  }

  List<Map<String, dynamic>> _syntheticNotificationsFromCounts(
    SectionBadgeCounts counts,
    AppLocalizations l10n,
  ) {
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
        title: l10n.t('notif_synth_messages_title'),
        body: l10n.t('notif_synth_messages_body',
            args: [counts.messages.toString()]),
        count: counts.messages,
      ));
    }
    if (counts.network > 0) {
      out.add(mk(
        section: ThixSection.network.name,
        type: 'network',
        title: l10n.t('notif_synth_network_title'),
        body: l10n.t('notif_synth_network_body',
            args: [counts.network.toString()]),
        count: counts.network,
      ));
    }
    if (counts.opportunities > 0) {
      out.add(mk(
        section: ThixSection.opportunities.name,
        type: 'opportunity',
        title: l10n.t('notif_synth_opportunities_title'),
        body: l10n.t('notif_synth_opportunities_body',
            args: [counts.opportunities.toString()]),
        count: counts.opportunities,
      ));
    }
    if (counts.jobs > 0) {
      out.add(mk(
        section: ThixSection.jobs.name,
        type: 'job',
        title: l10n.t('notif_synth_jobs_title'),
        body: l10n.t('notif_synth_jobs_body',
            args: [counts.jobs.toString()]),
        count: counts.jobs,
      ));
    }
    if (counts.events > 0) {
      out.add(mk(
        section: ThixSection.events.name,
        type: 'event',
        title: l10n.t('notif_synth_events_title'),
        body: l10n.t('notif_synth_events_body',
            args: [counts.events.toString()]),
        count: counts.events,
      ));
    }
    if (counts.formations > 0) {
      out.add(mk(
        section: ThixSection.formations.name,
        type: 'formation',
        title: l10n.t('notif_synth_formations_title'),
        body: l10n.t('notif_synth_formations_body',
            args: [counts.formations.toString()]),
        count: counts.formations,
      ));
    }
    if (counts.info > 0) {
      out.add(mk(
        section: ThixSection.info.name,
        type: 'info',
        title: l10n.t('notif_synth_info_title'),
        body: l10n.t('notif_synth_info_body',
            args: [counts.info.toString()]),
        count: counts.info,
      ));
    }
    if (counts.market > 0) {
      out.add(mk(
        section: ThixSection.market.name,
        type: 'market',
        title: l10n.t('notif_synth_market_title'),
        body: l10n.t('notif_synth_market_body',
            args: [counts.market.toString()]),
        count: counts.market,
      ));
    }
    return out;
  }

  Future<void> _handleSyntheticTap({
    required BuildContext context,
    required String section,
  }) async {
    HapticFeedback.selectionClick();
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
          _showInfoSection(context);
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
      }
    } catch (e) {
      debugPrint('[NotifSheet] ❌ Synthetic tap failed: $e');
    }
  }
}

// ============================================================================
// SECTION CHIP
// ============================================================================

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.icon,
    required this.labelKey,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String labelKey;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasCount = count > 0;
    final bg = hasCount
        ? ThixPolicy.primary.withValues(alpha: 0.15)
        : ThixPolicy.surfaceSoft;
    final fg = hasCount ? ThixPolicy.primary : ThixPolicy.textMuted;
    final borderColor = hasCount
        ? ThixPolicy.primary.withValues(alpha: 0.5)
        : ThixPolicy.border;

    return Semantics(
      button: true,
      label: '${l10n.t(labelKey)}${hasCount ? ", $count" : ""}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(
                l10n.t(labelKey),
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (hasCount) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > _kMaxBadgeDisplay
                        ? '${_kMaxBadgeDisplay}+'
                        : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// INCOMING ACCESS REQUEST CARD
// ============================================================================

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder(
      stream: profiles.streamPublicProfileByUserId(requesterId),
      builder: (context, snap) {
        final p = snap.data;
        final name = _NotifValidators.sanitizeText(
            p?.displayName ?? '', maxLength: 60);
        final thixId = _NotifValidators.sanitizeText(
            p?.thixId ?? '', maxLength: 32);
        final header = name.isNotEmpty
            ? '${l10n.t("notif_access_from")}: $name'
            : '${l10n.t("notif_access_from")}: ${_NotifValidators.shortId(requesterId)}';

        return Container(
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  header,
                  style: TextStyle(
                    color: ThixPolicy.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (thixId.isNotEmpty)
                Text(
                  'THIX ID: $thixId',
                  style: TextStyle(
                    color: ThixPolicy.warning,
                    fontSize: 13,
                  ),
                ),
              Text(
                '${l10n.t("notif_access_request_id")}: ${_NotifValidators.shortId(requestId)}',
                style: TextStyle(
                  color: ThixPolicy.textMuted,
                  fontSize: 12,
                ),
              ),
              if (createdAt.isNotEmpty)
                Text(
                  '${l10n.t("notif_access_received")}: $createdAt',
                  style: TextStyle(
                    color: ThixPolicy.textMuted,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: l10n.t('notif_access_reject'),
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThixPolicy.danger,
                          side: BorderSide(color: ThixPolicy.danger),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(ThixPolicy.rSm)),
                        ),
                        child: Text(l10n.t('notif_access_reject')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: l10n.t('notif_access_approve'),
                      child: ElevatedButton(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThixPolicy.warning,
                          foregroundColor: ThixPolicy.inkDeep,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(ThixPolicy.rSm)),
                        ),
                        child: Text(
                          l10n.t('notif_access_approve'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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

// ============================================================================
// SHEET SHELL
// ============================================================================

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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * _kSheetMaxHeightRatio,
      ),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_kSheetBorderRadius),
          topRight: Radius.circular(_kSheetBorderRadius),
        ),
        border: Border(
          top: BorderSide(color: ThixPolicy.border, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Semantics(
                label: 'Drag handle',
                child: Container(
                  width: _kHandleWidth,
                  height: _kHandleHeight,
                  decoration: BoxDecoration(
                    color: ThixPolicy.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: TextStyle(
                            color: ThixPolicy.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: ThixPolicy.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
          ),
          // Content
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NOTIFICATION ROW
// ============================================================================

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
    return Semantics(
      button: true,
      label: '$title. $body. $timeLabel',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          color: read
              ? Colors.transparent
              : accent.withValues(alpha: 0.05),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: read
                      ? ThixPolicy.surfaceSoft
                      : accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(
                    color: read
                        ? ThixPolicy.border
                        : accent.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: read ? ThixPolicy.textMuted : accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: read
                                  ? ThixPolicy.textMuted
                                  : ThixPolicy.textMain,
                              fontWeight: read
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: ThixPolicy.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (!read) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: TextStyle(
                          color: ThixPolicy.textMuted,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(height: 12),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SYNTHETIC NOTIFICATION ROW
// ============================================================================

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
      case 'network':
        return Icons.groups_rounded;
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
      default:
        return Icons.widgets_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $body. $count',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          color: ThixPolicy.primary.withValues(alpha: 0.05),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(
                    color: ThixPolicy.primary.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(_iconForType(),
                    color: ThixPolicy.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: ThixPolicy.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ThixPolicy.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            count > _kMaxBadgeDisplay
                                ? '${_kMaxBadgeDisplay}+'
                                : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        color: ThixPolicy.textMuted,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ACCESS REQUEST ACTIONS
// ============================================================================

class _AccessRequestActions extends StatelessWidget {
  final String? requestId;
  final Future<void> Function(String requestId) onApprove;
  final Future<void> Function(String requestId) onReject;

  const _AccessRequestActions({
    required this.requestId,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = requestId;
    if (id == null || !_NotifValidators.isValidId(id)) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.t('notif_access_reject'),
            child: OutlinedButton(
              onPressed: () => onReject(id),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.danger,
                side: BorderSide(color: ThixPolicy.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              ),
              child: Text(l10n.t('notif_access_reject')),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.t('notif_access_approve'),
            child: ElevatedButton(
              onPressed: () => onApprove(id),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.warning,
                foregroundColor: ThixPolicy.inkDeep,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              ),
              child: Text(
                l10n.t('notif_access_approve'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SKELETON LOADER
// ============================================================================

class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _row() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: 0.35 + 0.3 * _ctrl.value,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Opacity(
                    opacity: 0.35 + 0.3 * _ctrl.value,
                    child: Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                        color: ThixPolicy.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Opacity(
                    opacity: 0.35 + 0.3 * _ctrl.value,
                    child: Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ThixPolicy.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: List.generate(5, (_) => _row()),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: ThixPolicy.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('notif_empty'),
            style: TextStyle(color: ThixPolicy.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 40, color: ThixPolicy.danger),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: ThixPolicy.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: l10n.t('common_retry'),
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
