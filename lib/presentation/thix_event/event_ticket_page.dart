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

// ============================================================================
// GESTION DES 4 CATÉGORIES DYNAMIQUES
// ============================================================================
class TicketStyle {
  final Color color;
  final String label;

  TicketStyle(this.color, this.label);

  static TicketStyle fromCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('vvip') || cat.contains('premium') || cat.contains('platine')) {
      return TicketStyle(const Color(0xFFE5E4E2), category.toUpperCase()); // Platine/Argent
    } else if (cat.contains('vip') || cat.contains('gold') || cat.contains('or')) {
      return TicketStyle(const Color(0xFFFFD700), category.toUpperCase()); // Or
    } else if (cat.contains('early') || cat.contains('promo')) {
      return TicketStyle(const Color(0xFF00FA9A), category.toUpperCase()); // Émeraude/Vert
    }
    // Standard / Par défaut
    return TicketStyle(_ThixColors.primary, category.toUpperCase()); // Thix Primary
  }
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
    // Contrôleur pour l'hologramme (durée du balayage : 2.5 secondes)
    _holo = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
    _fetch();
  }

  @override
  void dispose() { 
    _holo.dispose(); 
    super.dispose(); 
  }

  // LOGIQUE STABLE CONSERVÉE INTACTE
  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client.from("event_bookings").select("*, events(*)").eq("id", widget.bookingId).single();
      if (mounted) setState(() { _booking = res; _event = res["events"]; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _askPin() {
    final ctrl = TextEditingController();
    // Le PIN vient bien de la DB via Supabase
    final correct = _booking!["pin_code"]?.toString() ?? "";
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _ThixColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _ThixColors.cardBorder)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline_rounded, color: _ThixColors.primary, size: 32),
            const SizedBox(height: 12),
            const Text("Sécurité", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text("Entrez votre code PIN pour afficher le QR", textAlign: TextAlign.center, style: TextStyle(color: _ThixColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl, 
              keyboardType: TextInputType.number, 
              maxLength: 4, 
              obscureText: true, 
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold), 
              decoration: InputDecoration(
                counterText: "", 
                hintText: "••••",
                hintStyle: const TextStyle(color: _ThixColors.textMuted, letterSpacing: 8),
                filled: true, 
                fillColor: _ThixColors.surfaceAlt, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
              )
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (ctrl.text.trim() == correct) { 
                    setState(() => _qrVisible = true); 
                  } else { 
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN incorrect"), backgroundColor: Colors.red)); 
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Confirmer", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
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

    final title = _event!["title"] ?? "Événement";
    final dateStr = _event!["date"] ?? _event!["start_date"];
    final dt = dateStr != null ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now() : DateTime.now();
    final dateFmt = DateFormat("dd MMM yyyy - HH:mm", "fr").format(dt);
    final loc = _event!["location"] ?? "";
    final img = _event!["image_url"];
    final qty = _booking!["ticket_quantity"] ?? 1;
    final catRaw = _booking!["ticket_category"] ?? "Standard";
    final pin = _booking!["pin_code"]?.toString() ?? "****";
    final qr = _booking!["id"].toString();
    
    // Détermination dynamique du style selon la catégorie
    final style = TicketStyle.fromCategory(catRaw);

    final dash = "-";
    final masked = "****-****-${qr.length >= 4 ? qr.substring(qr.length - 4).toUpperCase() : qr}";
    final shortId = qr.contains(dash) ? qr.split(dash).first.toUpperCase() : qr.toUpperCase();
    final displayId = _qrVisible ? shortId : masked;

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
              leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.go("/thix-event")), 
              title: const Text("Billet Sécurisé", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), 
              centerTitle: true
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Stack(
          children: [
            // LE BILLET PRINCIPAL
            Container(
              decoration: BoxDecoration(
                color: _ThixColors.surface, 
                borderRadius: BorderRadius.circular(24), 
                border: Border.all(color: style.color.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: style.color.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                ]
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  // HOLOGRAMME MOBILE (Couche de fond animée)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _holo,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-2.0 + (_holo.value * 4), -1.5),
                              end: Alignment(0.0 + (_holo.value * 4), 1.5),
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.1),
                                Colors.cyanAccent.withOpacity(0.15),
                                Colors.purpleAccent.withOpacity(0.15),
                                Colors.yellowAccent.withOpacity(0.15),
                                Colors.white.withOpacity(0.1),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // CONTENU DU BILLET
                  Column(children: [
                    // Image de couverture avec overlay
                    if (img != null) Stack(
                      children: [
                        Image.network(img, height: 180, width: double.infinity, fit: BoxFit.cover),
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.transparent, _ThixColors.surface.withOpacity(0.9), _ThixColors.surface]
                            )
                          ),
                        ),
                        Positioned(
                          top: 16, right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: style.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: style.color)),
                            child: Text(style.label, style: TextStyle(color: style.color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                          ),
                        )
                      ],
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (img == null) const SizedBox(height: 24),
                        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                        const SizedBox(height: 16),
                        Row(children: [
                          const Icon(Icons.calendar_month_rounded, color: _ThixColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Text(dateFmt, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on_rounded, color: _ThixColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(loc, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 13))),
                        ]),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: _ThixColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: _ThixColors.cardBorder)),
                          child: Row(children: [
                            const Icon(Icons.confirmation_num_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text("$qty Billet(s)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            const Spacer(),
                            Text(_qrVisible ? pin : "••••", style: TextStyle(color: style.color, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 16)),
                          ]),
                        ),
                      ]),
                    ),
                    
                    // Ligne de séparation avec pointillées
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Flex(
                            direction: Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate((constraints.constrainWidth() / 10).floor(), (_) => const SizedBox(width: 5, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: _ThixColors.cardBorder)))),
                          );
                        },
                      ),
                    ),

                    // Section QR Code
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        _qrVisible
                          ? Container(
                              padding: const EdgeInsets.all(12), 
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: style.color.withOpacity(0.5), blurRadius: 15)]), 
                              child: QrImageView(data: qr, version: QrVersions.auto, size: 160, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black))
                            )
                          : Container(
                              height: 180, width: 180,
                              decoration: BoxDecoration(color: _ThixColors.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: style.color.withOpacity(0.3))), 
                              child: Center(
                                child: ElevatedButton.icon(
                                  onPressed: _askPin, 
                                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18), 
                                  label: const Text("Afficher QR", style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: style.color, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))
                                )
                              )
                            ),
                        const SizedBox(height: 16),
                        Text("ID: $displayId", style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11, letterSpacing: 2, fontFamily: 'monospace')),
                      ]),
                    ),
                  ]),
                ],
              ),
            ),
            
            // PERFORATIONS LATÉRALES (Design Billet Physique)
            // Positionnées au niveau de la ligne de séparation (environ 340px du haut)
            Positioned(
              left: -12, top: 335,
              child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: _ThixColors.bg, shape: BoxShape.circle)),
            ),
            Positioned(
              right: -12, top: 335,
              child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: _ThixColors.bg, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }
}
