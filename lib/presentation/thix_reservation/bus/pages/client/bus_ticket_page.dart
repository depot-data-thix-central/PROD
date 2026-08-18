// lib/presentation/thix_reservation/bus/pages/client/bus_ticket_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../data/models/booking_model.dart';

class BusTicketPage extends StatelessWidget {
  final BookingModel booking;
  const BusTicketPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final trip = booking.trip;
    final isConfirmed = booking.status == 'confirmed' || booking.status == 'completed';

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mon billet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🌟 Carte principale du billet
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowCard(),
              ),
              child: Column(
                children: [
                  // En-tête : Agence et Statut
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trip?.agency?.name ?? 'Agence partenaire',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConfirmed ? ThixPolicy.success.withOpacity(0.1) : ThixPolicy.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          booking.status.toUpperCase(),
                          style: TextStyle(
                            color: isConfirmed ? ThixPolicy.success : ThixPolicy.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Code QR central
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surface,
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: QrImageView(
                      data: booking.qrCode,
                      size: 180,
                      version: QrVersions.auto,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ThixPolicy.textMain),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ThixPolicy.textMain),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Code texte du QR
                  Text(
                    booking.qrCode,
                    style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textSecondary),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1, color: ThixPolicy.border),
                  ),

                  // Itinéraire (Départ → Arrivée)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip?.departureCity ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip != null ? '${trip.departureTime.hour.toString().padLeft(2, '0')}:${trip.departureTime.minute.toString().padLeft(2, '0')}' : '',
                            style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded, size: 16, color: ThixPolicy.primary),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            trip?.arrivalCity ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip != null ? '${trip.arrivalTime.hour.toString().padLeft(2, '0')}:${trip.arrivalTime.minute.toString().padLeft(2, '0')}' : '',
                            style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sièges et Prix total
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surface,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_seat_rounded, size: 16, color: ThixPolicy.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Siège(s) : ${booking.seats.join(', ')}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ThixPolicy.textMain),
                            ),
                          ],
                        ),
                        Text(
                          '${booking.totalPriceFcfa} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Consigne informative
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_rounded, size: 14, color: ThixPolicy.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Présentez ce QR à l\'embarquement. Lié à votre THIX ID.',
                  style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
