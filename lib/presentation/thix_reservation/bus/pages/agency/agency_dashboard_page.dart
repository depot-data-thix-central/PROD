// lib/presentation/thix_reservation/bus/pages/agency/agency_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/agency_dashboard_provider.dart';

class AgencyDashboardPage extends ConsumerStatefulWidget {
  const AgencyDashboardPage({super.key});
  @override
  ConsumerState<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends ConsumerState<AgencyDashboardPage> {
  String _fx = 'CDF';
  static const double usdToCdf = 2850;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agencyDashboardProvider.notifier).init();
    });
  }

  String _money(num amountCdf) {
    if (_fx == 'USD') {
      final usd = amountCdf / usdToCdf;
      return '${usd.toStringAsFixed(2)} USD';
    }
    return '${amountCdf.toStringAsFixed(0)} CDF';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyDashboardProvider);
    final agency = state.myAgency;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.hasAgency) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon Agence')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/agency/onboarding'),
            child: const Text('Créer mon agence'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(agency!.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(
              '${agency.countryCode} • ${agency.status}',
              style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () => context.push('/agency/scan'), icon: const Icon(Icons.qr_code_scanner)),
          IconButton(onPressed: () => context.push('/agency/trip/create'), icon: const Icon(Icons.add, color: ThixPolicy.primary)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ThixPolicy.primary,
        onPressed: () => context.push('/agency/trip/create'),
        icon: const Icon(Icons.add_road, color: Colors.white),
        label: const Text('Nouveau trajet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(agencyDashboardProvider.notifier).init(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Row(
              children: [
                const Text('Devise', style: TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'CDF', label: Text('CDF')),
                    ButtonSegment(value: 'USD', label: Text('USD')),
                  ],
                  selected: {_fx},
                  onSelectionChanged: (s) => setState(() => _fx = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Kpi('Réservations du jour', '${state.todayBookingsCount}', Icons.receipt_long, ThixPolicy.primary)),
              const SizedBox(width: 10),
              Expanded(child: _Kpi('Revenu du jour', _money(state.todayRevenue), Icons.payments, ThixPolicy.success)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Kpi('Trajets', '${state.myTrips.length}', Icons.directions_bus, ThixPolicy.primaryDeep)),
              const SizedBox(width: 10),
              Expanded(child: _Kpi('À venir', '${state.pendingDepartures}', Icons.schedule, Colors.orange)),
            ]),
            const SizedBox(height: 18),
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Action('Nouveau trajet', Icons.add_road, () => context.push('/agency/trip/create')),
              _Action('Scanner ticket', Icons.qr_code_scanner, () => context.push('/agency/scan')),
              _Action('Mes sièges', Icons.event_seat, () {
                if (state.myTrips.isNotEmpty) {
                  context.push('/agency/seats?tripId=${state.myTrips.first.id}');
                }
              }),
              _Action('Onboarding', Icons.storefront, () => context.push('/agency/onboarding')),
            ]),
            const SizedBox(height: 22),
            const Text('Trajets à venir', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 8),
            if (state.myTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun trajet. Appuie sur + pour publier.', textAlign: TextAlign.center),
              )
            else
              ...state.myTrips.map((t) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/agency/seats?tripId=${t.id}'),
                    child: Row(children: [
                      const Icon(Icons.directions_bus_rounded, color: ThixPolicy.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${t.departureCity} → ${t.arrivalCity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            '${t.priceFcfa} • ${t.availableSeats} places • ${t.status}',
                            style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary),
                          ),
                        ]),
                      ),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: 22),
            const Text('Dernières réservations', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 8),
            if (state.agencyBookings.isEmpty)
              const Text('Aucune réservation', style: TextStyle(color: ThixPolicy.textSecondary))
            else
              ...state.agencyBookings.take(10).map((b) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text(b.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(b.status),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary)),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Action(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      onPressed: onTap,
    );
  }
}
