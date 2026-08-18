import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/event_seat.dart';
import '../../core/admin_constants.dart';
import '../../core/admin_guards.dart';
import '../../providers/admin_event_provider.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textMuted = Color(0x66FFFFFF);
}

class SeatMapAdminPage extends ConsumerStatefulWidget {
  const SeatMapAdminPage({super.key});
  @override ConsumerState<SeatMapAdminPage> createState() => _SeatMapAdminPageState();
}

class _SeatMapAdminPageState extends ConsumerState<SeatMapAdminPage> {
  String? _eventId;
  int _rows = 10, _perRow = 10;
  bool _hasAisle = true;
  Map<SeatCategory, double> _prices = {SeatCategory.standard: 10, SeatCategory.vip: 50, SeatCategory.gold: 100, SeatCategory.family: 25};
  Map<String, SeatCategory> _catByRow = {};
  List<EventSeat> _seats = [];
  bool _generating = false, _loading = false;

  static const _cStd = Color(0xFF10B981);
  static const _cVip = Color(0xFF8B5CF6);
  static const _cGold = Color(0xFFD4AF37);
  static const _cFam = Color(0xFF3B82F6);

  @override void initState() { super.initState(); _initCats(); }

  void _initCats() { _catByRow.clear(); for (int i = 0; i < _rows; i++) { final l = String.fromCharCode(65 + i); _catByRow[l] = i < 2? SeatCategory.vip : i < 4? SeatCategory.gold : SeatCategory.standard; } }

  Future<void> _loadSeats() async {
    if (_eventId == null) return;
    setState(() => _loading = true);
    try { _seats = await ref.read(adminEventServiceProvider).getSeatMapForAdmin(_eventId!); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _generate() async {
    if (_eventId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis un evenement'))); return; }
    final total = _rows * _perRow;
    if (total > AdminConstants.maxSeatGeneration) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Max ${AdminConstants.maxSeatGeneration}'))); return; }
    final role = await AdminGuard.getCurrentRole();
    if (!AdminGuard.canWrite(role)) return;
    setState(() => _generating = true);
    try {
      final cfg = _catByRow.map((k,v) => MapEntry(k, v.toString().split('.').last));
      final prc = _prices.map((k,v) => MapEntry(k.toString().split('.').last, v));
      await ref.read(adminEventServiceProvider).generateSeatMap(eventId: _eventId!, rows: _rows, seatsPerRow: _perRow, categoryConfig: cfg, categoryPrices: prc, hasCenterAisle: _hasAisle);
      await _loadSeats();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$total sieges generes'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _generating = false); }
  }

  Color _catColor(SeatCategory c) => switch(c) { SeatCategory.vip => _cVip, SeatCategory.gold => _cGold, SeatCategory.family => _cFam, _ => _cStd };
  Color _statusColor(EventSeat s) { if (s.status == SeatStatus.sold) return const Color(0xFFEF4444); if (s.status == SeatStatus.reserved) return const Color(0xFFF59E0B); return _catColor(s.category); }

  @override Widget build(BuildContext context) {
    final events = ref.watch(adminEventProvider).eventsState.items;

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: AppBar(backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)), title: const Text('Plan de Salle & Tarifs', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))))),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(value: _eventId, dropdownColor: _ThixColors.surface, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: _deco('Evenement cible'), items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { setState(() => _eventId = v); _loadSeats(); }),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.monetization_on_rounded, color: Colors.white, size: 14), SizedBox(width: 6), Text('Tarification Dynamique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _priceField('Standard', _prices[SeatCategory.standard]!, (v) => _prices[SeatCategory.standard] = v)), const SizedBox(width: 10), Expanded(child: _priceField('VIP', _prices[SeatCategory.vip]!, (v) => _prices[SeatCategory.vip] = v))]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _priceField('GOLD', _prices[SeatCategory.gold]!, (v) => _prices[SeatCategory.gold] = v)), const SizedBox(width: 10), Expanded(child: _priceField('Family', _prices[SeatCategory.family]!, (v) => _prices[SeatCategory.family] = v))]),
        ])),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.event_seat_rounded, color: Colors.white, size: 14), SizedBox(width: 6), Text('Forme & Disposition', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _numField('Lignes', _rows, (v) { setState(() { _rows = v; _initCats(); }); })), const SizedBox(width: 10), Expanded(child: _numField('Sieges / ligne', _perRow, (v) => setState(() => _perRow = v)))]),
          const SizedBox(height: 10),
          SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: Colors.white, title: const Text('Couloir central', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)), subtitle: const Text('Espace vide au milieu', style: TextStyle(color: _ThixColors.textMuted, fontSize: 10)), value: _hasAisle, onChanged: (v) => setState(() => _hasAisle = v)),
          const Divider(color: _ThixColors.cardBorder, height: 24),
          const Text('Categories par rangee', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(_rows, (i) { final l = String.fromCharCode(65 + i); final cat = _catByRow[l]?? SeatCategory.standard; return InkWell(onTap: () { setState(() { _catByRow[l] = cat == SeatCategory.standard? SeatCategory.vip : cat == SeatCategory.vip? SeatCategory.gold : cat == SeatCategory.gold? SeatCategory.family : SeatCategory.standard; }); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _catColor(cat).withOpacity(0.14), border: Border.all(color: _catColor(cat).withOpacity(0.6)), borderRadius: BorderRadius.circular(8)), child: Text('$l : ${cat.name.toUpperCase()}', style: TextStyle(color: _catColor(cat), fontSize: 9, fontWeight: FontWeight.w800)))); })),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(onPressed: _generating? null : _generate, icon: _generating? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.precision_manufacturing_rounded, size: 16), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))), label: Text(_generating? 'GENERATION...' : 'GENERER ${_rows * _perRow} SIEGES', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)))),
        ])),
        const SizedBox(height: 20),
        const Text('Apercu plan actuel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 10),
        if (_loading) const Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2))
        else if (_seats.isNotEmpty)...[_buildMap(), const SizedBox(height: 12), _legend()]
        else Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)), child: const Center(child: Text('Aucun siege genere', style: TextStyle(color: _ThixColors.textMuted, fontSize: 11)))),
      ]),
    );
  }

  Widget _buildMap() {
    final Map<String, List<EventSeat>> byRow = {};
    for (var s in _seats) byRow.putIfAbsent(s.row, () => []).add(s);
    final sorted = byRow.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(children: [
        Container(width: 220, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: _ThixColors.cardBorder)), child: const Center(child: Text('SCENE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)))),
        const SizedBox(height: 24),
       ...sorted.map((r) { final seats = byRow[r]!..sort((a,b) => a.number.compareTo(b.number)); final half = seats.length ~/ 2; return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))), Row(children: List.generate(seats.length, (idx) { final s = seats[idx]; final w = Container(width: 22, height: 22, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: _statusColor(s).withOpacity(s.isAvailable? 0.18 : 1), borderRadius: BorderRadius.circular(6), border: Border.all(color: _statusColor(s), width: 1.2)), child: Center(child: Text('${s.number}', style: TextStyle(color: s.isAvailable? _statusColor(s) : Colors.white, fontSize: 7, fontWeight: FontWeight.w800)))); if (_hasAisle && idx == half - 1) return Row(children: [w, const SizedBox(width: 28)]); return w; }))])) ; }),
      ])),
    );
  }

  Widget _legend() => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _ThixColors.cardBorder)), child: Wrap(spacing: 12, runSpacing: 6, children: [_dot(_cStd,'Std'), _dot(_cVip,'VIP'), _dot(_cGold,'GOLD'), _dot(const Color(0xFFF59E0B),'Reserve'), _dot(const Color(0xFFEF4444),'Vendu')]));
  Widget _dot(Color c, String l) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 5), Text(l, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))]);

  Widget _numField(String label, int v, Function(int) onChange) => TextFormField(initialValue: v.toString(), style: const TextStyle(color: Colors.white, fontSize: 11), decoration: _deco(label), keyboardType: TextInputType.number, onChanged: (x) { final n = int.tryParse(x); if (n!= null) onChange(n); });
  Widget _priceField(String label, double v, Function(double) onChange) => TextFormField(initialValue: v.toString(), style: const TextStyle(color: Colors.white, fontSize: 11), decoration: _deco(label, prefix: '\$ '), keyboardType: TextInputType.number, onChanged: (x) { final n = double.tryParse(x); if (n!= null) onChange(n); });
  InputDecoration _deco(String l, {String? prefix}) => InputDecoration(labelText: l, prefixText: prefix, prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), labelStyle: const TextStyle(color: _ThixColors.textMuted, fontSize: 10), filled: true, fillColor: _ThixColors.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _ThixColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _ThixColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10));
}
