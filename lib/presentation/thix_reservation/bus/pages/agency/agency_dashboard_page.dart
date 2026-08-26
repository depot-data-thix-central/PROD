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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agencyDashboardProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyDashboardProvider);
    final notifier = ref.read(agencyDashboardProvider.notifier);

    if (!state.isLoading && !state.hasAgency) {
      return Scaffold(
        backgroundColor: ThixPolicy.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Mon Agence', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 56, color: ThixPolicy.textSecondary),
                const SizedBox(height: 12),
                const Text(
                  'Aucune agence liée à ce compte',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/agency/onboarding'),
                  child: const Text('Créer mon agence'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        title: Text(
          state.myAgency?.name ?? 'Mon Agence',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.textMain),
            onPressed: state.isAgencyActive ? () => context.push('/agency/scan') : null,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: ThixPolicy.primary),
            onPressed: state.isAgencyActive ? () => context.push('/agency/trip/create') : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
          : RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: Colors.white,
              onRefresh: () => notifier.init(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.isPending)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Agence en attente de validation. Le dashboard complet s’ouvre dès le statut active.',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Réservations du jour',
                            value: '${state.todayBookingsCount}',
                            icon: Icons.receipt_long_rounded,
                            color: ThixPolicy.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Revenu du jour',
                            value: '${state.todayRevenue} FC',
                            icon: Icons.payments_rounded,
                            color: ThixPolicy.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Trajets à venir',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain),
                    ),
                    const SizedBox(height: 10),
                    if (state.myTrips.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(30),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                          border: Border.all(color: ThixPolicy.border),
                        ),
                        child: const Text(
                          'Aucun trajet programmé',
                          style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.myTrips.length,
                        itemBuilder: (_, i) {
                          final trip = state.myTrips[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                              border: Border.all(color: ThixPolicy.border),
                              boxShadow: ThixPolicy.shadowSoft(),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_bus_rounded, color: ThixPolicy.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${trip.departureCity} → ${trip.arrivalCity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: ThixPolicy.textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${trip.priceFcfa} FCFA • ${trip.availableSeats} places dispo',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: ThixPolicy.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
