/// THIX SOS — Historique des incidents (Production Enterprise)
/// ✅ SÉCURISÉ : ThixPolicy, i18n, semantics, haptic, mounted checks, logs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'sos_actif_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRefreshThrottle = Duration(seconds: 2);

// ============================================================================
// PAGE
// ============================================================================
class MesIncidentsPage extends ConsumerStatefulWidget {
  const MesIncidentsPage({super.key});

  @override
  ConsumerState<MesIncidentsPage> createState() => _MesIncidentsPageState();
}

class _MesIncidentsPageState extends ConsumerState<MesIncidentsPage> {
  DateTime? _lastRefresh;

  Future<void> _refresh() async {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < _kRefreshThrottle) {
      debugPrint('[MesIncidents] ⚠️ Refresh throttled');
      return;
    }
    _lastRefresh = now;
    debugPrint('[MesIncidents] 🔄 Refreshing history');
    HapticFeedback.lightImpact();
    ref.invalidate(sosHistoryProvider);
    ref.invalidate(activeSosProvider);
  }

  void _navigateToActive(BuildContext context, SosIncident active) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosActifPage(incidentId: active.id),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, SosIncident incident) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    // TODO: Implémenter IncidentDetailPage
    debugPrint('[MesIncidents] ⚠️ Detail page not implemented for ${incident.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final historyAsync = ref.watch(sosHistoryProvider);
    final activeAsync = ref.watch(activeSosProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.inkDeep,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 20, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          l10n.t('sos_my_incidents'),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_refresh'),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: ThixPolicy.danger,
        backgroundColor: ThixPolicy.card,
        onRefresh: _refresh,
        child: historyAsync.when(
          loading: () => const _SkeletonLoader(),
          error: (e, stack) {
            debugPrint('[MesIncidents] ❌ Load error: $e');
            debugPrint('[MesIncidents] Stack: $stack');
            return _ErrorState(
              message: l10n.t('sos_history_error'),
              onRetry: _refresh,
            );
          },
          data: (incidents) {
            final active = activeAsync.valueOrNull;
            final past = incidents
                .where((i) => active == null || i.id != active.id)
                .toList();

            if (incidents.isEmpty) {
              return _EmptyState(l10n: l10n);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                ThixPolicy.s16,
                ThixPolicy.s8,
                ThixPolicy.s16,
                ThixPolicy.s32,
              ),
              children: [
                if (active != null && active.isActive) ...[
                  _SectionTitle(
                    title: l10n.t('sos_in_progress'),
                    color: ThixPolicy.danger,
                  ),
                  const SizedBox(height: ThixPolicy.s8),
                  _IncidentCard(
                    incident: active,
                    highlight: true,
                    onTap: () => _navigateToActive(context, active),
                  ),
                  const SizedBox(height: ThixPolicy.s24),
                ],
                if (past.isNotEmpty) ...[
                  _SectionTitle(
                    title: l10n.t('sos_history'),
                    color: ThixPolicy.textMuted,
                  ),
                  const SizedBox(height: ThixPolicy.s8),
                  ...past.map(
                    (i) => _IncidentCard(
                      incident: i,
                      onTap: () => _navigateToDetail(context, i),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============================================================================
// INCIDENT CARD
// ============================================================================
class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    this.onTap,
    this.highlight = false,
  });

  final SosIncident incident;
  final VoidCallback? onTap;
  final bool highlight;

  Color get _statusColor {
    if (incident.status == SosStatus.resolved) return ThixPolicy.success;
    if (incident.status == SosStatus.cancelled) return ThixPolicy.textMuted;
    return ThixPolicy.danger;
  }

  String _formatDate(DateTime d, AppLocalizations l10n) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(d.year, d.month, d.day);
      final time =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

      if (day == today) return '${l10n.t('common_today')}, $time';
      if (day == today.subtract(const Duration(days: 1))) {
        return '${l10n.t('common_yesterday')}, $time';
      }
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}, $time';
    } catch (e) {
      debugPrint('[MesIncidents] ⚠️ Date format error: $e');
      return '—';
    }
  }

  String _durationLabel(SosIncident i) {
    try {
      final end = i.resolvedAt ?? DateTime.now();
      final d = end.difference(i.startedAt);
      if (d.isNegative) return '0 min';
      if (d.inHours > 0) {
        return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}min';
      }
      return '${d.inMinutes} min';
    } catch (e) {
      debugPrint('[MesIncidents] ⚠️ Duration error: $e');
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s10),
      child: Semantics(
        button: true,
        label: '${l10n.t('sos_incident')} ${incident.publicId}',
        child: Material(
          color: highlight
              ? ThixPolicy.danger.withValues(alpha: 0.35)
              : ThixPolicy.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: highlight
                      ? ThixPolicy.danger.withValues(alpha: 0.45)
                      : ThixPolicy.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      highlight ? Icons.sos : Icons.folder_outlined,
                      color: _statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.publicId,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(incident.startedAt, l10n),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: ThixPolicy.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${incident.status.labelFr} · ${_durationLabel(incident)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: highlight ? ThixPolicy.danger : ThixPolicy.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  Widget _box(double h, [double w = double.infinity]) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.35 + 0.3 * _ctrl.value,
        child: Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: ThixPolicy.border,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        children: [
          _box(16, 120),
          const SizedBox(height: 12),
          _box(80),
          const SizedBox(height: 24),
          _box(16, 100),
          const SizedBox(height: 12),
          _box(80),
          const SizedBox(height: 10),
          _box(80),
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
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline,
            color: ThixPolicy.danger, size: 40),
        const SizedBox(height: ThixPolicy.s12),
        Center(
          child: Text(
            message,
            style: GoogleFonts.inter(color: ThixPolicy.danger),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: ThixPolicy.s16),
        Center(
          child: Semantics(
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
        ),
      ],
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
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.folder_open, size: 56, color: ThixPolicy.textMuted),
        const SizedBox(height: ThixPolicy.s16),
        Center(
          child: Text(
            l10n.t('sos_no_incidents'),
            style: GoogleFonts.inter(
              fontSize: 15,
              color: ThixPolicy.textMuted,
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s6),
        Center(
          child: Text(
            l10n.t('sos_incidents_appear_here'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ThixPolicy.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}
