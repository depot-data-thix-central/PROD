import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class StaffDashboardPage extends ConsumerWidget {
  final String weddingId;
  const StaffDashboardPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weddingAsync = ref.watch(weddingProvider(weddingId));
    final statsAsync = ref.watch(dashboardStatsProvider(weddingId));
    final budgetAsync = ref.watch(paymentsSummaryProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: Text(
          'Dashboard',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B3B8F),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () =>
                context.push('/thix-weeding/staff/$weddingId/messages'),
          ),
        ],
      ),
      body: weddingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0B3B8F)),
        ),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () {
            ref.invalidate(weddingProvider(weddingId));
            ref.invalidate(dashboardStatsProvider(weddingId));
            ref.invalidate(paymentsSummaryProvider(weddingId));
          },
        ),
        data: (wedding) {
          final stats = statsAsync.valueOrNull;
          final budget = budgetAsync.valueOrNull;

          int daysLeft = 0;
          String dateLabel = 'Date à définir';
          final d = wedding.weddingDate;
          if (d != null) {
            daysLeft = d.difference(DateTime.now()).inDays.clamp(0, 9999);
            dateLabel =
                '${d.day.toString().padLeft(2, '0')}/'
                '${d.month.toString().padLeft(2, '0')}/'
                '${d.year}';
          }

          final totalBudget = budget?['budget'] ?? 0.0;
          final totalSpent = budget?['spent'] ?? 0.0;

          return RefreshIndicator(
            color: const Color(0xFF0B3B8F),
            onRefresh: () async {
              ref.invalidate(weddingProvider(weddingId));
              ref.invalidate(dashboardStatsProvider(weddingId));
              ref.invalidate(paymentsSummaryProvider(weddingId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // En-tête couple
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wedding.coupleNames.isEmpty
                            ? 'Mariage'
                            : wedding.coupleNames,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (wedding.venue != null &&
                              wedding.venue!.isNotEmpty)
                            wedding.venue!,
                          dateLabel,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'J − $daysLeft',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE31C4E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Invités',
                        value: '${stats?['guests'] ?? '—'}',
                        icon: Icons.people_outline,
                        color: const Color(0xFF0B3B8F),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Présents',
                        value: '${stats?['present'] ?? '—'}',
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Prestataires',
                        value: '${stats?['vendors'] ?? '—'}',
                        icon: Icons.storefront_outlined,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Tâches',
                        value: '${stats?['pendingTasks'] ?? '—'}',
                        icon: Icons.task_alt,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Budget
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalSpent.toStringAsFixed(0)} / ${totalBudget.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: totalBudget > 0
                              ? (totalSpent / totalBudget).clamp(0.0, 1.0)
                              : 0,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Raccourcis
                Text(
                  'Raccourcis',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                _Shortcut(
                  icon: Icons.people_outline,
                  title: 'Liste des invités',
                  onTap: () =>
                      context.push('/thix-weeding/staff/$weddingId/invites'),
                ),
                _Shortcut(
                  icon: Icons.storefront_outlined,
                  title: 'Prestataires',
                  onTap: () => context
                      .push('/thix-weeding/staff/$weddingId/prestataires'),
                ),
                _Shortcut(
                  icon: Icons.checklist_outlined,
                  title: 'Checklist',
                  onTap: () =>
                      context.push('/thix-weeding/staff/$weddingId/checklist'),
                ),
                _Shortcut(
                  icon: Icons.payments_outlined,
                  title: 'Paiements',
                  onTap: () =>
                      context.push('/thix-weeding/staff/$weddingId/paiements'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger le mariage',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B3B8F),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF0B3B8F)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
