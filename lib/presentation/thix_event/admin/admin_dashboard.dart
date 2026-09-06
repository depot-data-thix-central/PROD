// lib/presentation/thix_event/admin/admin_dashboard.dart
//
// AdminDashboard — Production Enterprise (i18n + Design System + A11y)
//
// LOGIQUE PRÉSERVÉE (ne rien changer) :
// - AdminGuard.getCurrentRole() → rôle utilisateur
// - adminEventProvider.notifier.loadDashboardStats() (microtask)
// - AdminGuard.canWrite(role) pour la carte "Créer"
// - AdminConstants.isDevOpenAccess pour badge DEV
// - Navigation via context.push(route)
// - Stats : totalEvents, totalBookings, totalRevenue, waitingQueue
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/admin_constants.dart';
import '../../../core/admin_guards.dart';
import '../../../core/theme/thix_design_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/admin_event_provider.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color accent = ThixPolicy.gold;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color devWarning = ThixPolicy.warning;
  static const Color danger = ThixPolicy.danger;
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kNavThrottle = Duration(milliseconds: 500);

// ============================================================================
// LOGGING
// ============================================================================
class _AdminLogger {
  static const _tag = 'AdminDashboard';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// ACTION DEFINITION (data-driven, pas en dur dans le widget)
// ============================================================================
class _AdminAction {
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final String route;
  final bool requiresWrite;

  const _AdminAction({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.route,
    this.requiresWrite = false,
  });
}

const List<_AdminAction> _kAdminActions = [
  _AdminAction(
    titleKey: 'admin_action_events',
    subtitleKey: 'admin_action_events_sub',
    icon: Icons.list_alt_rounded,
    route: '/thix-event/admin/events',
  ),
  _AdminAction(
    titleKey: 'admin_action_create',
    subtitleKey: 'admin_action_create_sub',
    icon: Icons.add_circle_rounded,
    route: '/thix-event/admin/events/create',
    requiresWrite: true,
  ),
  _AdminAction(
    titleKey: 'admin_action_seats',
    subtitleKey: 'admin_action_seats_sub',
    icon: Icons.event_seat_rounded,
    route: '/thix-event/admin/seats',
  ),
  _AdminAction(
    titleKey: 'admin_action_reservations',
    subtitleKey: 'admin_action_reservations_sub',
    icon: Icons.receipt_long_rounded,
    route: '/thix-event/admin/bookings',
  ),
  _AdminAction(
    titleKey: 'admin_action_limits',
    subtitleKey: 'admin_action_limits_sub',
    icon: Icons.security_rounded,
    route: '/thix-event/admin/limits',
  ),
  _AdminAction(
    titleKey: 'admin_action_analytics',
    subtitleKey: 'admin_action_analytics_sub',
    icon: Icons.analytics_rounded,
    route: '/thix-event/admin/analytics',
  ),
];

// ============================================================================
// PAGE
// ============================================================================
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  AdminRole _role = AdminRole.superAdmin;
  DateTime? _lastNav;

  @override
  void initState() {
    super.initState();
    _init();
    _AdminLogger.info('AdminDashboard initialized');
  }

  Future<void> _init() async {
    try {
      _role = await AdminGuard.getCurrentRole();
      if (!mounted) return;
      setState(() {});
      _AdminLogger.info('Role resolved', {'role': _role.toString()});
    } catch (e) {
      _AdminLogger.error('Role resolution failed', {'error': '$e'});
    }
    Future.microtask(() {
      if (!mounted) return;
      try {
        ref.read(adminEventProvider.notifier).loadDashboardStats();
      } catch (e) {
        _AdminLogger.error('loadDashboardStats failed', {'error': '$e'});
      }
    });
  }

  Future<void> _refresh() async {
    try {
      await ref.read(adminEventProvider.notifier).loadDashboardStats();
    } catch (e) {
      _AdminLogger.error('Refresh failed', {'error': '$e'});
    }
  }

  bool _canNavigate() {
    final now = DateTime.now();
    if (_lastNav != null && now.difference(_lastNav!) < _kNavThrottle) {
      _AdminLogger.warn('Navigation throttled');
      return false;
    }
    _lastNav = now;
    return true;
  }

  void _navigate(String route) {
    if (!_canNavigate()) return;
    HapticFeedback.selectionClick();
    _AdminLogger.info('Navigate', {'route': route});
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(adminEventProvider);
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.accessibleNavigation ||
        mediaQuery.disableAnimations;

    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: reduceMotion ? 0 : 20,
              sigmaY: reduceMotion ? 0 : 20,
            ),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85),
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(ThixPolicy.s6),
                    decoration: BoxDecoration(
                      color: EventTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: EventTheme.primary,
                    ),
                  ),
                  const SizedBox(width: ThixPolicy.s10),
                  Text(
                    l10n.t('admin_title'),
                    style: ThixPolicy.labelStyle.copyWith(
                      color: EventTheme.textMain,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: ThixPolicy.s8),
                  if (AdminConstants.isDevOpenAccess)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: EventTheme.devWarning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(ThixPolicy.s6),
                        border: Border.all(
                          color: EventTheme.devWarning.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        l10n.t('admin_dev_open'),
                        style: ThixPolicy.microStyle.copyWith(
                          color: EventTheme.devWarning,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                Semantics(
                  button: true,
                  label: l10n.t('common_refresh'),
                  child: IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _refresh,
                  ),
                ),
                const SizedBox(width: ThixPolicy.s4),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: EventTheme.primary,
        backgroundColor: EventTheme.surface,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildStatsGrid(l10n, state)),
            const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s16,
                ),
                child: Text(
                  l10n.t('admin_actions_section'),
                  style: ThixPolicy.microStyle.copyWith(
                    color: EventTheme.textMuted.withOpacity(0.8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: ThixPolicy.s10),
            ),
            SliverToBoxAdapter(child: _buildActionGrid(l10n, _role)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // STATS GRID (logique préservée)
  // ════════════════════════════════════════════════════════════
  Widget _buildStatsGrid(AppLocalizations l10n, AdminEventState s) {
    // Logique exacte préservée : loader affiché uniquement si chargement initial
    if (s.statsLoading && s.stats.totalEvents == 0) {
      return Padding(
        padding: const EdgeInsets.all(ThixPolicy.s32),
        child: Center(
          child: CircularProgressIndicator(
            color: EventTheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Formatage robuste des valeurs (gère null/erreur)
    String safeNum(dynamic v) {
      try {
        if (v == null) return '0';
        if (v is num) return v.toStringAsFixed(0);
        return v.toString();
      } catch (_) {
        return '0';
      }
    }

    return Padding(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Wrap(
        spacing: ThixPolicy.s12,
        runSpacing: ThixPolicy.s12,
        children: [
          _StatCard(
            label: l10n.t('admin_stat_events'),
            value: safeNum(s.stats.totalEvents),
            icon: Icons.event_rounded,
            color: EventTheme.primary,
          ),
          _StatCard(
            label: l10n.t('admin_stat_bookings'),
            value: safeNum(s.stats.totalBookings),
            icon: Icons.confirmation_number_rounded,
            color: EventTheme.accent,
          ),
          _StatCard(
            label: l10n.t('admin_stat_revenue'),
            value: safeNum(s.stats.totalRevenue),
            icon: Icons.payments_rounded,
            color: ThixPolicy.success,
          ),
          _StatCard(
            label: l10n.t('admin_stat_queue'),
            value: safeNum(s.stats.waitingQueue),
            icon: Icons.hourglass_top_rounded,
            color: ThixPolicy.info,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ACTION GRID (data-driven, garde la logique canWrite)
  // ════════════════════════════════════════════════════════════
  Widget _buildActionGrid(AppLocalizations l10n, AdminRole role) {
    final canWrite = AdminGuard.canWrite(role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: ThixPolicy.s12,
        mainAxisSpacing: ThixPolicy.s12,
        childAspectRatio: 1.25,
        children: _kAdminActions
            .map(
              (a) => _ActionCard(
                action: a,
                canWrite: canWrite,
                onTap: () => _navigate(a.route),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================================
// STAT CARD
// ============================================================================
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;

    return Semantics(
      label: '$label: $value',
      child: Container(
        width: width,
        padding: const EdgeInsets.all(ThixPolicy.s14),
        decoration: BoxDecoration(
          color: EventTheme.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: EventTheme.border),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: ThixPolicy.s12),
            Text(
              value,
              style: ThixPolicy.h2Style.copyWith(
                color: EventTheme.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: ThixPolicy.s2),
            Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                color: EventTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ACTION CARD (préserve la logique canWrite + title=='Creer' check)
// ============================================================================
class _ActionCard extends StatelessWidget {
  final _AdminAction action;
  final bool canWrite;
  final VoidCallback onTap;

  const _ActionCard({
    required this.action,
    required this.canWrite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isReadOnly = action.requiresWrite && !canWrite;

    return Semantics(
      button: true,
      enabled: !isReadOnly,
      label: '${l10n.t(action.titleKey)}. ${l10n.t(action.subtitleKey)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        onTap: isReadOnly ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(ThixPolicy.s14),
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(
              color: isReadOnly ? EventTheme.border : EventTheme.border,
            ),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s10),
                decoration: BoxDecoration(
                  color: isReadOnly
                      ? EventTheme.textMuted.withOpacity(0.1)
                      : EventTheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isReadOnly
                        ? EventTheme.textMuted.withOpacity(0.2)
                        : EventTheme.primary.withOpacity(0.25),
                  ),
                ),
                child: Icon(
                  action.icon,
                  size: 18,
                  color: isReadOnly ? EventTheme.textMuted : EventTheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                l10n.t(action.titleKey),
                style: ThixPolicy.bodyMediumStyle.copyWith(
                  color: isReadOnly
                      ? EventTheme.textMuted
                      : EventTheme.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: ThixPolicy.s2),
              Text(
                l10n.t(action.subtitleKey),
                style: ThixPolicy.microStyle.copyWith(
                  color: EventTheme.textMuted,
                ),
              ),
              if (isReadOnly)
                Padding(
                  padding: const EdgeInsets.only(top: ThixPolicy.s4),
                  child: Text(
                    l10n.t('admin_read_only'),
                    style: ThixPolicy.microStyle.copyWith(
                      color: EventTheme.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
