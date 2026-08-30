// lib/presentation/thix_market/services/service_calendar.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kBookingTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMinDaysAhead = 1;
const int _kMaxDaysAhead = 60;
const int _kDefaultDaysAhead = 30;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ServiceValidators {
  _ServiceValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatTimeKey(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('unique') || msg.contains('duplicate') || msg.contains('conflict')) {
      return 'Ce créneau vient d\'être réservé. Choisissez-en un autre.';
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _ServiceL10n on BuildContext {
  String svcT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _svcRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[ServiceCalendar] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ServiceCalendar] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ServiceCalendar] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// BOOKING SLOT INDEX (O(1) lookup)
// ============================================================================
class _BookedSlotsIndex {
  final Map<String, Set<String>> _index = {}; // date -> Set<time>

  _BookedSlotsIndex(List<Map<String, dynamic>> slots) {
    for (final slot in slots) {
      final date = slot['booking_date']?.toString();
      final time = slot['booking_time']?.toString();
      if (date != null && time != null) {
        _index.putIfAbsent(date, () => <String>{}).add(time);
      }
    }
  }

  bool isBooked(DateTime date, TimeOfDay time) {
    final dateKey = _ServiceValidators.formatDateKey(date);
    final timeKey = _ServiceValidators.formatTimeKey(time);
    return _index[dateKey]?.contains(timeKey) ?? false;
  }

  int countBookings(DateTime date) {
    final dateKey = _ServiceValidators.formatDateKey(date);
    return _index[dateKey]?.length ?? 0;
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class ServiceCalendar extends StatefulWidget {
  final String productId;
  final String shopId;
  final Function(DateTime, TimeOfDay)? onSlotSelected;

  const ServiceCalendar({
    super.key,
    required this.productId,
    required this.shopId,
    this.onSlotSelected,
  });

  @override
  State<ServiceCalendar> createState() => _ServiceCalendarState();
}

class _ServiceCalendarState extends State<ServiceCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay? _selectedTime;

  _BookedSlotsIndex _bookedIndex = _BookedSlotsIndex([]);
  List<DateTime> _availableDates = [];
  List<TimeOfDay> _availableTimes = [];

  bool _isLoading = true;
  bool _isBooking = false;
  String? _error;

  final List<TimeOfDay> _defaultTimeSlots = const [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 11, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 15, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[ServiceCalendar] 📅 Opened for product ${widget.productId.substring(0, 8)}...');

    if (!_ServiceValidators.isValidId(widget.productId) ||
        !_ServiceValidators.isValidId(widget.shopId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = context.svcT('Identifiants invalides', 'Invalid IDs');
          });
        }
      });
      return;
    }

    _loadAvailability();
  }

  @override
  void dispose() {
    debugPrint('[ServiceCalendar] 👋 Disposed');
    super.dispose();
  }

  // ============================================================
  // LOAD AVAILABILITY
  // ============================================================
  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load booked slots
      final bookedResponse = await _svcRetry(
        () => Supabase.instance.client
            .from('service_bookings')
            .select('booking_date, booking_time')
            .eq('product_id', widget.productId)
            .eq('status', 'confirmed'),
        label: 'loadBookedSlots',
      );

      final bookedList = (bookedResponse as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Build O(1) index
      _bookedIndex = _BookedSlotsIndex(bookedList);

      // Generate available dates (next 30 days)
      final now = DateTime.now();
      final dates = <DateTime>[];
      for (int i = _kMinDaysAhead; i <= _kDefaultDaysAhead; i++) {
        dates.add(now.add(Duration(days: i)));
      }

      if (!mounted) return;

      setState(() {
        _availableDates = dates;
        _isLoading = false;
      });

      debugPrint('[ServiceCalendar] ✓ Loaded ${bookedList.length} booked slots, ${dates.length} available dates');
    } catch (e) {
      debugPrint('[ServiceCalendar] ❌ Load availability error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _ServiceValidators.friendlyError(e);
      });
    }
  }

  // ============================================================
  // DAY SELECTION
  // ============================================================
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDay = selectedDay;
      _selectedTime = null;
      _focusedDay = focusedDay;

      // Filter available times (O(1) lookup per slot)
      _availableTimes = _defaultTimeSlots.where((time) {
        return !_bookedIndex.isBooked(selectedDay, time);
      }).toList();
    });
    debugPrint('[ServiceCalendar] 📅 Day selected: ${_ServiceValidators.formatDateKey(selectedDay)}');
  }

  // ============================================================
  // TIME SELECTION
  // ============================================================
  void _onTimeSelected(TimeOfDay time) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTime = _selectedTime == time ? null : time;
    });
  }

  // ============================================================
  // BOOK SERVICE
  // ============================================================
  Future<void> _bookService() async {
    if (_isBooking) {
      debugPrint('[ServiceCalendar] ⚠️ Booking already in progress');
      return;
    }

    if (_selectedDay == null) {
      _showInfo(context.svcT('Sélectionnez une date', 'Select a date'));
      return;
    }
    if (_selectedTime == null) {
      _showInfo(context.svcT('Sélectionnez un horaire', 'Select a time'));
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (!_ServiceValidators.isValidId(userId)) {
      _showError(context.svcT('Veuillez vous connecter', 'Please sign in'));
      return;
    }

    // Double-check slot availability (race condition protection)
    if (_bookedIndex.isBooked(_selectedDay!, _selectedTime!)) {
      _showError(context.svcT('Ce créneau vient d\'être réservé', 'This slot was just booked'));
      await _loadAvailability();
      return;
    }

    setState(() => _isBooking = true);
    HapticFeedback.mediumImpact();

    final dateStr = _ServiceValidators.formatDateKey(_selectedDay!);
    final timeStr = _ServiceValidators.formatTimeKey(_selectedTime!);

    debugPrint('[ServiceCalendar] 📝 Booking $dateStr $timeStr for product ${widget.productId.substring(0, 8)}...');

    try {
      await _svcRetry(
        () => Supabase.instance.client.from('service_bookings').insert({
          'product_id': widget.productId,
          'shop_id': widget.shopId,
          'user_id': userId,
          'booking_date': dateStr,
          'booking_time': timeStr,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        }),
        label: 'createBooking',
        timeout: _kBookingTimeout,
        maxRetries: 0, // Pas de retry sur booking (double booking)
      );

      // Notify parent
      widget.onSlotSelected?.call(_selectedDay!, _selectedTime!);

      if (mounted) {
        _showSuccess(context.svcT('Réservation envoyée au vendeur', 'Booking sent to seller'));
        // Pop si dans un modal
        try {
          Navigator.pop(context);
        } catch (_) {
          // Pas dans un modal
        }
      }
      debugPrint('[ServiceCalendar] ✓ Booking created');
    } catch (e) {
      debugPrint('[ServiceCalendar] ❌ Booking error: $e');
      if (mounted) _showError(_ServiceValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SkeletonCalendar();
    }

    if (_error != null) {
      return _ErrorState(
        message: _error!,
        retryLabel: context.svcT('Réessayer', 'Retry'),
        onRetry: _loadAvailability,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarHeader(title: context.svcT('Réservation de service', 'Service booking')),
          const SizedBox(height: 16),

          _CalendarSection(
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            firstDay: DateTime.now().add(const Duration(days: _kMinDaysAhead)),
            lastDay: DateTime.now().add(const Duration(days: _kMaxDaysAhead)),
            bookedIndex: _bookedIndex,
            onDaySelected: _onDaySelected,
          ),

          const SizedBox(height: 24),

          if (_selectedDay != null)
            _TimeSlotsSection(
              availableTimes: _availableTimes,
              selectedTime: _selectedTime,
              onTimeSelected: _onTimeSelected,
              emptyLabel: context.svcT('Aucun créneau disponible pour ce jour', 'No slots available for this day'),
              titleLabel: context.svcT('Créneaux disponibles', 'Available slots'),
            ),

          const SizedBox(height: 24),

          _BookButton(
            isBooking: _isBooking,
            onBook: _bookService,
            label: context.svcT('Réserver', 'Book'),
            processingLabel: context.svcT('Réservation...', 'Booking...'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _CalendarHeader extends StatelessWidget {
  final String title;
  const _CalendarHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ThixPolicy.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.calendar_month_rounded, color: ThixPolicy.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: ThixPolicy.h3Style.copyWith(
              fontSize: 20,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarSection extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final DateTime firstDay;
  final DateTime lastDay;
  final _BookedSlotsIndex bookedIndex;
  final OnDaySelected onDaySelected;

  const _CalendarSection({
    required this.focusedDay,
    required this.selectedDay,
    required this.firstDay,
    required this.lastDay,
    required this.bookedIndex,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.svcT('Calendrier de réservation', 'Booking calendar'),
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
        ),
        padding: const EdgeInsets.all(12),
        child: TableCalendar(
          calendarFormat: CalendarFormat.month,
          firstDay: firstDay,
          lastDay: lastDay,
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: onDaySelected,
          availableCalendarFormats: {
            CalendarFormat.month: context.svcT('Mois', 'Month'),
          },
          calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: ThixPolicy.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ThixPolicy.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            todayDecoration: BoxDecoration(
              color: ThixPolicy.textMuted.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            outsideDaysVisible: false,
            weekendTextStyle: TextStyle(color: ThixPolicy.textMuted),
            defaultTextStyle: TextStyle(color: ThixPolicy.textMain),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: ThixPolicy.labelStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
            leftChevronIcon: Icon(Icons.chevron_left_rounded, color: ThixPolicy.textMain),
            rightChevronIcon: Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMain),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) => _DayCell(
              day: day,
              isToday: false,
              isSelected: false,
              bookingCount: bookedIndex.countBookings(day),
            ),
            todayBuilder: (context, day, focusedDay) => _DayCell(
              day: day,
              isToday: true,
              isSelected: false,
              bookingCount: bookedIndex.countBookings(day),
            ),
            selectedBuilder: (context, day, focusedDay) => _DayCell(
              day: day,
              isToday: false,
              isSelected: true,
              bookingCount: bookedIndex.countBookings(day),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final int bookingCount;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.bookingCount,
  });

  @override
  Widget build(BuildContext context) {
    // 7 slots par jour, si tous réservés → désactivé
    final isFullyBooked = bookingCount >= 7;
    final hasBookings = bookingCount > 0 && !isFullyBooked;

    Color bgColor;
    Color textColor;

    if (isSelected) {
      bgColor = ThixPolicy.primary;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = ThixPolicy.primary.withOpacity(0.1);
      textColor = ThixPolicy.primary;
    } else if (isFullyBooked) {
      bgColor = ThixPolicy.danger.withOpacity(0.08);
      textColor = ThixPolicy.danger;
    } else {
      bgColor = Colors.transparent;
      textColor = ThixPolicy.textMain;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: ThixPolicy.primary.withOpacity(0.4), width: 2)
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ThixPolicy.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          if (hasBookings && !isSelected)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: ThixPolicy.gold,
                shape: BoxShape.circle,
              ),
            ),
          if (isFullyBooked)
            Icon(
              Icons.close_rounded,
              size: 10,
              color: ThixPolicy.danger,
            ),
        ],
      ),
    );
  }
}

class _TimeSlotsSection extends StatelessWidget {
  final List<TimeOfDay> availableTimes;
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay> onTimeSelected;
  final String emptyLabel;
  final String titleLabel;

  const _TimeSlotsSection({
    required this.availableTimes,
    required this.selectedTime,
    required this.onTimeSelected,
    required this.emptyLabel,
    required this.titleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 18, color: ThixPolicy.primary),
            const SizedBox(width: 8),
            Text(
              titleLabel,
              style: ThixPolicy.labelStyle.copyWith(
                fontSize: 16,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (availableTimes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 40, color: ThixPolicy.textMuted),
                const SizedBox(height: 8),
                Text(
                  emptyLabel,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTimes.map((time) {
              final isSelected = selectedTime == time;
              return Semantics(
                button: true,
                selected: isSelected,
                label: time.format(context),
                child: FilterChip(
                  label: Text(
                    time.format(context),
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 13,
                      fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.regular,
                      color: isSelected ? Colors.white : ThixPolicy.textMain,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => onTimeSelected(time),
                  backgroundColor: ThixPolicy.surfaceSoft,
                  selectedColor: ThixPolicy.primary,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _BookButton extends StatelessWidget {
  final bool isBooking;
  final VoidCallback onBook;
  final String label;
  final String processingLabel;

  const _BookButton({
    required this.isBooking,
    required this.onBook,
    required this.label,
    required this.processingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: !isBooking,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: isBooking ? null : onBook,
          icon: isBooking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.event_available_rounded, color: Colors.white, size: 20),
          label: Text(
            isBooking ? processingLabel : label,
            style: ThixPolicy.labelStyle.copyWith(
              fontSize: 15,
              color: Colors.white,
              fontWeight: ThixPolicy.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: ThixPolicy.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON / ERROR STATES
// ============================================================================

class _SkeletonCalendar extends StatelessWidget {
  const _SkeletonCalendar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 20, color: Colors.grey.shade200)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 14, width: 200, color: Colors.grey.shade200),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(
              context.svcT('Erreur de chargement', 'Loading error'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: retryLabel,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(retryLabel, style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
