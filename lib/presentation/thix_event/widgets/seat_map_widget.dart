import 'package:flutter/material.dart';
import '../../../models/event_seat.dart';

class _ThixColors {
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
  static const seatAvailable = Color(0xFF10B981);
  static const seatReserved = Color(0xFFF59E0B);
  static const seatSold = Color(0xFFEF4444);
}

class SeatMapWidget extends StatelessWidget {
  final List<EventSeat> seats;
  final List<EventSeat> selectedSeats;
  final Function(EventSeat) onSeatTap;
  const SeatMapWidget({super.key, required this.seats, required this.selectedSeats, required this.onSeatTap});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<EventSeat>> rows = {};
    for (var s in seats) { rows.putIfAbsent(s.row, () => []).add(s); }
    final sorted = rows.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: _ThixColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ThixColors.cardBorder),
          ),
          child: const Center(child: Text('SCENE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 4, color: _ThixColors.textMuted))),
        ),
        for (var row in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 28, child: Text(row, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white))),
              Expanded(
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: rows[row]!.map((seat) {
                    final sel = selectedSeats.any((s) => s.id == seat.id);
                    Color col;
                    if (sel) col = _ThixColors.primary;
                    else if (seat.isSold) col = _ThixColors.seatSold;
                    else if (seat.isReserved) col = _ThixColors.seatReserved;
                    else col = _ThixColors.seatAvailable;

                    return GestureDetector(
                      onTap: (seat.isAvailable || sel)? () => onSeatTap(seat) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: sel? col.withOpacity(0.22) : col.withOpacity(0.12),
                          border: Border.all(color: col, width: sel? 2 : 1.2),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
                          boxShadow: sel? [BoxShadow(color: col.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
                        ),
                        child: Center(child: Text(seat.number.toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: col))),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 18),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: _ThixColors.cardBorder)),
          child: const Center(child: Text('COULOIR CENTRAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: _ThixColors.textMuted))),
        ),
      ]),
    );
  }
}
