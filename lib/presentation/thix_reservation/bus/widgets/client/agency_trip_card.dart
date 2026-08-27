// lib/presentation/thix_reservation/bus/widgets/client/agency_trip_card.dart
import 'package:flutter/material.dart';
import '../../data/models/bus_trip_model.dart';

class AgencyTripCard extends StatelessWidget {
  final BusTripModel trip;
  final VoidCallback onTap;

  const AgencyTripCard({
    super.key,
    required this.trip,
    required this.onTap,
  });

  String two(int n) {
    final s = n.toString();
    if (s.length == 1) return '0' + s;
    return s;
  }

  String hhmm(DateTime d) {
    return two(d.hour) + ':' + two(d.minute);
  }

  @override
  Widget build(BuildContext context) {
    final agencyName = trip.agency?.name ?? 'Agence';
    final initial = agencyName.isNotEmpty ? agencyName.substring(0, 1) : 'A';
    final logo = trip.agency?.logoUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: logo != null ? NetworkImage(logo) : null,
                    child: logo == null
                        ? Text(initial, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                agencyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                            if (trip.agency?.isVerified == true)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                              ),
                          ],
                        ),
                        Text(
                          trip.busType.toUpperCase() + ' • ' + trip.durationLabel,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trip.priceFcfa.toString() + ' CDF',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0D47A1)),
                      ),
                      if (trip.isAlmostFull)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Plus que ' + trip.availableSeats.toString(),
                            style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C), fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        Text(
                          trip.availableSeats.toString() + ' places',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TimeBox(time: hhmm(trip.departureTime), city: trip.departureCity),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Divider(color: Color(0xFFD1D5DB)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_bus, size: 14, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _TimeBox(time: hhmm(trip.arrivalTime), city: trip.arrivalCity, alignEnd: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String time;
  final String city;
  final bool alignEnd;

  const _TimeBox({
    required this.time,
    required this.city,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(time, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(city, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ],
    );
  }
}
