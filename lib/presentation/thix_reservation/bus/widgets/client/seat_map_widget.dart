// lib/presentation/thix_reservation/bus/widgets/client/seat_map_widget.dart
import 'package:flutter/material.dart';
import '../../data/models/seat_model.dart';

class SeatMapWidget extends StatelessWidget {
  final List<SeatModel> seats;
  final Set<String> selected;
  final Function(SeatModel) onTap;
  const SeatMapWidget({super.key, required this.seats, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // On suppose bus 4 sièges par rangée: A B | couloir | C D
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1),
      itemCount: seats.length,
      itemBuilder: (_, i) {
        if ((i+1)%3==0) return const Icon(Icons.confirmation_number, color: Colors.transparent); // couloir
        final seatIndex = i - (i/3).floor() - (i>=3?1:0);
        if (seatIndex >= seats.length) return const SizedBox();
        final seat = seats[seatIndex];
        final isSelected = selected.contains(seat.seatNumber);
        Color color;
        if (!seat.isAvailable) color = Colors.grey.shade300;
        else if (isSelected) color = const Color(0xFF0D47A1);
        else if (seat.isVip) color = Colors.amber.shade100;
        else color = Colors.white;

        return InkWell(
          onTap: seat.isAvailable? () => onTap(seat): null,
          borderRadius: BorderRadius.circular(8),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected? const Color(0xFF0D47A1): Colors.grey.shade300)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.airline_seat_recline_normal, size: 18, color: isSelected? Colors.white: seat.isAvailable? Colors.black87: Colors.grey), Text(seat.seatNumber, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected? Colors.white: Colors.black87))]))),
        );
      },
    );
  }
}
