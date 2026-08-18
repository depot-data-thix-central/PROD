import 'package:flutter/material.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
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

class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _ThixColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ThixColors.cardBorder),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: const [
          _LegendItem(color: _ThixColors.seatAvailable, label: 'Disponible'),
          _LegendItem(color: _ThixColors.primary, label: 'Selectionnee'),
          _LegendItem(color: _ThixColors.seatReserved, label: 'Reservee (15min)'),
          _LegendItem(color: _ThixColors.seatSold, label: 'Vendue'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          border: Border.all(color: color, width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _ThixColors.textSecondary)),
    ]);
  }
}
