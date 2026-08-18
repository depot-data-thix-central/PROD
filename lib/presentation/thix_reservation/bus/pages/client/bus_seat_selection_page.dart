// lib/presentation/thix_reservation/bus/pages/client/bus_seat_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../data/models/bus_trip_model.dart';
import '../../providers/seat_selection_provider.dart';
import '../../widgets/client/seat_map_widget.dart';

class BusSeatSelectionPage extends ConsumerStatefulWidget {
  final BusTripModel trip;
  const BusSeatSelectionPage({super.key, required this.trip});

  @override
  ConsumerState<BusSeatSelectionPage> createState() => _BusSeatSelectionPageState();
}

class _BusSeatSelectionPageState extends ConsumerState<BusSeatSelectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(seatSelectionProvider.notifier).init(widget.trip.id, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 Écoute moderne de l'état Riverpod
    final state = ref.watch(seatSelectionProvider);
    final notifier = ref.read(seatSelectionProvider.notifier);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Choix des sièges',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
        actions: [
          if (state.lockRemainingSeconds > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⏳ ${state.lockRemainingSeconds ~/ 60}:${(state.lockRemainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ThixPolicy.danger),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🌟 Légende modernisée
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: ThixPolicy.border),
                      boxShadow: ThixPolicy.shadowSoft(),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Legend(color: Colors.white, label: 'Libre'),
                        _Legend(color: Color(0xFFE2E8F0), label: 'Occupé'),
                        _Legend(color: ThixPolicy.primary, label: 'Sélectionné'),
                        _Legend(color: Color(0xFFFEF3C7), label: 'VIP +1000'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Plan des sièges
                  SeatMapWidget(
                    seats: state.seats,
                    selected: state.selectedSeats,
                    onTap: (seat) => notifier.toggleSeat(seat),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Récapitulatif sélection
                  if (state.selectedSeats.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThixPolicy.tint,
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat_rounded, color: ThixPolicy.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sièges : ${state.selectedSeats.join(', ')}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain),
                            ),
                          ),
                          if (state.totalVipSupplement > 0)
                            Text(
                              '+${state.totalVipSupplement} FCFA VIP',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.warning),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: ThixPolicy.border)),
          boxShadow: ThixPolicy.shadowCard(),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: state.selectedSeats.isEmpty
                    ? null
                    : () async {
                        await notifier.confirmAndUnlockForPayment();
                        if (context.mounted) {
                          context.push(
                            '/thix-reservation/bus/passenger',
                            extra: {'trip': widget.trip, 'seats': state.selectedSeats.toList()},
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                ),
                child: Text(
                  'Continuer (${state.selectedSeats.length})',
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
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: ThixPolicy.border),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textMain),
        ),
      ],
    );
  }
}
