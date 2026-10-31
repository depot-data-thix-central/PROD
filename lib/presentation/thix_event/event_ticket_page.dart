// lib/presentation/thix_event/event_ticket_page.dart
//
// EventTicketPage — DESIGN v2 (blanc épuré + glassmorphism)
//
import 'dart:math' as math;
import 'dart:ui' as ui; // ✅ Import préfixé pour éviter le conflit TextDirection

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// PALETTE
// ============================================================================

class _C {
  static const bg = Color(0xFFFBFBFD);
  static const surface = Colors.white;
  static const tile = Color(0xFFF7F7FB);
  static const ink = Color(0xFF101018);
  static const inkSoft = Color(0xFF71717E);
  static const line = Color(0xFFECECF2);
  static const accent = Color(0xFF5B3DF5);
  static const amber = Color(0xFFFFB020);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFEF4444);
}

// ============================================================================
// CATÉGORIES DYNAMIQUES
// ============================================================================

class TicketStyle {
  final Color color;
  final Color soft;
  final String label;

  const TicketStyle(this.color, this.soft, this.label);

  static TicketStyle fromCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('vvip') ||
        cat.contains('platine') ||
        cat.contains('premium')) {
      return TicketStyle(
          const Color(0xFF64748B), const Color(0x1464748B), category.toUpperCase());
    }
    if (cat.contains('vip') || cat.contains('gold') || cat.contains('or')) {
      return TicketStyle(
          const Color(0xFFD97706), const Color(0x14D97706), category.toUpperCase());
    }
    if (cat.contains('early') || cat.contains('promo')) {
      return TicketStyle(
          const Color(0xFF059669), const Color(0x14059669), category.toUpperCase());
    }
    return TicketStyle(
        _C.accent, const Color(0x145B3DF5), category.toUpperCase());
  }
}

// ============================================================================
// FILIGRANE « THIX »
// ============================================================================

class _WatermarkPainter extends CustomPainter {
  final Color color;
  _WatermarkPainter(this.color);

  @override
  void paint(ui.Canvas canvas, ui.Size size) { // ✅ ui. préfixe
    final tp = TextPainter(
      text: TextSpan(
        text: 'THIX',
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 5,
        ),
      ),
      textDirection: ui.TextDirection.ltr, // ✅ CORRECTION : ui.TextDirection
    )..layout();

    canvas.save();
    canvas.rotate(-0.32);
    for (double y = -size.height * 0.35; y < size.height * 1.35; y += 92) {
      for (double x = -size.width * 0.25; x < size.width * 1.25; x += 150) {
        tp.paint(canvas, ui.Offset(x, y)); // ✅ ui.Offset
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// PAGE
// ============================================================================

class EventTicketPage extends StatefulWidget {
  final String bookingId;
  const EventTicketPage({super.key, required this.bookingId});

  @override
  State<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends State<EventTicketPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _qrVisible = false;
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _event;
  late AnimationController _holo;

  @override
  void initState() {
    super.initState();
    _holo = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();
    _fetch();
  }

  @override
  void dispose() {
    _holo.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from("event_bookings")
          .select("*, events(*)")
          .eq("id", widget.bookingId)
          .single();
      if (mounted) {
        setState(() {
          _booking = res;
          _event = res["events"];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _askPin() {
    final ctrl = TextEditingController();
    final correct = _booking!["pin_code"]?.toString() ?? "";
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _C.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: _C.accent, size: 26),
            ),
            const SizedBox(height: 14),
            const Text("Sécurité",
                style: TextStyle(
                    color: _C.ink, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text("Entrez votre code PIN pour afficher le QR",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _C.inkSoft, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _C.ink,
                  letterSpacing: 8,
                  fontSize: 22,
                  fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                  counterText: "",
                  hintText: "••••",
                  hintStyle: const TextStyle(
                      color: _C.inkSoft, letterSpacing: 8, fontSize: 18),
                  filled: true,
                  fillColor: _C.tile,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _C.line))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (ctrl.text.trim() == correct) {
                    setState(() => _qrVisible = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("PIN incorrect"),
                        backgroundColor: _C.danger));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _C.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text("Confirmer",
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, Color tint) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 14, color: _C.ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _C.ink, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: _C.accent),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _C.inkSoft,
                    letterSpacing: 0.6)),
          ]),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: _C.ink)),
        ],
      ),
    );
  }

  Widget _barcode(String seed) {
    final codes = seed.codeUnits;
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < codes.length && i < 44; i++)
            Container(
              width: codes[i] % 3 == 0
                  ? 2.4
                  : (codes[i] % 3 == 1 ? 1.1 : 1.7),
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 1.1),
              color: _C.ink.withOpacity(0.85),
            ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'cancelled':
        return 'ANNULÉ';
      case 'used':
      case 'checked_in':
        return 'UTILISÉ';
      default:
        return 'CONFIRMÉ';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'cancelled':
        return _C.danger;
      case 'used':
      case 'checked_in':
        return _C.inkSoft;
      default:
        return _C.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator(color: _C.accent)),
      );
    }

    if (_booking == null || _event == null) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: _C.ink),
              onPressed: () => context.go("/thix-event")),
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.confirmation_num_outlined,
                size: 48, color: _C.inkSoft),
            const SizedBox(height: 12),
            const Text("Billet introuvable",
                style: TextStyle(
                    color: _C.inkSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    final title = _event!["title"] ?? "Événement";
    final dateStr = _event!["date"] ?? _event!["start_date"];
    final dt = dateStr != null
        ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now()
        : DateTime.now();
    final dateFmt = DateFormat("dd MMM yyyy • HH:mm", "fr").format(dt);
    final loc = (_event!["location"] ?? "").toString();
    final city = (_event!["city"] ?? "").toString().trim();
    final organizer = (_event!["organizer_name"] ?? "").toString().trim();
    final place = city.isEmpty
        ? loc
        : (loc.isEmpty ? city : '$loc • $city');
    final img = _event!["image_url"];
    final qty = _booking!["ticket_quantity"] ?? 1;
    final catRaw = (_booking!["ticket_category"] ?? "Standard").toString();
    final pin = _booking!["pin_code"]?.toString() ?? "****";
    final qr = _booking!["id"].toString();
    final status = _booking!["status"]?.toString();

    final priceNum = (_booking!["total_price"] as num?)?.toDouble() ?? 0;
    final cur = (_event!["price_currency"] ?? "FC").toString();
    final priceStr = priceNum == 0
        ? "Gratuit"
        : "${priceNum.toStringAsFixed(priceNum % 1 == 0 ? 0 : 2)} $cur";

    final bookedRaw = _booking!["booking_date"] ?? _booking!["created_at"];
    final bookedDt =
        bookedRaw != null ? DateTime.tryParse(bookedRaw.toString()) : null;
    final bookedStr =
        bookedDt != null ? DateFormat("dd MMM yyyy", "fr").format(bookedDt) : "—";

    final style = TicketStyle.fromCategory(catRaw);
    final statusColor = _statusColor(status);

    final dash = "-";
    final masked =
        "****-****-${qr.length >= 4 ? qr.substring(qr.length - 4).toUpperCase() : qr}";
    final shortId = qr.contains(dash)
        ? qr.split(dash).first.toUpperCase()
        : qr.toUpperCase();
    final displayId = _qrVisible ? shortId : masked;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18), // ✅ ui.
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white70,
                border: Border(bottom: BorderSide(color: _C.line)),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                    icon: const Icon(Icons.close_rounded, color: _C.ink),
                    onPressed: () => context.go("/thix-event")),
                title: const Text("Billet sécurisé",
                    style: TextStyle(
                        color: _C.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
                centerTitle: true,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
              top: -80,
              right: -60,
              child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.accent.withOpacity(0.05)))),
          Positioned(
              bottom: 60,
              left: -80,
              child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.amber.withOpacity(0.06)))),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: _ticketCard(
              title: title,
              dateFmt: dateFmt,
              place: place,
              organizer: organizer,
              img: img,
              qty: qty,
              priceStr: priceStr,
              bookedStr: bookedStr,
              style: style,
              statusLabel: _statusLabel(status),
              statusColor: statusColor,
              pin: pin,
              qr: qr,
              displayId: displayId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard({
    required String title,
    required String dateFmt,
    required String place,
    required String organizer,
    required dynamic img,
    required int qty,
    required String priceStr,
    required String bookedStr,
    required TicketStyle style,
    required String statusLabel,
    required Color statusColor,
    required String pin,
    required String qr,
    required String displayId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.line, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: _C.ink.withOpacity(0.07),
              blurRadius: 28,
              offset: const Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(children: [
            if (img != null)
              Stack(
                children: [
                  Image.network(img,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 190, color: _C.tile)),
                  Container(
                    height: 190,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _C.surface.withOpacity(0.85),
                          _C.surface,
                        ],
                        stops: const [0.35, 0.8, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _chip(statusLabel, statusColor),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _chip(style.label, style.color),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 14),
                    _chip(statusLabel, statusColor),
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _chip(style.label, style.color),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: _C.ink,
                            height: 1.2,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 14),
                    _metaRow(Icons.calendar_month_rounded, dateFmt,
                        _C.amber.withOpacity(0.18)),
                    const SizedBox(height: 8),
                    _metaRow(Icons.location_on_rounded, place,
                        _C.accent.withOpacity(0.12)),
                    if (organizer.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _metaRow(Icons.badge_rounded, organizer,
                          style.soft),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _infoTile(
                              "BILLETS", "$qty", Icons.confirmation_num_rounded)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _infoTile(
                              "TOTAL", priceStr, Icons.receipt_long_rounded)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _infoTile("RÉSERVÉ LE", bookedStr,
                              Icons.history_rounded)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _infoTile("PIN", _qrVisible ? pin : "••••",
                              Icons.key_rounded)),
                    ]),
                  ]),
            ),

            SizedBox(
              height: 1,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Flex(
                          direction: Axis.horizontal,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                              (constraints.constrainWidth() / 10).floor(),
                              (_) => const SizedBox(
                                  width: 5,
                                  height: 1.5,
                                  child: DecoratedBox(
                                      decoration:
                                          BoxDecoration(color: _C.line)))),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: -12,
                    child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                            color: _C.bg, shape: BoxShape.circle)),
                  ),
                  Positioned(
                    right: -12,
                    child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                            color: _C.bg, shape: BoxShape.circle)),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Column(children: [
                _qrVisible
                    ? Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _C.line),
                          boxShadow: [
                            BoxShadow(
                                color: style.color.withOpacity(0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: QrImageView(
                          data: qr,
                          version: QrVersions.auto,
                          size: 168,
                          eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square, color: Colors.black),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black),
                        ),
                      )
                    : Container(
                        height: 196,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _C.tile,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: style.color.withOpacity(0.35), width: 1.2),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: style.soft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.lock_rounded,
                                    color: style.color, size: 26),
                              ),
                              const SizedBox(height: 10),
                              const Text("QR code protégé par PIN",
                                  style: TextStyle(
                                      color: _C.inkSoft,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: _askPin,
                                icon: const Icon(Icons.qr_code_2_rounded,
                                    size: 17),
                                label: const Text("Afficher le QR",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: style.color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16))),
                              ),
                            ]),
                      ),
                const SizedBox(height: 18),
                _barcode(qr),
                const SizedBox(height: 10),
                Text("ID: $displayId",
                    style: const TextStyle(
                        color: _C.inkSoft,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                if (_qrVisible)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _qrVisible = false),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _C.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: const Text("Masquer le QR",
                          style: TextStyle(
                              color: _C.inkSoft, fontWeight: FontWeight.w800)),
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  "Billet personnel • Présentez le QR à l'entrée",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _C.inkSoft,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WatermarkPainter(
                  _C.ink.withOpacity(0.035))),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _holo,
                builder: (context, child) {
                  final t = _holo.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.2 + 2.4 * t, -1.0),
                        end: Alignment(-0.2 + 2.4 * t, 1.0),
                        colors: [
                          Colors.white.withOpacity(0.0),
                          const Color(0xFF22D3EE).withOpacity(0.10),
                          const Color(0xFFA78BFA).withOpacity(0.12),
                          const Color(0xFFFFD36E).withOpacity(0.10),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.42, 0.5, 0.58, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10), // ✅ ui.
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: 1)),
        ),
      ),
    );
  }
}
