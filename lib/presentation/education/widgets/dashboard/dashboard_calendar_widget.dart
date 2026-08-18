// lib/presentation/education/widgets/dashboard/dashboard_calendar_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _C {
  static const primary = Color(0xFF2D6CDF);
  static const textMain = Color(0xFF1A1A2E);
  static const textMuted = Color(0xFF7386A8);
  static const surface = Colors.white;
}

class DashboardCalendarWidget extends StatefulWidget {
  final DateTime? initialDate;
  final List<DateTime>? highlightedDates;
  final Function(DateTime)? onDateSelected;

  const DashboardCalendarWidget({
    super.key,
    this.initialDate,
    this.highlightedDates,
    this.onDateSelected,
  });

  @override
  State<DashboardCalendarWidget> createState() => _DashboardCalendarWidgetState();
}

class _DashboardCalendarWidgetState extends State<DashboardCalendarWidget> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  
  // Optimisation O(1) pour les dates mises en évidence
  late Set<String> _highlightedSet;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _currentMonth = DateTime(initial.year, initial.month, 1);
    _selectedDate = initial;
    _updateHighlightedSet();
  }

  @override
  void didUpdateWidget(covariant DashboardCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedDates != oldWidget.highlightedDates) {
      _updateHighlightedSet();
    }
  }

  // Transforme la liste en Set de chaînes 'YYYY-MM-DD' pour une recherche instantanée
  void _updateHighlightedSet() {
    _highlightedSet = (widget.highlightedDates ?? [])
        .map((d) => '${d.year}-${d.month}-${d.day}')
        .toSet();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    // DateTime.weekday retourne 1 (Lundi) à 7 (Dimanche)
    // Pour que l'index 0 corresponde à Lundi, on fait - 1.
    final offset = firstDayOfMonth.weekday - 1; 

    // Mise en cache de la date du jour pour éviter des appels système répétés
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final selectedKey = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F44).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête du mois
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                color: _C.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 24,
              ),
              Text(
                toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'fr').format(_currentMonth)) ?? '',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _C.textMain,
                  letterSpacing: 0.3,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                color: _C.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 24,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Jours de la semaine
          Row(
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((label) => Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _C.textMuted,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          
          // Grille des jours
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: offset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < offset) return const SizedBox();
              
              final day = index - offset + 1;
              final dateKey = '${_currentMonth.year}-${_currentMonth.month}-$day';
              
              final isToday = dateKey == todayKey;
              final isSelected = dateKey == selectedKey;
              final isHighlighted = _highlightedSet.contains(dateKey);

              return GestureDetector(
                onTap: () {
                  final newDate = DateTime(_currentMonth.year, _currentMonth.month, day);
                  setState(() => _selectedDate = newDate);
                  widget.onDateSelected?.call(newDate);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _C.primary
                        : isToday
                            ? _C.primary.withOpacity(0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(color: _C.primary.withOpacity(0.3), width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? _C.primary
                                  : _C.textMain,
                        ),
                      ),
                      if (isHighlighted && !isSelected)
                        Positioned(
                          bottom: 6,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: _C.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
