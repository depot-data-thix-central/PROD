// lib/presentation/thix_reservation/bus/pages/client/bus_seat_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../data/models/bus_trip_model.dart';
import '../../providers/seat_selection_provider.dart';
import '../../widgets/client/seat_map_widget.dart';

class BusSeatSelectionPage extends ConsumerStatefulWidget {
  final BusTripModel? trip;
  final String? tripId;

  const BusSeatSelectionPage({
    super.key,
    this.trip,
    this.tripId,
  });

  @override
  ConsumerState<BusSeatSelectionPage> createState() => _BusSeatSelectionPageState();
}

class _BusSeatSelectionPageState extends ConsumerState<BusSeatSelectionPage> {
  String two(int n) {
    final s = n.toString();
    if (s.length == 1) return '0' + s;
    return s;
  }

  String lockLabel(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds - (m * 60);
    return two(m) + ':' + two(s);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.trip?.id ?? widget.tripId ?? '';
      if (id.isNotEmpty) {
        ref.read(seatSelectionProvider.notifier).init(id, 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seatSelectionProvider);
    final notifier = ref.read(seatSelectionProvider.notifier);
    final trip = widget.trip;

    final base = trip?.priceFcfa ?? 0;
    final count = state.selectedSeats.length;
    final vip = state.totalVipSupplement;
    final total = (base * count) + vip;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choix des sieges',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            if (trip != null)
              Text(
                trip.departureCity + ' → ' + trip.arrivalCity,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          if (state.lockRemainingSeconds > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Lock ' + lockLabel(state.lockRemainingSeconds),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Legend(color: Colors.white, label: 'Libre'),
                      _Legend(color: Color(0xFF64748B), label: 'Pris'),
                      _Legend(color: Color(0xFF2563EB), label: 'Choisi'),
                      _Legend(color: Color(0xFFFBBF24), label: 'VIP'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: const Color(0xFF334155), width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.sports_esports, color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Text('Conducteur', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.door_front_door_outlined, color: Colors.white54),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: SeatMapWidget(
                            seats: state.seats,
                            selected: state.selectedSeats,
                            onTap: (seat) => notifier.toggleSeat(seat),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Couloir central',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (state.selectedSeats.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sieges : ' + state.selectedSeats.join(', '),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          count.toString() + ' x ' + base.toString() + ' CDF',
                          style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12),
                        ),
                        if (vip > 0)
                          Text(
                            'Supplement VIP +' + vip.toString() + ' CDF',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.warning),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Total ' + total.toString() + ' CDF',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.success),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: state.selectedSeats.isEmpty || trip == null
                    ? null
                    : () async {
                        await notifier.confirmAndUnlockForPayment();
                        if (!context.mounted) return;
                        context.push(
                          '/thix-reservation/bus/payment',
                          extra: {
                            'trip': trip,
                            'seats': state.selectedSeats.toList(),
                          },
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                ),
                child: Text(
                  state.selectedSeats.isEmpty
                      ? 'Choisissez un siege'
                      : 'Continuer  •  ' + total.toString() + ' CDF',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }
}
