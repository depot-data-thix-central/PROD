import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

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
  
  List<Map<String, dynamic>> _bookedSlots = [];
  List<DateTime> _availableDates = [];
  List<TimeOfDay> _availableTimes = [];
  bool _isLoading = true;
  bool _isBooking = false;
  
  final List<TimeOfDay> _defaultTimeSlots = [
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
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    
    try {
      // Load booked slots
      final bookedResponse = await Supabase.instance.client
          .from('service_bookings')
          .select('booking_date, booking_time')
          .eq('product_id', widget.productId)
          .eq('status', 'confirmed');
      
      final bookedList = List<Map<String, dynamic>>.from(bookedResponse);
      setState(() {
        _bookedSlots = bookedList;
      });
      
      // Load available dates (next 30 days)
      final now = DateTime.now();
      final List<DateTime> dates = [];
      for (int i = 1; i <= 30; i++) {
        final date = now.add(Duration(days: i));
        dates.add(date);
      }
      setState(() {
        _availableDates = dates;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading availability: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _isSlotBooked(DateTime date, TimeOfDay time) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return _bookedSlots.any((slot) => slot['booking_date'] == dateStr && slot['booking_time'] == timeStr);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _selectedTime = null;
      _focusedDay = focusedDay;
      
      // Filter available times for selected day
      _availableTimes = _defaultTimeSlots.where((time) {
        return !_isSlotBooked(selectedDay, time);
      }).toList();
    });
  }

  Future<void> _bookService() async {
    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une date')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un horaire')),
      );
      return;
    }
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter')),
      );
      return;
    }
    
    setState(() => _isBooking = true);
    
    try {
      await Supabase.instance.client
          .from('service_bookings')
          .insert({
            'product_id': widget.productId,
            'shop_id': widget.shopId,
            'user_id': userId,
            'booking_date': DateFormat('yyyy-MM-dd').format(_selectedDay!),
            'booking_time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          });
      
      widget.onSlotSelected?.call(_selectedDay!, _selectedTime!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation envoyée au vendeur')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Réservation de service',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Calendar
          TableCalendar(
            calendarFormat: CalendarFormat.month,
            firstDay: DateTime.now().add(const Duration(days: 1)),
            lastDay: DateTime.now().add(const Duration(days: 60)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day), // ✅ correction
            onDaySelected: _onDaySelected,
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Color(0xFFE5592F),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            availableCalendarFormats: const {CalendarFormat.month: 'Mois'},
          ),
          const SizedBox(height: 24),
          
          // Time slots
          if (_selectedDay != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créneaux disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTimes.map((time) {
                    final isSelected = _selectedTime == time;
                    return FilterChip(
                      label: Text(time.format(context)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTime = selected ? time : null;
                        });
                      },
                      selectedColor: const Color(0xFFE5592F).withOpacity(0.1),
                      checkmarkColor: const Color(0xFFE5592F),
                    );
                  }).toList(),
                ),
                if (_availableTimes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('Aucun créneau disponible pour ce jour'),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          
          // Book button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _bookService,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5592F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isBooking
                  ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  : const Text('Réserver', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
