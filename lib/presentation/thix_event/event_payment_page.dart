// lib/presentation/thix_event/event_payment_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/event_payment_provider.dart';
// L'IMPORT MANQUANT QUI CAUSAIT LE PROBLÈME :
import '../../services/event_payment_service.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textMuted = Color(0x66FFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
}

// CORRECTION : On instancie correctement le Service, qui est maintenant bien importé
final _paymentProvider = Provider<EventPaymentProvider>((ref) => EventPaymentProvider(EventPaymentService(Supabase.instance.client)));

class EventPaymentPage extends ConsumerStatefulWidget {
  final String bookingId;
  final double amount;
  final String currency;
  const EventPaymentPage({super.key, required this.bookingId, required this.amount, required this.currency});
  @override
  ConsumerState<EventPaymentPage> createState() => _EventPaymentPageState();
}

class _EventPaymentPageState extends ConsumerState<EventPaymentPage> {
  String _selected = "airtel";
  final _phone = TextEditingController();
  StreamSubscription? _sub;
  bool _processing = false;

  final _methods = const [
    {"id": "mpesa", "name": "M-Pesa", "brand": "Vodacom", "color": Color(0xFF00A651)},
    {"id": "airtel", "name": "Airtel Money", "brand": "Airtel", "color": Color(0xFFFF0000)},
    {"id": "orange", "name": "Orange Money", "brand": "Orange", "color": Color(0xFFFF6600)},
    {"id": "visa_master", "name": "Visa", "brand": "Carte", "color": Color(0xFF1A1F71)},
  ];

  @override
  void dispose() { 
    _phone.dispose(); 
    _sub?.cancel(); 
    super.dispose(); 
  }

  Future<void> _pay() async {
    final needPhone = _selected != "visa_master";
    if (needPhone && _phone.text.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Numéro invalide")));
      return;
    }
    setState(() => _processing = true);
    final svc = ref.read(_paymentProvider);
    final ok = await svc.makePayment(
      bookingId: widget.bookingId, 
      amount: widget.amount, 
      currency: widget.currency, 
      paymentMethod: _selected, 
      phoneNumber: needPhone ? _phone.text.trim() : null,
    );
    setState(() => _processing = false);
    if (ok && mounted) _waiting();
  }

  void _waiting() {
    showDialog(
      barrierDismissible: false, 
      context: context, 
      builder: (_) => Dialog(
        backgroundColor: _ThixColors.surface, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), 
        child: const Padding(
          padding: EdgeInsets.all(24), 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              CircularProgressIndicator(color: _ThixColors.primary), 
              SizedBox(height: 20), 
              Text("Validation...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
    _sub = Supabase.instance.client.from("event_bookings").stream(primaryKey: ["id"]).eq("id", widget.bookingId).listen((data) {
      if (data.isEmpty) return;
      final status = data.first["payment_status"];
      if (status == "paid" && mounted) {
        _sub?.cancel();
        Navigator.of(context, rootNavigator: true).pop();
        context.pushReplacement("/thix-event/ticket/${widget.bookingId}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52), 
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85), 
              elevation: 0, 
              leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()), 
              title: const Text("Paiement", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)), 
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Text("${widget.amount.toInt()} ${widget.currency}", style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900))),
          const SizedBox(height: 24),
          ..._methods.map((m) {
            final sel = _selected == m["id"];
            final col = m["color"] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _selected = m["id"] as String),
                child: Container(
                  padding: const EdgeInsets.all(14), 
                  decoration: BoxDecoration(
                    color: sel ? _ThixColors.primary.withOpacity(0.10) : _ThixColors.surface, 
                    borderRadius: BorderRadius.circular(18), 
                    border: Border.all(color: sel ? _ThixColors.primary : _ThixColors.cardBorder),
                  ), 
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(color: col.withOpacity(0.18), shape: BoxShape.circle), 
                        child: Icon(Icons.phone_android_rounded, color: col, size: 16),
                      ), 
                      const SizedBox(width: 12), 
                      Text(m["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), 
                      const Spacer(), 
                      Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? _ThixColors.primary : _ThixColors.textMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_selected != "visa_master") ...[
            const SizedBox(height: 12),
            TextField(
              controller: _phone, 
              keyboardType: TextInputType.phone, 
              style: const TextStyle(color: Colors.white), 
              decoration: InputDecoration(
                hintText: "+243...", 
                hintStyle: const TextStyle(color: _ThixColors.textMuted), 
                filled: true, 
                fillColor: _ThixColors.surface, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), 
        child: SizedBox(
          height: 46, 
          width: double.infinity, 
          child: ElevatedButton(
            onPressed: _processing ? null : _pay, 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, 
              foregroundColor: Colors.black, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
            ), 
            child: _processing 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Text("PAYER ${widget.amount.toInt()} ${widget.currency}", style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}
