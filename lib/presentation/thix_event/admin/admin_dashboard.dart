import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/admin_constants.dart';
import 'core/admin_guards.dart';
import 'providers/admin_event_provider.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  AdminRole _role = AdminRole.superAdmin;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _role = await AdminGuard.getCurrentRole();
    if (mounted) setState(() {});
    Future.microtask(() => ref.read(adminEventProvider.notifier).loadDashboardStats());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminEventProvider);
    final notifier = ref.read(adminEventProvider.notifier);

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85),
              elevation: 0,
              title: Row(children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _ThixColors.primary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.shield_rounded, size: 16, color: _ThixColors.primary)),
                const SizedBox(width: 10),
                const Text('THIX ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                const SizedBox(width: 8),
                if (AdminConstants.isDevOpenAccess)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.withOpacity(0.3))), child: const Text('DEV OPEN', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.w900))),
              ]),
              actions: [
                IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18), onPressed: () => notifier.loadDashboardStats()),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildStatsGrid(state)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ACTIONS', style: TextStyle(color: _ThixColors.textMuted.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)))),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(child: _buildActionGrid(_role)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AdminEventState s) {
    if (s.statsLoading && s.stats.totalEvents == 0) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        _StatCard(label: 'Events', value: '${s.stats.totalEvents}', icon: Icons.event_rounded),
        _StatCard(label: 'Bookings', value: '${s.stats.totalBookings}', icon: Icons.confirmation_number_rounded),
        _StatCard(label: 'Revenu', value: '${s.stats.totalRevenue}', icon: Icons.payments_rounded),
        _StatCard(label: 'File', value: '${s.stats.waitingQueue}', icon: Icons.hourglass_top_rounded),
      ]),
    );
  }

  Widget _buildActionGrid(AdminRole role) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          _ActionCard('Evenements', '20 / page', Icons.list_alt_rounded, '/thix-event/admin/events', role),
          _ActionCard('Creer', 'Upload + validation', Icons.add_circle_rounded, '/thix-event/admin/events/create', role),
          _ActionCard('Sieges', 'Batch 200', Icons.event_seat_rounded, '/thix-event/admin/seats', role),
          _ActionCard('Reservations', '50 / page + filtres', Icons.receipt_long_rounded, '/thix-event/admin/bookings', role),
          _ActionCard('Anti-Fraude', 'Limits', Icons.security_rounded, '/thix-event/admin/limits', role),
          _ActionCard('Analytics', 'RPC', Icons.analytics_rounded, '/thix-event/admin/analytics', role),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ThixColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _ThixColors.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: Icon(icon, size: 16, color: Colors.white)),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle, route;
  final IconData icon;
  final AdminRole role;
  const _ActionCard(this.title, this.subtitle, this.icon, this.route, this.role);
  @override
  Widget build(BuildContext context) {
    final canWrite = AdminGuard.canWrite(role);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle), child: Icon(icon, size: 18, color: Colors.white)),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10)),
          if (!canWrite && title == 'Creer') const Padding(padding: EdgeInsets.only(top: 4), child: Text('Lecture seule', style: TextStyle(color: Colors.red, fontSize: 9))),
        ]),
      ),
    );
  }
}
