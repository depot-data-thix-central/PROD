import 'package:flutter/material.dart';

class _ThixColors {
  static const surface = Color(0xFF0C0C12);
  static const cardBorder = Color(0x14FFFFFF);
  static const cardBorderStrong = Color(0x26FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class DateFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  const DateFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? _ThixColors.primary.withOpacity(0.14) : _ThixColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? _ThixColors.primary : _ThixColors.cardBorderStrong, width: isSelected ? 1.2 : 1),
          boxShadow: [if (isSelected) BoxShadow(color: _ThixColors.primary.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : _ThixColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class DateFilterRow extends StatefulWidget {
  final Function(String) onFilterChanged;
  final String initialFilter;
  const DateFilterRow({super.key, required this.onFilterChanged, this.initialFilter = 'all'});
  @override
  State<DateFilterRow> createState() => _DateFilterRowState();
}

class _DateFilterRowState extends State<DateFilterRow> {
  late String _selectedFilter;

  final _filters = const [
    {'value': 'today', 'label': "Aujourdhui"},
    {'value': 'week', 'label': 'Cette semaine'},
    {'value': 'month', 'label': 'Ce mois'},
    {'value': 'all', 'label': 'Tous'},
  ];

  @override
  void initState() { super.initState(); _selectedFilter = widget.initialFilter; }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _filters.map((f) {
          final isSel = _selectedFilter == f['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DateFilterChip(
              label: f['label']!,
              value: f['value']!,
              isSelected: isSel,
              onTap: () { setState(() => _selectedFilter = f['value']!); widget.onFilterChanged(f['value']!); },
            ),
          );
        }).toList(),
      ),
    );
  }
}
