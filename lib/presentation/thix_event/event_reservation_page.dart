import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../models/event_seat.dart';
import '../../services/event_booking_limit_service.dart';
import '../../services/event_seat_service.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textMuted = Color(0x66FFFFFF);
}

class EventReservationPage extends ConsumerStatefulWidget {
  final String eventId;
  final List<EventSeat>? selectedSeats;
  final double? totalPrice;
  final int quantity;
  final String? ticketCategory;
  final double? ticketPrice;
  const EventReservationPage({super.key, required this.eventId, this.selectedSeats, this.totalPrice, this.quantity = 1, this.ticketCategory, this.ticketPrice});
  @override
  ConsumerState<EventReservationPage> createState() => _EventReservationPageState();
}

class _EventReservationPageState extends ConsumerState<EventReservationPage> {
  late Event _event;
  bool _loading = true;
  int _qty = 1;
  bool _processing = false;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qty = widget.quantity;
    _pin.text = (1000 + Random().nextInt(9000)).toString();
    _load();
  }

  @override
  void dispose() { _name.dispose(); _email.dispose(); _phone.dispose(); _pin.dispose(); super.dispose(); }

  Future<void> _load() async {
    final ev = await ref.read(eventServiceProvider).getEventById(widget.eventId);
    if (ev!= null && mounted) setState(() { _event = ev; _loading = false; });
  }

  double get _unit => widget.ticketPrice?? widget.totalPrice?? _event.price;
  double get _total => _unit * _qty;

  Future<void> _reserve() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);
    try {
      String? bookingId;
      if (widget.selectedSeats!= null && widget.selectedSeats!.isNotEmpty) {
        final b = await ref.read(eventServiceProvider).bookTicket(eventId: widget.eventId, quantity: widget.selectedSeats!.length, totalPrice: _total);
        if (b!= null) {
          await EventSeatService(Supabase.instance.client).confirmSeats(widget.eventId, widget.selectedSeats!.map((s) => s.id).toList(), 0);
          bookingId = b.id;
        }
      } else {
        final b = await ref.read(eventServiceProvider).bookTicket(eventId: widget.eventId, quantity: _qty, totalPrice: _total);
        bookingId = b?.id;
      }
      if (bookingId!= null) {
        await Supabase.instance.client.from("event_bookings").update({"pin_code": _pin.text.trim(), "ticket_category": widget.ticketCategory?? "Standard"}).eq("id", bookingId);
        if (mounted) context.push("/thix-event/payment", extra: {"bookingId": bookingId, "amount": _total, "currency": _event.priceCurrency});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _processing = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: _ThixColors.bg, body: Center(child: CircularProgressIndicator(color: _ThixColors.primary)));
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(52), child: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: AppBar(backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()), title: const Text("Confirmation", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)), centerTitle: true)))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(children: [
          Container(
            decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.cardBorder)),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _field(_name, "Nom complet", Icons.person_outline_rounded),
                const SizedBox(height: 12),
                _field(_email, "Email", Icons.email_outlined),
                const SizedBox(height: 12),
                _field(_phone, "Telephone", Icons.phone_outlined),
                const SizedBox(height: 12),
                _field(_pin, "PIN 4 chiffres", Icons.lock_outline_rounded),
              ]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(color: _ThixColors.surface.withOpacity(0.96), border: const Border(top: BorderSide(color: _ThixColors.cardBorder))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("${_total.toInt()} ${_event.priceCurrency}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 46, child: ElevatedButton(onPressed: _processing? null : _reserve, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))), child: _processing? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("PAYER", style: TextStyle(fontWeight: FontWeight.w900)))),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: (v) => (v?? "").trim().isEmpty? "Requis" : null,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: _ThixColors.textMuted, fontSize: 12), prefixIcon: Icon(icon, size: 16, color: _ThixColors.textMuted), filled: true, fillColor: _ThixColors.surfaceAlt, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _ThixColors.cardBorder))),
    );
  }
}
