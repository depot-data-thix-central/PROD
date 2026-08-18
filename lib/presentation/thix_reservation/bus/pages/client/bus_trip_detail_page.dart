// lib/presentation/thix_reservation/bus/pages/client/bus_trip_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../data/models/bus_trip_model.dart';

class BusTripDetailPage extends StatelessWidget {
  final BusTripModel trip;
  const BusTripDetailPage({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          '${trip.departureCity} → ${trip.arrivalCity}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 Header Agence SaaS
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ThixPolicy.tint,
                    backgroundImage: trip.agency?.logoUrl != null ? NetworkImage(trip.agency!.logoUrl!) : null,
                    child: trip.agency?.logoUrl == null
                        ? Text(
                            trip.agency?.name.isNotEmpty == true ? trip.agency!.name[0] : 'A',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: ThixPolicy.primaryDeep),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trip.agency?.name ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trip.agency?.isVerified == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, color: ThixPolicy.primary, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${trip.busType.toUpperCase()} • ${trip.agency?.ratingAvg ?? 0} ⭐ (${trip.agency?.ratingCount ?? 0} avis)',
                          style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🌟 Carte Itinéraire et Horaires
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.departureTime.hour.toString().padLeft(2, '0')}:${trip.departureTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: ThixPolicy.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(trip.departureCity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain)),
                      const SizedBox(height: 2),
                      Text(trip.departureStation, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(trip.durationLabel, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: ThixPolicy.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: trip.availableSeats > 0 ? ThixPolicy.success.withOpacity(0.1) : ThixPolicy.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          trip.availableSeats > 0 ? '${trip.availableSeats} places' : 'Complet',
                          style: TextStyle(
                            fontSize: 10,
                            color: trip.availableSeats > 0 ? ThixPolicy.success : ThixPolicy.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${trip.arrivalTime.hour.toString().padLeft(2, '0')}:${trip.arrivalTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: ThixPolicy.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(trip.arrivalCity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain)),
                      const SizedBox(height: 2),
                      Text(trip.arrivalStation, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🌟 Équipements (Amenities)
            if (trip.amenities.isNotEmpty) ...[
              const Text('Équipements à bord', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: trip.amenities.map((a) => Chip(
                  label: Text(a, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.primaryDeep)),
                  backgroundColor: ThixPolicy.tint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: ThixPolicy.border)),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // 🌟 Politique de l'agence
            const Text('Politique agence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Text(
                trip.agency?.description ?? 'Aucune politique renseignée par l\'agence.',
                style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 40),
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
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${trip.priceFcfa} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.success),
                  ),
                  const Text('par place • frais inclus', style: TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: trip.isFull ? null : () => context.push('/thix-reservation/bus/seats/${trip.id}', extra: trip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(
                    trip.isFull ? 'Complet' : 'Choisir sièges',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
