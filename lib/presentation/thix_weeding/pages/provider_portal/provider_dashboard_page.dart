// lib/presentation/thix_weeding/pages/provider_portal/provider_dashboard_page.dart
// ============================================================================
// THIX WEDDING — DASHBOARD PRESTATAIRE (PRODUCTION ENTERPRISE)
// ✅ Statistiques réelles depuis Supabase (Réservations, Revenus, Tâches)
// ✅ Actions rapides (Ajouter médias, Voir demandes)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF0B3B8F);
  static const Color amber = Color(0xFFF59E0B);
}

class ProviderDashboardPage extends ConsumerWidget {
  final ThixProviderModel provider;
  const ProviderDashboardPage({super.key, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(providerStatsProvider(provider.id));
    final reservationsAsync = ref.watch(providerReservationsProvider(ProviderReservationsParams(providerId: provider.id)));
    final tasksAsync = ref.watch(providerTasksProvider(ProviderTasksParams(providerId: provider.id)));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(providerStatsProvider(provider.id));
        ref.invalidate(providerReservationsProvider(ProviderReservationsParams(providerId: provider.id)));
        ref.invalidate(providerTasksProvider(ProviderTasksParams(providerId: provider.id)));
      },
      child: Scaffold(
        backgroundColor: _P.bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true, expandedHeight: 140, backgroundColor: _P.rose,
              flexibleSpace: FlexibleSpaceBar(background: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_P.rose, Color(0xFFFF85A1)], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Bonjour 👋', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(provider.businessName, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              ]))))),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate([
                // ── STATS GRID ───────────────────────────────────────────
                statsAsync.when(
                  data: (stats) => GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3, children: [
                    _StatCard(title: 'Réservations', value: '${stats['total_reservations'] ?? 0}', icon: Icons.event_note_rounded, color: _P.blue),
                    _StatCard(title: 'Confirmées', value: '${stats['confirmed_reservations'] ?? 0}', icon: Icons.check_circle_rounded, color: _P.green),
                    _StatCard(title: 'Revenus', value: '\$${NumberFormat('#,###').format(stats['total_revenue'] ?? 0)}', icon: Icons.attach_money_rounded, color: _P.amber),
                    _StatCard(title: 'Tâches actives', value: '${(stats['total_tasks'] ?? 0) - (stats['completed_tasks'] ?? 0)}', icon: Icons.assignment_turned_in_rounded, color: _P.rose),
                  ]),
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: 24),
                Text('Actions rapides', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _ActionTile(icon: Icons.add_photo_alternate_outlined, label: 'Ajouter\nmédias', color: _P.blue, onTap: () => context.go('/thix-weeding/provider/gallery'))),
                  const SizedBox(width: 12),
                  Expanded(child: _ActionTile(icon: Icons.calendar_month_outlined, label: 'Voir\ndemandes', color: _P.green, onTap: () => context.go('/thix-weeding/provider/reservations'))),
                  const SizedBox(width: 12),
                  Expanded(child: _ActionTile(icon: Icons.task_alt_outlined, label: 'Mes\ntâches', color: _P.rose, onTap: () => context.go('/thix-weeding/provider/tasks'))),
                ]),

                const SizedBox(height: 24),
                Row(children: [
                  Text('Dernières activités', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
                  const Spacer(),
                  TextButton(onPressed: () => context.go('/thix-weeding/provider/reservations'), child: Text('Tout voir', style: GoogleFonts.inter(color: _P.rose, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 8),
                
                // ── RECENT RESERVATIONS ──────────────────────────────────
                reservationsAsync.when(
                  data: (reservations) => reservations.isEmpty
                      ? _EmptyState(icon: Icons.event_busy_outlined, message: 'Aucune réservation pour le moment.')
                      : Column(children: reservations.take(3).map((r) => _ActivityItem(
                          title: r.clientName, subtitle: DateFormat('dd MMM yyyy').format(r.eventDate), status: r.status.name, isPositive: r.status == ReservationStatus.confirmed,
                        )).toList()),
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: 16),
                
                // ── RECENT TASKS ─────────────────────────────────────────
                tasksAsync.when(
                  data: (tasks) => tasks.isEmpty
                      ? _EmptyState(icon: Icons.task_outlined, message: 'Aucune tâche assignée.')
                      : Column(children: tasks.where((t) => t.status != TaskStatus.completed).take(2).map((t) => _ActivityItem(
                          title: t.title, subtitle: 'Échéance: ${DateFormat('dd MMM HH:mm').format(t.dueDateTime)}', status: t.status.name, isPositive: false,
                        )).toList()),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: 40),
              ])),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNES
// ═══════════════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _P.line), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)), const Spacer(), Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)), Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _P.inkSoft))]));
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.line), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _P.ink, height: 1.2))])));
}

class _ActivityItem extends StatelessWidget {
  final String title; final String subtitle; final String status; final bool isPositive;
  const _ActivityItem({required this.title, required this.subtitle, required this.status, required this.isPositive});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.line)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)), Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft))])), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (isPositive ? _P.green : _P.amber).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: isPositive ? _P.green : _P.amber)))]));
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.line, style: BorderStyle.solid)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: _P.inkSoft, size: 18), const SizedBox(width: 8), Text(message, style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic))]));
}
