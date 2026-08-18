// lib/presentation/thix_reservation/bus/widgets/client/agency_trip_card.dart
import 'package:flutter/material.dart';
import '../../data/models/bus_trip_model.dart';

class AgencyTripCard extends StatelessWidget {
  final BusTripModel trip;
  final VoidCallback onTap;
  const AgencyTripCard({super.key, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [
        CircleAvatar(radius: 18, backgroundColor: Colors.blue.shade50, backgroundImage: trip.agency?.logoUrl!= null? NetworkImage(trip.agency!.logoUrl!): null, child: trip.agency?.logoUrl== null? Text(trip.agency?.name.substring(0,1)?? 'A', style: const TextStyle(fontWeight: FontWeight.bold)): null),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(trip.agency?.name?? 'Agence', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), if (trip.agency?.isVerified== true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: Colors.blue))]), Text('${trip.busType.toUpperCase()} • ${trip.durationLabel}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${trip.priceFcfa} FCFA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0D47A1))), if (trip.isAlmostFull) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)), child: Text('Plus que ${trip.availableSeats}!', style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold))) else Text('${trip.availableSeats} places', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])
      ]),
      const Divider(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _TimeBox(time: '${trip.departureTime.hour.toString().padLeft(2,'0')}:${trip.departureTime.minute.toString().padLeft(2,'0')}', city: trip.departureCity),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Stack(alignment: Alignment.center, children: [Divider(color: Colors.grey.shade300), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.directions_bus, size: 14, color: Colors.grey.shade600))]))),
        _TimeBox(time: '${trip.arrivalTime.hour.toString().padLeft(2,'0')}:${trip.arrivalTime.minute.toString().padLeft(2,'0')}', city: trip.arrivalCity, alignEnd: true),
      ])
    ]))));
  }
}

class _TimeBox extends StatelessWidget {
  final String time; final String city; final bool alignEnd;
  const _TimeBox({required this.time, required this.city, this.alignEnd = false});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: alignEnd? CrossAxisAlignment.end: CrossAxisAlignment.start, children: [Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(city, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]);
  }
}
