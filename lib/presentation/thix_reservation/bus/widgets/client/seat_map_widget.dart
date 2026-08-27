// lib/presentation/thix_reservation/bus/widgets/client/seat_map_widget.dart
import 'package:flutter/material.dart';
import '../../data/models/seat_model.dart';

class SeatMapWidget extends StatelessWidget {
  final List<SeatModel> seats;
  final Set<String> selected;
  final Function(SeatModel) onTap;

  const SeatMapWidget({
    super.key,
    required this.seats,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <List<SeatModel>>[];
    for (var i = 0; i < seats.length; i += 4) {
      final end = i + 4 > seats.length ? seats.length : i + 4;
      rows.add(seats.sublist(i, end));
    }

    return Column(
      children: rows.map((row) {
        final left = row.length >= 2 ? row.sublist(0, 2) : row;
        final right = row.length > 2 ? row.sublist(2) : <SeatModel>[];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...left.map((s) => _SeatCell(
                    seat: s,
                    selected: selected.contains(s.seatNumber),
                    onTap: onTap,
                  )),
              const SizedBox(
                width: 28,
                child: Icon(Icons.more_vert, size: 12, color: Colors.white24),
              ),
              ...right.map((s) => _SeatCell(
                    seat: s,
                    selected: selected.contains(s.seatNumber),
                    onTap: onTap,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SeatCell extends StatelessWidget {
  final SeatModel seat;
  final bool selected;
  final Function(SeatModel) onTap;

  const _SeatCell({
    required this.seat,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color fg = const Color(0xFF111827);
    Color border = const Color(0xFFD1D5DB);

    if (!seat.isAvailable) {
      bg = const Color(0xFF64748B);
      fg = Colors.white70;
      border = const Color(0xFF475569);
    } else if (selected) {
      bg = const Color(0xFF2563EB);
      fg = Colors.white;
      border = const Color(0xFF1D4ED8);
    } else if (seat.isVip) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      border = const Color(0xFFF59E0B);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: seat.isAvailable ? () => onTap(seat) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.airline_seat_recline_normal, size: 16, color: fg),
              Text(
                seat.seatNumber,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
