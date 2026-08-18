import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event_model.dart';
import '../../models/event_seat.dart';
import '../../services/event_seat_service.dart';
import 'event_reservation_page.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const cardBorderStrong = Color(0x26FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
  static const available = Color(0xFF1A1A22);
  static const reserved = Color(0xFFF59E0B);
  static const sold = Color(0xFFEF4444);
}

class SeatSelectionPage extends ConsumerStatefulWidget {
  final String eventId;
  final Event? event;
  final int? requestedQuantity;
  const SeatSelectionPage({super.key, required this.eventId, this.event, this.requestedQuantity});
  @override
  ConsumerState<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends ConsumerState<SeatSelectionPage> {
  late EventSeatService _svc;
  List<EventSeat> _seats = [];
  List<EventSeat> _selected = [];
  final Set<String> _processing = {};
  Map<String, List<EventSeat>> _grouped = {};
  List<String> _rows = [];
  bool _loading = true;
  bool _confirming = false;
  int _available = 0;
  String? _error;

  int get _max => widget.requestedQuantity!= null && widget.requestedQuantity! < 5? widget.requestedQuantity! : 5;

  @override
  void initState() { super.initState(); _svc = EventSeatService(Supabase.instance.client); _load(); }

  @override
  void dispose() { _release(); super.dispose(); }

  Future<void> _release() async { if (_selected.isNotEmpty) await _svc.releaseSeats(widget.eventId, _selected.map((s) => s.id).toList()); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final seats = await _svc.getSeatMap(widget.eventId);
      final avail = await _svc.getAvailableSeatsCount(widget.eventId);
      _grouped.clear(); for (var s in seats) { _grouped.putIfAbsent(s.row, () => []).add(s); }
      _rows = _grouped.keys.toList()..sort();
      if (mounted) setState(() { _seats = seats; _available = avail; _loading = false; });
    } catch (_) { if (mounted) setState(() { _error = 'Impossible de charger le plan'; _loading = false; }); }
  }

  Future<void> _toggle(EventSeat seat) async {
    if (_processing.contains(seat.id)) return;
    setState(() => _processing.add(seat.id));
    try {
      final already = _selected.any((s) => s.id== seat.id);
      if (already) {
        if (await _svc.releaseSeats(widget.eventId, [seat.id]) && mounted) setState(() { _selected.removeWhere((s) => s.id== seat.id); _available++; });
      } else {
        if (_selected.length >= _max) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Max $_max places'), backgroundColor: Colors.red)); return; }
        if (await _svc.reserveSeats(widget.eventId, [seat.id]) && mounted) setState(() { _selected.add(seat); _available--; });
        else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place prise'), backgroundColor: Colors.orange)); _load(); }
      }
    } finally { if (mounted) setState(() => _processing.remove(seat.id)); }
  }

  double get _total => _selected.fold(0, (sum, s) => sum + (s.categoryPrice>0? s.categoryPrice : (widget.event?.price?? 0)));

  void _confirm() {
    if (_selected.isEmpty) return;
    setState(() => _confirming = true);
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventReservationPage(eventId: widget.eventId, selectedSeats: _selected, totalPrice: _total, quantity: _selected.length))).then((_) { if (mounted) { setState(() => _confirming = false); _load(); } });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: AppBar(backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0, leading: Padding(padding: const EdgeInsets.all(8), child: InkWell(onTap: () => context.pop(), child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18)))), title: const Text('Places', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), centerTitle: true, actions: [Container(margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: _ThixColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.primary.withOpacity(0.3))), child: Center(child: Text('${_selected.length} / $_max', style: const TextStyle(color: _ThixColors.primary, fontSize: 12, fontWeight: FontWeight.w900))))]))),
      ),
      body: _loading? const Center(child: CircularProgressIndicator(color: _ThixColors.primary)) : _error!= null? _errorView() : Column(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _ThixColors.surfaceAlt, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.event_seat_rounded, color: _ThixColors.textSecondary, size: 14)), const SizedBox(width: 10), const Text('Disponibles', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))]), Text('$_available', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))])),
        Expanded(child: _map()),
        _legend(),
        _bottom(),
      ]),
    );
  }

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 32), const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 12)), const SizedBox(height: 12), ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Réessayer'))]));

  Widget _legend() => Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), decoration: const BoxDecoration(color: _ThixColors.surface, border: Border(top: BorderSide(color: _ThixColors.cardBorder))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_leg(_ThixColors.available, 'Libre', false), _leg(_ThixColors.primary, 'Sélection', true), _leg(_ThixColors.reserved, 'En cours', true), _leg(_ThixColors.sold, 'Vendue', true)]));

  Widget _leg(Color c, String l, bool filled) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: filled? c : Colors.transparent, border: Border.all(color: filled? c : _ThixColors.textMuted, width: 1.2), borderRadius: BorderRadius.circular(3))), const SizedBox(width: 5), Text(l, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600))]);

  Widget _map() {
    if (_seats.isEmpty) return const Center(child: Text('Aucune place configurée', style: TextStyle(color: _ThixColors.textMuted)));
    return InteractiveViewer(minScale: 0.6, maxScale: 3, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 40), child: Column(children: [
      CustomPaint(size: const Size(220, 36), painter: _ScenePainter()),
      const SizedBox(height: 10), const Text('SCÈNE', style: TextStyle(color: _ThixColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 4)),
      const SizedBox(height: 30),
      for (var row in _rows) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 22, child: Text(row, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
        const SizedBox(width: 6),
        Wrap(spacing: 8, runSpacing: 8, children: _grouped[row]!.map((seat) {
          final sel = _selected.any((s) => s.id== seat.id);
          final proc = _processing.contains(seat.id);
          final avail = seat.isAvailable;
          Color col; Color txt = Colors.white;
          if (sel) col = _ThixColors.primary; else if (seat.isSold) col = _ThixColors.sold; else if (seat.isReserved &&!sel) col = _ThixColors.reserved; else { col = _ThixColors.available; txt = _ThixColors.textSecondary; }
          return GestureDetector(onTap: (avail||sel)&&!_confirming? () => _toggle(seat) : null, child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 36, height: 36, decoration: BoxDecoration(color: sel||!avail||seat.isReserved? col : Colors.transparent, border: Border.all(color: sel? _ThixColors.primary : avail? _ThixColors.cardBorderStrong : col, width: 1.2), borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)), boxShadow: sel? [BoxShadow(color: _ThixColors.primary.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))] : null), child: Center(child: proc? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)) : Text(seat.number.toString(), style: TextStyle(color: txt, fontSize: 11, fontWeight: FontWeight.w800)))));
        }).toList()),
      ])),
    ])));
  }

  Widget _bottom() => Container(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), decoration: BoxDecoration(color: _ThixColors.surfaceAlt.withOpacity(0.96), border: Border(top: BorderSide(color: _ThixColors.cardBorder))), child: SafeArea(top: false, child: Row(children: [
    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_selected.isEmpty? 'Aucune place' : '${_selected.length} place(s)', style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11)), const SizedBox(height: 2), Text('${_total.toInt()} ${widget.event?.priceCurrency?? 'FC'}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))])),
    Expanded(flex: 3, child: SizedBox(height: 46, child: ElevatedButton(onPressed: (_selected.isEmpty||_confirming)? null : _confirm, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, disabledBackgroundColor: _ThixColors.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))), child: _confirming? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('CONTINUER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))))),
  ])));
}

class _ScenePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0x14FFFFFF)..style = PaintingStyle.fill;
    final path = Path()..moveTo(0, s.height)..quadraticBezierTo(s.width/2, -s.height, s.width, s.height)..close();
    c.drawPath(path, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
