// lib/presentation/thix_reservation/bus/pages/client/bus_payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../data/models/bus_trip_model.dart';
import '../../providers/booking_provider.dart';

class BusPaymentPage extends ConsumerWidget {
  final BusTripModel trip;
  final List<String> seats;
  const BusPaymentPage({super.key, required this.trip, required this.seats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 Écoute moderne de l'état Riverpod
    final state = ref.watch(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);

    final base = trip.priceFcfa * seats.length;
    const serviceFee = 300;
    final total = base + serviceFee;

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
          'Paiement',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🌟 Carte de récapitulatif financier
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowCard(),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trajet', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${trip.departureCity} → ${trip.arrivalCity}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: ThixPolicy.textMain)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: ThixPolicy.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sièges', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(seats.join(', '), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: ThixPolicy.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sous-total', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('$base FCFA', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Frais de service THIX', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('$serviceFee FCFA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: ThixPolicy.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total à payer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain)),
                      Text('$total FCFA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.success)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: ThixPolicy.border)),
          boxShadow: ThixPolicy.shadowCard(),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isPaying
                      ? null
                      : () async {
                          try {
                            final booking = await notifier.createBookingAndPay(
                              agencyId: trip.agencyId,
                              tripId: trip.id,
                              seats: seats,
                              basePrice: trip.priceFcfa,
                              vipSupplement: 0,
                            );
                            if (context.mounted) {
                              context.go('/thix-reservation/bus/ticket/${booking.id}', extra: booking);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: $e'),
                                  backgroundColor: ThixPolicy.danger,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                  ),
                  child: state.isPaying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Payer maintenant',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Paiement sécurisé lié à votre THIX ID • ${trip.agency?.name ?? 'Agence'}',
                style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
