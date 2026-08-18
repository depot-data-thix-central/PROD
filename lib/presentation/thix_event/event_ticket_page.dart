import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textMuted = Color(0x66FFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
}

class EventTicketPage extends StatefulWidget {
  final String bookingId;
  const EventTicketPage({super.key, required this.bookingId});
  @override
  State<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends State<EventTicketPage> with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _qrVisible = false;
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _event;
  late AnimationController _holo;

  @override
  void initState() {
    super.initState();
    _holo = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _fetch();
  }

  @override
  void dispose() { _holo.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client.from("event_bookings").select("*, events(*)").eq("id", widget.bookingId).single();
      if (mounted) setState(() { _booking = res; _event = res["events"]; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _askPin() {
    final ctrl = TextEditingController();
    final correct = _booking!["pin_code"]?.toString()?? "";
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _ThixColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _ThixColors.cardBorder)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Securite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, style: const TextStyle(color: Colors.white, letterSpacing: 4), decoration: InputDecoration(counterText: "", filled: true, fillColor: _ThixColors.surfaceAlt, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (ctrl.text.trim() == correct) { setState(() => _qrVisible = true); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN incorrect"), backgroundColor: Colors.red)); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("Confirmer"),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: _ThixColors.bg, body: Center(child: CircularProgressIndicator(color: _ThixColors.primary)));
    if (_booking == null || _event == null) return Scaffold(backgroundColor: _ThixColors.bg, appBar: AppBar(backgroundColor: Colors.transparent, leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.go("/thix-event"))), body: const Center(child: Text("Billet introuvable", style: TextStyle(color: Colors.white))));

    final title = _event!["title"]?? "Evenement";
    final dateStr = _event!["date"]?? _event!["start_date"];
    final dt = dateStr!= null? DateTime.tryParse(dateStr.toString())?? DateTime.now() : DateTime.now();
    final dateFmt = DateFormat("dd MMM yyyy - HH:mm", "fr").format(dt);
    final loc = _event!["location"]?? "";
    final img = _event!["image_url"];
    final qty = _booking!["ticket_quantity"]?? 1;
    final cat = _booking!["ticket_category"]?? "Standard";
    final pin = _booking!["pin_code"]?.toString()?? "****";
    final qr = _booking!["id"].toString();
    final dash = "-";
    final masked = "****-****-${qr.length >= 4? qr.substring(qr.length - 4).toUpperCase() : qr}";
    final shortId = qr.contains(dash)? qr.split(dash).first.toUpperCase() : qr.toUpperCase();
    final displayId = _qrVisible? shortId : masked;

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0, leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.go("/thix-event")), title: const Text("Billet Securise", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), centerTitle: true),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(children: [
          Container(
            decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _ThixColors.cardBorder)),
            child: Column(children: [
              if (img!= null) ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)), child: Image.network(img, height: 160, width: double.infinity, fit: BoxFit.cover)),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text(dateFmt, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 12)),
                  Text(loc, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text("$qty billet(s) - $cat", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    Text(_qrVisible? pin : "****", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3)),
                  ]),
                ]),
              ),
              const Divider(color: _ThixColors.cardBorder, height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  _qrVisible
                     ? Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: QrImageView(data: qr, version: QrVersions.auto, size: 150))
                      : Container(height: 170, decoration: BoxDecoration(color: _ThixColors.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)), child: Center(child: ElevatedButton.icon(onPressed: _askPin, icon: const Icon(Icons.visibility_rounded, size: 14), label: const Text("Afficher QR")))),
                  const SizedBox(height: 10),
                  Text("ID: $displayId", style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10, letterSpacing: 1.5)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
