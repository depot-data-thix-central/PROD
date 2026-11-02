// lib/presentation/thix_weeding/pages/staff/seating/seating_3d_page.dart
// ============================================================================
// THIX WEDDING — PLAN DE SALLE 2D FIXE (PRODUCTION v5 — BLUEPRINT)
// ✅ Remplacement total du moteur 3D par une vue 2D verticale fixe
// ✅ Pavé directionnel flottant (Haut/Bas/Gauche/Droite) pour navigation précise
// ✅ Zoom/Pan tactile + boutons dédiés
// ✅ Rendu blueprint propre (tables, chaises, décors en 2D)
// ✅ Toutes les fonctionnalités de placement conservées
// ============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONSTANTES / PALETTE
// ═══════════════════════════════════════════════════════════════════════════
const double _roomW = 1200;
const double _roomH = 800;
const double _seatGap = 14;
const double _kMoveStep = 20.0;
const double _kRotateStep = 0.15;
const double _panStep = 80.0;

class _C {
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color ink = Color(0xFF111827);
  static const Color ink2 = Color(0xFF6B7280);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color gridLine = Color(0xFFE2E8F0);
}

const Map<String, Color> _zoneColors = {
  'general': Color(0xFF94A3B8),
  'vip': _C.gold,
  'famille_marié': _C.blue,
  'famille_mariée': _C.rose,
  'amis': _C.purple,
  'collegues': _C.amber,
};

const Map<String, String> _zoneLabels = {
  'general': 'Général',
  'vip': 'VIP',
  'famille_marié': 'Famille marié',
  'famille_mariée': 'Famille mariée',
  'amis': 'Amis',
  'collegues': 'Collègues',
};

Color _zoneColor(String z) => _zoneColors[z] ?? _zoneColors['general']!;

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════
enum _Kind {
  tableRound, tableRect, tableSquare, stage, dance, buffet, bar, cake, dj,
  entrance, vip, plant, photobooth, wishingTree, fountain, floralArch,
}

const Map<_Kind, String> _kindKey = {
  _Kind.tableRound: 'table_round', _Kind.tableRect: 'table_rect',
  _Kind.tableSquare: 'table_square', _Kind.stage: 'stage',
  _Kind.dance: 'dance', _Kind.buffet: 'buffet', _Kind.bar: 'bar',
  _Kind.cake: 'cake', _Kind.dj: 'dj', _Kind.entrance: 'entrance',
  _Kind.vip: 'vip_zone', _Kind.plant: 'plant', _Kind.photobooth: 'photobooth',
  _Kind.wishingTree: 'wishing_tree', _Kind.fountain: 'fountain',
  _Kind.floralArch: 'floral_arch',
};

_Kind _kindFrom(String? k) => _kindKey.entries
    .firstWhere((e) => e.value == k, orElse: () => const MapEntry(_Kind.tableRound, 'table_round'))
    .key;

class _KindMeta {
  final String label;
  final IconData icon;
  final double w;
  final double h;
  const _KindMeta(this.label, this.icon, this.w, this.h);
}

const Map<_Kind, _KindMeta> _meta = {
  _Kind.tableRound: _KindMeta('Table ronde', Icons.circle_outlined, 0, 0),
  _Kind.tableRect: _KindMeta('Table rect.', Icons.rectangle_outlined, 0, 0),
  _Kind.tableSquare: _KindMeta('Table carrée', Icons.crop_square, 0, 0),
  _Kind.stage: _KindMeta('Scène', Icons.theater_comedy, 360, 90),
  _Kind.dance: _KindMeta('Piste danse', Icons.nightlife, 240, 160),
  _Kind.buffet: _KindMeta('Buffet', Icons.restaurant, 260, 50),
  _Kind.bar: _KindMeta('Bar', Icons.local_bar, 180, 44),
  _Kind.cake: _KindMeta('Gâteau', Icons.cake, 50, 50),
  _Kind.dj: _KindMeta('DJ / Sono', Icons.speaker, 130, 54),
  _Kind.entrance: _KindMeta('Entrée', Icons.door_front_door, 140, 44),
  _Kind.vip: _KindMeta('Zone VIP', Icons.star, 280, 200),
  _Kind.plant: _KindMeta('Plante', Icons.local_florist, 34, 34),
  _Kind.photobooth: _KindMeta('Photobooth', Icons.camera_alt, 160, 120),
  _Kind.wishingTree: _KindMeta('Arbre vœux', Icons.park, 90, 90),
  _Kind.fountain: _KindMeta('Fontaine', Icons.water_drop, 110, 110),
  _Kind.floralArch: _KindMeta('Arche florale', Icons.local_florist_outlined, 180, 60),
};

class _Seat {
  final int index;
  final Offset off;
  const _Seat(this.index, this.off);
}

class _Item {
  final String id;
  _Kind kind;
  String label;
  int? tableNumber;
  int capacity;
  String zone;
  double x, y, w, h, rotation;
  bool locked;

  _Item({
    required this.id, required this.kind, required this.label, this.tableNumber,
    this.capacity = 8, this.zone = 'general', this.x = 0.5, this.y = 0.5,
    this.w = 0, this.h = 0, this.rotation = 0, this.locked = false,
  });

  factory _Item.fromJson(Map<String, dynamic> j) => _Item(
        id: j['id'].toString(), kind: _kindFrom(j['kind'] as String?),
        label: (j['label'] as String?) ?? 'Table',
        tableNumber: (j['table_number'] as num?)?.toInt(),
        capacity: (j['capacity'] as num?)?.toInt() ?? 8,
        zone: (j['zone'] as String?) ?? 'general',
        x: (j['x'] as num?)?.toDouble() ?? 0.5,
        y: (j['y'] as num?)?.toDouble() ?? 0.5,
        w: (j['w'] as num?)?.toDouble() ?? 0,
        h: (j['h'] as num?)?.toDouble() ?? 0,
        rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
        locked: (j['locked'] as bool?) ?? false,
      );

  Map<String, dynamic> toRow() => {
        'kind': _kindKey[kind], 'label': label, 'table_number': tableNumber,
        'capacity': capacity, 'zone': zone, 'x': x, 'y': y, 'w': w, 'h': h,
        'rotation': rotation, 'locked': locked,
      };

  bool get isTable => kind == _Kind.tableRound || kind == _Kind.tableRect || kind == _Kind.tableSquare;
  bool get isFlat => kind == _Kind.vip || kind == _Kind.dance || kind == _Kind.entrance;
  Offset get c => Offset(x * _roomW, y * _roomH);

  Size get body {
    switch (kind) {
      case _Kind.tableRound:
        final r = 20 + capacity * 2.6;
        return Size(r * 2, r * 2);
      case _Kind.tableRect:
        final per = (capacity / 2).ceil();
        return Size(math.max(96.0, per * 34.0 + 14), 54);
      case _Kind.tableSquare:
        return const Size(78, 78);
      default:
        final m = _meta[kind]!;
        return Size(w > 0 ? w : m.w, h > 0 ? h : m.h);
    }
  }

  Size get extent => isTable
      ? Size(body.width + 80, body.height + 80)
      : Size(body.width + 24, body.height + 24);

  List<_Seat> get seats {
    final b = body;
    final n = capacity;
    final out = <_Seat>[];
    if (kind == _Kind.tableRound) {
      final r = b.width / 2 + _seatGap;
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        out.add(_Seat(i, Offset(math.cos(a) * r, math.sin(a) * r)));
      }
    } else if (kind == _Kind.tableRect) {
      final top = (n + 1) ~/ 2, bot = n - top;
      var i = 0;
      for (var k = 0; k < top; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / top, -b.height / 2 - _seatGap)));
      }
      for (var k = 0; k < bot; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / bot, b.height / 2 + _seatGap)));
      }
    } else if (kind == _Kind.tableSquare) {
      final base = n ~/ 4, rem = n % 4;
      final top = base + (rem > 0 ? 1 : 0);
      final bot = base + (rem > 1 ? 1 : 0);
      final left = base + (rem > 2 ? 1 : 0);
      final right = base;
      var i = 0;
      for (var k = 0; k < top; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / top, -b.height / 2 - _seatGap)));
      }
      for (var k = 0; k < bot; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / bot, b.height / 2 + _seatGap)));
      }
      for (var k = 0; k < left; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 - _seatGap, -b.height / 2 + b.height * (k + 0.5) / left)));
      }
      for (var k = 0; k < right; k++) {
        out.add(_Seat(i++, Offset(b.width / 2 + _seatGap, -b.height / 2 + b.height * (k + 0.5) / right)));
      }
    }
    return out;
  }
}

class _Guest {
  final String id;
  final String name;
  final int count;
  final bool isVip;
  final String? group;
  final bool active;
  String? tableId;
  List<int> seats;

  _Guest({
    required this.id, required this.name, required this.count, required this.isVip,
    required this.group, required this.active, required this.tableId, required this.seats,
  });

  factory _Guest.fromJson(Map<String, dynamic> j) => _Guest(
        id: j['id'].toString(), name: (j['name'] as String?) ?? '—',
        count: (j['guests_count'] as num?)?.toInt() ?? 1,
        isVip: (j['is_vip'] as bool?) ?? false, group: j['group_name'] as String?,
        active: (j['invitation_active'] as bool?) ?? true,
        tableId: j['hall_table_id'] as String?,
        seats: ((j['seat_indices'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      );

  bool get placed => tableId != null && seats.isNotEmpty;
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
  String get zone => isVip ? 'vip' : (group ?? 'general');
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class Seating3dPage extends ConsumerStatefulWidget {
  final String weddingId;
  const Seating3dPage({super.key, required this.weddingId});

  @override
  ConsumerState<Seating3dPage> createState() => _Seating3dPageState();
}

class _Seating3dPageState extends ConsumerState<Seating3dPage> {
  final _supa = Supabase.instance.client;
  final _labelCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  RealtimeChannel? _channel;
  Timer? _flushTimer;
  final Set<String> _dirty = {};

  List<_Item> _items = [];
  List<_Guest> _guests = [];
  bool _loaded = false;
  String? _selId;
  int? _selSeat;
  _Guest? _assigning;
  bool _showPlaced = false;
  String _query = '';

  // ✅ Navigation 2D simple
  Offset _pan = Offset.zero;
  double _scale = 1.0;
  bool _snap = true;
  bool _showGrid = true;
  bool _showPanel = true;
  bool _precisionMode = false;

  // Drag
  String? _dragId;
  Offset _dragOff = Offset.zero;
  double _scaleStart = 1.0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _flush();
    if (_channel != null) _supa.removeChannel(_channel!);
    _labelCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── DONNÉES ─────────────────────────
  Future<void> _bootstrap() async {
    try {
      final rows = await _supa
          .from('thix_weeding_hall_items')
          .select()
          .eq('wedding_id', widget.weddingId)
          .order('order_index', ascending: true);
      _items = (rows as List)
          .map((e) => _Item.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _fetchGuests();
      _subscribe();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      _toast('Chargement du plan : $e', error: true);
    }
  }

  Future<void> _fetchGuests() async {
    final rows = await _supa
        .from('thix_weeding_guests')
        .select('id, name, guests_count, is_vip, group_name, hall_table_id, seat_indices, invitation_active')
        .eq('wedding_id', widget.weddingId);
    _guests = (rows as List)
        .map((e) => _Guest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _reloadGuests() async {
    try {
      await _fetchGuests();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _subscribe() {
    _channel = _supa
        .channel('hall-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_guests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: widget.weddingId,
          ),
          callback: (_) => _reloadGuests(),
        )
        .subscribe();
  }

  void _markDirty(String id) {
    _dirty.add(id);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 700), _flush);
  }

  Future<void> _flush() async {
    if (_dirty.isEmpty) return;
    final ids = _dirty.toList();
    _dirty.clear();
    for (final id in ids) {
      final it = _itemById(id);
      if (it == null) continue;
      try {
        await _supa.from('thix_weeding_hall_items').update(it.toRow()).eq('id', id);
      } catch (e) {
        _toast('Enregistrement : $e', error: true);
      }
    }
  }

  // ───────────────────────── HELPERS ─────────────────────────
  _Item? _itemById(String? id) {
    if (id == null) return null;
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  _Item? get _selected => _itemById(_selId);

  Map<int, _Guest> _occupancy(String tableId, {String? exclude}) {
    final m = <int, _Guest>{};
    for (final g in _guests) {
      if (!g.active || g.tableId != tableId || g.id == exclude) continue;
      for (final s in g.seats) m[s] = g;
    }
    return m;
  }

  List<int> _freeSeats(_Item t, {String? exclude}) {
    final occ = _occupancy(t.id, exclude: exclude);
    return [for (var i = 0; i < t.capacity; i++) if (!occ.containsKey(i)) i];
  }

  int get _totalSeats => _items.where((i) => i.isTable).fold(0, (s, i) => s + i.capacity);
  int get _seatedPersons => _guests.where((g) => g.active && g.placed).fold(0, (s, g) => s + g.count);
  int get _totalPersons => _guests.where((g) => g.active).fold(0, (s, g) => s + g.count);

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: error ? _C.rose : _C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
      ));
  }

  void _select(String? id) {
    setState(() {
      _selId = id;
      _selSeat = null;
    });
    _labelCtrl.text = _itemById(id)?.label ?? '';
  }

  // ───────────────────────── NAVIGATION 2D ─────────────────────────
  void _panView(double dx, double dy) {
    setState(() => _pan = Offset(_pan.dx + dx, _pan.dy + dy));
  }

  void _resetView() {
    setState(() {
      _pan = Offset.zero;
      _scale = 1.0;
    });
  }

  void _zoomBy(double factor) {
    setState(() => _scale = (_scale * factor).clamp(0.4, 3.0).toDouble());
  }

  // ───────────────────────── HIT-TEST 2D ─────────────────────────
  bool _contains2D(_Item it, Offset p) {
    final d = p - it.c;
    // Appliquer la rotation inverse pour le hit-test
    final cos = math.cos(-it.rotation);
    final sin = math.sin(-it.rotation);
    final lx = d.dx * cos - d.dy * sin;
    final ly = d.dx * sin + d.dy * cos;
    final b = it.body;
    if (it.kind == _Kind.tableRound) return Offset(lx, ly).distance <= b.width / 2 + 8;
    return lx.abs() <= b.width / 2 + 8 && ly.abs() <= b.height / 2 + 8;
  }

  _Item? _hitItem2D(Offset p) {
    _Item? best;
    var bestRank = -1;
    for (final it in _items) {
      if (!_contains2D(it, p)) continue;
      final rank = it.isTable ? 2 : (it.isFlat ? 0 : 1);
      if (rank >= bestRank) {
        best = it;
        bestRank = rank;
      }
    }
    return best;
  }

  (_Item, int)? _hitSeat2D(Offset p) {
    for (final it in _items.where((i) => i.isTable)) {
      for (final s in it.seats) {
        // Position de la chaise en tenant compte de la rotation de la table
        final cos = math.cos(it.rotation);
        final sin = math.sin(it.rotation);
        final sx = s.off.dx * cos - s.off.dy * sin;
        final sy = s.off.dx * sin + s.off.dy * cos;
        final pos = it.c + Offset(sx, sy);
        if ((pos - p).distance < 18) return (it, s.index);
      }
    }
    return null;
  }

  void _onTap(Offset p) {
    final hs = _hitSeat2D(p);
    if (hs != null) {
      _onSeatTap(hs.$1, hs.$2);
      return;
    }
    _select(_hitItem2D(p)?.id);
  }

  Future<void> _onSeatTap(_Item t, int seat) async {
    HapticFeedback.selectionClick();
    final occ = _occupancy(t.id);
    final g = _assigning;
    if (g != null) {
      final other = occ[seat];
      if (other == null) {
        await _assign(g, t, seat);
        return;
      }
      if (other.id != g.id) {
        _toast('Place déjà occupée par ${other.name}', error: true);
        return;
      }
    }
    _select(t.id);
    setState(() => _selSeat = seat);
  }

  // ───────────────────────── GESTES ÉDITION 2D ─────────────────────────
  void _editStart(ScaleStartDetails d) {
    _scaleStart = _scale;
    _dragId = null;
    if (d.pointerCount >= 2) return;
    final it = _hitItem2D(d.localFocalPoint);
    if (it != null && !it.locked) {
      _dragId = it.id;
      _dragOff = it.c - d.localFocalPoint;
      if (_selId != it.id) _select(it.id);
    }
  }

  void _editUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      _dragId = null;
      setState(() => _scale = (_scaleStart * d.scale).clamp(0.4, 3.0).toDouble());
      return;
    }
    final it = _itemById(_dragId);
    if (it == null) return;
    var p = d.localFocalPoint + _dragOff;
    if (_snap) {
      p = Offset((p.dx / 20).round() * 20.0, (p.dy / 20).round() * 20.0);
    }
    setState(() {
      it.x = (p.dx / _roomW).clamp(0.03, 0.97).toDouble();
      it.y = (p.dy / _roomH).clamp(0.03, 0.97).toDouble();
    });
  }

  void _editEnd(ScaleEndDetails d) {
    final id = _dragId;
    _dragId = null;
    if (id != null) _markDirty(id);
  }

  // ───────────────────────── MOUVEMENTS PRÉCIS ─────────────────────────
  void _moveSelectedBy(double dx, double dy) {
    final sel = _selected;
    if (sel == null || sel.locked) return;
    final step = _precisionMode ? 5.0 : _kMoveStep;
    final nx = sel.x * _roomW + dx * step;
    final ny = sel.y * _roomH + dy * step;
    setState(() {
      sel.x = (nx / _roomW).clamp(0.03, 0.97).toDouble();
      sel.y = (ny / _roomH).clamp(0.03, 0.97).toDouble();
    });
    HapticFeedback.lightImpact();
    _markDirty(sel.id);
  }

  void _rotateSelectedBy(double delta) {
    final sel = _selected;
    if (sel == null || sel.locked) return;
    setState(() => sel.rotation += delta);
    HapticFeedback.lightImpact();
    _markDirty(sel.id);
  }

  void _focusSelected() {
    final sel = _selected;
    if (sel == null) return;
    setState(() {
      _scale = 1.8;
      // Centrer la vue sur l'élément sélectionné
      final screenW = MediaQuery.of(context).size.width;
      final screenH = MediaQuery.of(context).size.height;
      final targetX = sel.x * _roomW * _scale;
      final targetY = sel.y * _roomH * _scale;
      _pan = Offset(screenW / 2 - targetX, screenH / 2 - targetY);
    });
    _toast('Centré sur ${sel.label}');
  }

  // ───────────────────────── ÉLÉMENTS CRUD ─────────────────────────
  Future<void> _addItem(_Kind kind) async {
    final isTable = kind == _Kind.tableRound || kind == _Kind.tableRect || kind == _Kind.tableSquare;
    final nums = _items.where((i) => i.isTable).map((e) => e.tableNumber ?? 0);
    final n = nums.isEmpty ? 1 : nums.reduce(math.max) + 1;
    final row = {
      'wedding_id': widget.weddingId,
      'kind': _kindKey[kind],
      'label': isTable ? 'Table $n' : _meta[kind]!.label,
      'table_number': isTable ? n : null,
      'capacity': isTable ? (kind == _Kind.tableSquare ? 4 : 8) : 0,
      'zone': 'general',
      'x': 0.5 + ((_items.length % 5) - 2) * 0.08,
      'y': 0.5 + (((_items.length ~/ 5) % 3) - 1) * 0.12,
      'w': 0, 'h': 0, 'rotation': 0,
      'order_index': _items.length,
    };
    try {
      final res = await _supa.from('thix_weeding_hall_items').insert(row).select().single();
      final it = _Item.fromJson(Map<String, dynamic>.from(res));
      setState(() => _items.add(it));
      _select(it.id);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _toast('Ajout impossible : $e', error: true);
    }
  }

  Future<void> _duplicate(_Item it) async {
    final nums = _items.where((i) => i.isTable).map((e) => e.tableNumber ?? 0);
    final n = nums.isEmpty ? 1 : nums.reduce(math.max) + 1;
    final row = it.toRow()
      ..['wedding_id'] = widget.weddingId
      ..['x'] = (it.x + 0.06).clamp(0.03, 0.97).toDouble()
      ..['y'] = (it.y + 0.06).clamp(0.03, 0.97).toDouble()
      ..['order_index'] = _items.length;
    if (it.isTable) {
      row['table_number'] = n;
      row['label'] = 'Table $n';
    }
    try {
      final res = await _supa.from('thix_weeding_hall_items').insert(row).select().single();
      final c = _Item.fromJson(Map<String, dynamic>.from(res));
      setState(() => _items.add(c));
      _select(c.id);
    } catch (e) {
      _toast('Duplication impossible : $e', error: true);
    }
  }

  Future<bool> _confirm(String title, String msg, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: _C.rose), onPressed: () => Navigator.pop(context, true), child: Text(ok)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _deleteItem(_Item it) async {
    final ok = await _confirm(
      'Supprimer « ${it.label} » ?',
      it.isTable ? 'Les invités placés seront libérés.' : 'Cet élément sera retiré.',
      'Supprimer',
    );
    if (!ok) return;
    try {
      if (it.isTable) {
        await _supa.from('thix_weeding_guests').update({
          'hall_table_id': null, 'seat_indices': <int>[], 'table_number': null,
        }).eq('hall_table_id', it.id);
      }
      await _supa.from('thix_weeding_hall_items').delete().eq('id', it.id);
      setState(() => _items.removeWhere((i) => i.id == it.id));
      _select(null);
      await _reloadGuests();
      ref.invalidate(guestsProvider(widget.weddingId));
    } catch (e) {
      _toast('Suppression impossible : $e', error: true);
    }
  }

  // ───────────────────────── PLACEMENT INVITÉS ─────────────────────────
  Future<bool> _assignSeats(_Guest g, _Item t, List<int> seats, {bool quiet = false}) async {
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': t.id, 'seat_indices': seats, 'table_number': t.tableNumber,
      }).eq('id', g.id);
      g.tableId = t.id;
      g.seats = seats;
      if (mounted) setState(() { if (_assigning?.id == g.id) _assigning = null; });
      ref.invalidate(guestsProvider(widget.weddingId));
      if (!quiet) {
        HapticFeedback.mediumImpact();
        _toast('${g.name} → ${t.label}, place${seats.length > 1 ? 's' : ''} ${seats.map((s) => s + 1).join(', ')}');
      }
      return true;
    } catch (e) {
      if (!quiet) _toast('Placement impossible : $e', error: true);
      return false;
    }
  }

  Future<void> _assign(_Guest g, _Item t, int start) async {
    final occ = _occupancy(t.id, exclude: g.id);
    final order = <int>[];
    for (var k = 0; k < t.capacity && order.length < g.count; k++) {
      final s = (start + k) % t.capacity;
      if (!occ.containsKey(s)) order.add(s);
    }
    if (order.length < g.count) {
      _toast('Pas assez de places libres (${g.count} nécessaires)', error: true);
      return;
    }
    order.sort();
    await _assignSeats(g, t, order);
  }

  List<_Item> _bestTables(_Guest g) {
    final tables = _items.where((i) => i.isTable).toList()
      ..sort((a, b) => (a.tableNumber ?? 0).compareTo(b.tableNumber ?? 0));
    return [...tables.where((t) => t.zone == g.zone), ...tables.where((t) => t.zone != g.zone)];
  }

  Future<bool> _autoOne(_Guest g, {_Item? table, bool quiet = false}) async {
    final cands = table != null ? [table] : _bestTables(g);
    for (final t in cands) {
      final free = _freeSeats(t, exclude: g.id);
      if (free.length >= g.count) return _assignSeats(g, t, free.take(g.count).toList(), quiet: quiet);
    }
    if (!quiet) _toast('Aucune table n\'a assez de places libres', error: true);
    return false;
  }

  Future<void> _autoPlaceAll() async {
    final pending = _guests.where((g) => g.active && !g.placed).toList()
      ..sort((a, b) => (b.isVip ? 1 : 0).compareTo(a.isVip ? 1 : 0));
    if (pending.isEmpty) { _toast('Tous les invités sont déjà placés'); return; }
    var ok = 0;
    for (final g in pending) { if (await _autoOne(g, quiet: true)) ok++; }
    HapticFeedback.heavyImpact();
    _toast('$ok/${pending.length} invité(s) placé(s) automatiquement', error: ok < pending.length);
  }

  Future<void> _unplace(_Guest g) async {
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': null, 'seat_indices': <int>[], 'table_number': null,
      }).eq('id', g.id);
      g.tableId = null;
      g.seats = [];
      setState(() {});
      ref.invalidate(guestsProvider(widget.weddingId));
    } catch (e) {
      _toast('Erreur : $e', error: true);
    }
  }

  Future<void> _releaseAll() async {
    final ok = await _confirm('Tout libérer ?', 'Tous les invités seront retirés de leurs chaises.', 'Libérer');
    if (!ok) return;
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': null, 'seat_indices': <int>[], 'table_number': null,
      }).eq('wedding_id', widget.weddingId).not('hall_table_id', 'is', null);
      await _reloadGuests();
      ref.invalidate(guestsProvider(widget.weddingId));
      _toast('Toutes les places sont libres');
    } catch (e) {
      _toast('Erreur : $e', error: true);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(backgroundColor: _C.bg, body: Center(child: CircularProgressIndicator(color: _C.gold)));
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = MediaQuery.of(context).size.height * 0.40;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── 1. CANVAS 2D ──────────────────────────────────────────────
          Positioned.fill(child: _canvas()),

          // ── 2. TOOLBAR HAUT ───────────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: _toolbar())),

          // ── 3. BOUTON PANNEAU ─────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 64, right: 12,
            child: FloatingActionButton.small(
              backgroundColor: _showPanel ? _C.rose : _C.blue,
              onPressed: () => setState(() => _showPanel = !_showPanel),
              child: Icon(_showPanel ? Icons.close : Icons.tune, color: Colors.white),
            ),
          ),

          // ── 4. STATS BAS-GAUCHE ───────────────────────────────────────
          Positioned(
            left: 12, bottom: _showPanel ? panelHeight + 20 : 20,
            child: ThixGlass(
              radius: 14, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('$_seatedPersons/$_totalPersons placés · $_totalSeats chaises', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _C.ink)),
                Text('Glissez pour déplacer · Pincez pour zoomer', style: GoogleFonts.inter(fontSize: 9.5, color: _C.ink2)),
              ]),
            ),
          ),

          // ── 5. PAVÉ DIRECTIONNEL BAS-DROITE ──────────────────────────
          Positioned(
            right: 12, bottom: _showPanel ? panelHeight + 20 : 20,
            child: _DirectionPad(
              onUp: () => _panView(0, _panStep),
              onDown: () => _panView(0, -_panStep),
              onLeft: () => _panView(_panStep, 0),
              onRight: () => _panView(-_panStep, 0),
              onCenter: _resetView,
              onZoomIn: () => _zoomBy(1.3),
              onZoomOut: () => _zoomBy(0.77),
            ),
          ),

          // ── 6. JOYSTICK ÉLÉMENT SÉLECTIONNÉ ──────────────────────────
          if (_selected != null)
            Positioned(
              left: 12, right: 12,
              bottom: _showPanel ? panelHeight + 80 : 80,
              child: _SelectionJoystick(
                item: _selected!,
                precision: _precisionMode,
                onPrecisionToggle: () => setState(() => _precisionMode = !_precisionMode),
                onMove: _moveSelectedBy,
                onRotate: _rotateSelectedBy,
                onFocus: _focusSelected,
                onDuplicate: () { final s = _selected; if (s != null) _duplicate(s); },
                onDeselect: () => _select(null),
              ),
            ),

          // ── 7. PANNEAU CONFIGURATION ──────────────────────────────────
          if (_showPanel)
            Positioned(
              left: 12, right: 12, bottom: 12 + bottomInset, height: panelHeight,
              child: ThixGlass(radius: 24, padding: EdgeInsets.zero, child: _selected == null ? _guestsPanel() : _itemPanel(_selected!)),
            ),

          // ── 8. BANNIÈRE PLACEMENT ────────────────────────────────────
          if (_assigning != null)
            Positioned(
              top: 76, left: 12, right: 70,
              child: ThixGlass(
                radius: 16, blur: 14, padding: const EdgeInsets.fromLTRB(12, 8, 6, 8), tint: const Color(0xFFFFF3C4),
                child: Row(children: [
                  const Icon(Icons.event_seat_rounded, size: 18, color: _C.goldDark),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Placer ${_assigning!.name} (${_assigning!.count} pers.) — touchez une chaise', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _assigning = null)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── CANVAS 2D ─────────────────────────
  Widget _canvas() {
    return GestureDetector(
      onScaleStart: _editStart,
      onScaleUpdate: _editUpdate,
      onScaleEnd: _editEnd,
      onTapUp: (d) => _onTap(d.localPosition),
      child: Container(
        color: _C.bg,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: _roomW, maxWidth: _roomW,
            minHeight: _roomH, maxHeight: _roomH,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(_pan.dx, _pan.dy)
                ..scale(_scale),
              child: SizedBox(
                width: _roomW,
                height: _roomH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Sol
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _C.gold, width: 4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Grille
                    if (_showGrid)
                      Positioned.fill(
                        child: IgnorePointer(child: CustomPaint(painter: _GridPainter2D())),
                      ),
                    // Éléments triés : flat d'abord, puis solides
                    for (final it in _items.where((i) => i.isFlat)) _placed2D(it),
                    for (final it in _items.where((i) => !i.isFlat)) _placed2D(it),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placed2D(_Item it) {
    final e = it.extent;
    final c = it.c;
    final sel = it.id == _selId;
    return Positioned(
      left: c.dx - e.width / 2, top: c.dy - e.height / 2,
      width: e.width, height: e.height,
      child: Transform.rotate(
        angle: it.rotation,
        child: it.isTable
            ? _Table2D(item: it, occ: _occupancy(it.id), selected: sel, selSeat: sel ? _selSeat : null, assigning: _assigning != null)
            : _Decor2D(item: it, selected: sel),
      ),
    );
  }

  // ───────────────────────── TOOLBAR ─────────────────────────
  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18), onPressed: () => Navigator.maybePop(context)),
            const SizedBox(width: 4),
            Text('Plan de salle', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            const Spacer(),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.grid_on_rounded, color: Colors.white54, size: 20), onPressed: () => setState(() => _showGrid = !_showGrid)),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline, color: _C.gold, size: 22), onPressed: _openAddSheet),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.tune_rounded, color: _C.blue, size: 22), onPressed: _openSettings),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── PANNEAU INVITÉS ─────────────────────────
  Widget _guestsPanel() {
    final q = _query.toLowerCase();
    final list = _guests.where((g) => g.active && (_showPlaced ? g.placed : !g.placed) && (q.isEmpty || g.name.toLowerCase().contains(q))).toList();
    final unplacedCount = _guests.where((g) => g.active && !g.placed).length;
    final ratio = _totalPersons == 0 ? 0.0 : _seatedPersons / _totalPersons;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(children: [
            Row(children: [
              Text('Invités', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _C.ink)),
              const Spacer(),
              Text('${(ratio * 100).round()}% placés', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _C.green)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.white.withOpacity(0.6), valueColor: const AlwaysStoppedAnimation(_C.green))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _searchCtrl, onChanged: (v) => setState(() => _query = v), style: GoogleFonts.inter(fontSize: 13), decoration: InputDecoration(isDense: true, hintText: 'Rechercher', prefixIcon: const Icon(Icons.search, size: 18), filled: true, fillColor: Colors.white.withOpacity(0.55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
              const SizedBox(width: 8),
              _Pill(label: 'À placer ($unplacedCount)', icon: Icons.person_outline, selected: !_showPlaced, onTap: () => setState(() => _showPlaced = false)),
              const SizedBox(width: 4),
              _Pill(icon: Icons.event_seat_rounded, selected: _showPlaced, onTap: () => setState(() => _showPlaced = true)),
            ]),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(_showPlaced ? 'Personne n\'est encore placé' : 'Tous les invités sont placés ✨', style: GoogleFonts.inter(color: _C.ink2, fontSize: 12)))
              : ListView.separated(padding: const EdgeInsets.fromLTRB(14, 4, 14, 14), itemCount: list.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) => _guestTile(list[i])),
        ),
      ],
    );
  }

  Widget _guestTile(_Guest g, {_Item? table}) {
    final t = _itemById(g.tableId);
    final sub = g.placed
        ? '${t?.label ?? 'Table'} · place${g.seats.length > 1 ? 's' : ''} ${(List<int>.from(g.seats)..sort()).map((s) => s + 1).join(', ')}'
        : '${_zoneLabels[g.zone] ?? 'Général'} · ${g.count} pers.';
    return GestureDetector(
      onTap: g.placed && t != null ? () => _select(t.id) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.9))),
        child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: _zoneColor(g.zone).withOpacity(0.2), child: g.isVip ? const Icon(Icons.star, size: 15, color: _C.gold) : Text(g.initial, style: TextStyle(color: _zoneColor(g.zone), fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _C.ink)),
            Text(sub, style: GoogleFonts.inter(fontSize: 10.5, color: _C.ink2)),
          ])),
          if (g.placed)
            IconButton(tooltip: 'Libérer', visualDensity: VisualDensity.compact, icon: const Icon(Icons.link_off_rounded, size: 19, color: _C.rose), onPressed: () => _unplace(g))
          else ...[
            IconButton(tooltip: 'Auto', visualDensity: VisualDensity.compact, icon: const Icon(Icons.auto_fix_high_rounded, size: 19, color: _C.blue), onPressed: () => _autoOne(g, table: table)),
            IconButton(tooltip: 'Choisir chaise', visualDensity: VisualDensity.compact, icon: const Icon(Icons.event_seat_rounded, size: 19, color: _C.goldDark), onPressed: () { setState(() { _assigning = g; }); }),
          ],
        ]),
      ),
    );
  }

  // ───────────────────────── PANNEAU ÉLÉMENT ─────────────────────────
  Widget _itemPanel(_Item it) {
    final meta = _meta[it.kind]!;
    final zc = _zoneColor(it.zone);
    final occ = it.isTable ? _occupancy(it.id) : <int, _Guest>{};
    final seated = it.isTable ? _guests.where((g) => g.active && g.tableId == it.id).toList() : <_Guest>[];
    final unplaced = _guests.where((g) => g.active && !g.placed).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: LinearGradient(colors: [zc, zc.withOpacity(0.7)]), borderRadius: BorderRadius.circular(10)), child: Icon(meta.icon, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _labelCtrl, onChanged: (v) { it.label = v; _markDirty(it.id); setState(() {}); }, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: _C.ink), decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Nom'))),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _select(null)),
        ]),
        if (it.isTable) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _Stepper(label: 'Chaises', value: it.capacity, onMinus: () {
              final maxUsed = occ.keys.isEmpty ? -1 : occ.keys.reduce(math.max);
              if (it.capacity - 1 <= maxUsed) { _toast('Libérez d\'abord la place ${maxUsed + 1}', error: true); return; }
              if (it.capacity > 2) { setState(() => it.capacity--); _markDirty(it.id); }
            }, onPlus: () { if (it.capacity < (it.kind == _Kind.tableSquare ? 8 : 20)) { setState(() => it.capacity++); _markDirty(it.id); } })),
            const SizedBox(width: 8),
            Expanded(child: _Stepper(label: 'N° table', value: it.tableNumber ?? 0, onMinus: () { if ((it.tableNumber ?? 1) > 1) { setState(() => it.tableNumber = (it.tableNumber ?? 1) - 1); _markDirty(it.id); } }, onPlus: () { setState(() => it.tableNumber = (it.tableNumber ?? 0) + 1); _markDirty(it.id); })),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 2, children: _zoneLabels.entries.map((e) => ChoiceChip(label: Text(e.value, style: const TextStyle(fontSize: 11)), selected: it.zone == e.key, selectedColor: _zoneColor(e.key).withOpacity(0.25), visualDensity: VisualDensity.compact, onSelected: (_) { setState(() => it.zone = e.key); _markDirty(it.id); })).toList()),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [_Kind.tableRound, _Kind.tableRect, _Kind.tableSquare].map((k) => ChoiceChip(label: Text(_meta[k]!.label, style: const TextStyle(fontSize: 11)), avatar: Icon(_meta[k]!.icon, size: 14), selected: it.kind == k, visualDensity: VisualDensity.compact, onSelected: (_) { if (k == _Kind.tableSquare && it.capacity > 8) { _toast('Max 8 chaises', error: true); return; } setState(() => it.kind = k); _markDirty(it.id); })).toList()),
        ],
        if (it.kind != _Kind.tableRound && it.kind != _Kind.plant && it.kind != _Kind.cake)
          _slider('Rotation', it.rotation, -math.pi, math.pi, (v) { setState(() => it.rotation = v); _markDirty(it.id); }),
        if (!it.isTable && it.kind != _Kind.plant && it.kind != _Kind.cake) ...[
          _slider('Largeur', it.body.width, 60, 520, (v) { setState(() => it.w = v); _markDirty(it.id); }),
          _slider('Hauteur', it.body.height, 30, 320, (v) { setState(() => it.h = v); _markDirty(it.id); }),
        ],
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _duplicate(it), icon: const Icon(Icons.copy_rounded, size: 16), label: const Text('Dupliquer'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () { setState(() => it.locked = !it.locked); _markDirty(it.id); }, icon: Icon(it.locked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16), label: Text(it.locked ? 'Verrouillé' : 'Verrouiller'))),
          const SizedBox(width: 8),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: _C.rose), onPressed: () => _deleteItem(it), icon: const Icon(Icons.delete_outline, size: 20)),
        ]),
        if (it.isTable) ...[
          const SizedBox(height: 14),
          Text('À cette table (${occ.length}/${it.capacity})', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: _C.ink)),
          const SizedBox(height: 6),
          if (seated.isEmpty) Text('Personne pour l\'instant', style: GoogleFonts.inter(fontSize: 12, color: _C.ink2))
          else ...seated.map((g) => Padding(padding: const EdgeInsets.only(bottom: 6), child: _guestTile(g))),
          const SizedBox(height: 12),
          Text('Placer un invité ici', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: _C.ink)),
          const SizedBox(height: 6),
          if (unplaced.isEmpty) Text('Aucun invité libre', style: GoogleFonts.inter(fontSize: 12, color: _C.ink2))
          else ...unplaced.map((g) => Padding(padding: const EdgeInsets.only(bottom: 6), child: _guestTile(g, table: it))),
        ],
      ],
    );
  }

  Widget _slider(String label, double v, double min, double max, ValueChanged<double> on) {
    return Row(children: [
      SizedBox(width: 70, child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: _C.ink2, fontWeight: FontWeight.w600))),
      Expanded(child: Slider(value: v.clamp(min, max).toDouble(), min: min, max: max, activeColor: _C.blue, onChanged: on)),
    ]);
  }

  // ───────────────────────── SHEETS ─────────────────────────
  void _openAddSheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => Padding(
      padding: const EdgeInsets.all(12),
      child: ThixGlass(radius: 26, opacity: 0.9, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ajouter à la salle', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _Kind.values.map((k) {
          final m = _meta[k]!;
          return GestureDetector(onTap: () { Navigator.pop(context); _addItem(k); }, child: Container(
            width: 90, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white)),
            child: Column(children: [Icon(m.icon, color: _C.blue, size: 24), const SizedBox(height: 6), Text(m.label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700))]),
          ));
        }).toList()),
      ])),
    ));
  }

  void _openSettings() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
      padding: const EdgeInsets.all(12),
      child: ThixGlass(radius: 26, opacity: 0.9, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Réglages du plan', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        SwitchListTile(dense: true, title: const Text('Aimanter à la grille'), value: _snap, onChanged: (v) { setState(() => _snap = v); setM(() {}); }),
        SwitchListTile(dense: true, title: const Text('Afficher la grille'), value: _showGrid, onChanged: (v) { setState(() => _showGrid = v); setM(() {}); }),
        const Divider(),
        ListTile(dense: true, leading: const Icon(Icons.auto_fix_high_rounded, color: _C.blue), title: const Text('Placer tous automatiquement'), onTap: () { Navigator.pop(ctx); _autoPlaceAll(); }),
        ListTile(dense: true, leading: const Icon(Icons.link_off_rounded, color: _C.rose), title: const Text('Libérer toutes les chaises'), onTap: () { Navigator.pop(ctx); _releaseAll(); }),
      ])),
    )));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAVÉ DIRECTIONNEL FLOTTANT
// ═══════════════════════════════════════════════════════════════════════════
class _DirectionPad extends StatelessWidget {
  final VoidCallback onUp, onDown, onLeft, onRight, onCenter, onZoomIn, onZoomOut;
  const _DirectionPad({required this.onUp, required this.onDown, required this.onLeft, required this.onRight, required this.onCenter, required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    const sz = 38.0;
    return ThixGlass(
      radius: 22, padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Zoom In
        _PadBtn(icon: Icons.add, onTap: onZoomIn, size: 32),
        const SizedBox(height: 4),
        // Haut
        _PadBtn(icon: Icons.arrow_upward_rounded, onTap: onUp),
        const SizedBox(height: 2),
        // Gauche - Centre - Droite
        Row(mainAxisSize: MainAxisSize.min, children: [
          _PadBtn(icon: Icons.arrow_back_rounded, onTap: onLeft),
          const SizedBox(width: 2),
          _PadBtn(icon: Icons.center_focus_strong_rounded, onTap: onCenter, filled: true),
          const SizedBox(width: 2),
          _PadBtn(icon: Icons.arrow_forward_rounded, onTap: onRight),
        ]),
        const SizedBox(height: 2),
        // Bas
        _PadBtn(icon: Icons.arrow_downward_rounded, onTap: onDown),
        const SizedBox(height: 4),
        // Zoom Out
        _PadBtn(icon: Icons.remove, onTap: onZoomOut, size: 32),
      ]),
    );
  }
}

class _PadBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final double size;
  const _PadBtn({required this.icon, required this.onTap, this.filled = false, this.size = 38});

  @override
  State<_PadBtn> createState() => _PadBtnState();
}

class _PadBtnState extends State<_PadBtn> {
  Timer? _repeatTimer;

  void _start() {
    widget.onTap();
    // Répétition uniquement pour les flèches directionnelles
    if (!widget.filled && widget.icon != Icons.add && widget.icon != Icons.remove) {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => widget.onTap());
    }
  }

  void _stop() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() { _stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: widget.filled ? _C.gold.withOpacity(0.25) : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.filled ? _C.gold : Colors.white.withOpacity(0.8), width: 1.2),
        ),
        child: Icon(widget.icon, size: widget.size * 0.48, color: widget.filled ? _C.goldDark : _C.ink),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// JOYSTICK ÉLÉMENT SÉLECTIONNÉ
// ═══════════════════════════════════════════════════════════════════════════
class _SelectionJoystick extends StatelessWidget {
  final _Item item;
  final bool precision;
  final VoidCallback onPrecisionToggle;
  final void Function(double dx, double dy) onMove;
  final void Function(double delta) onRotate;
  final VoidCallback onFocus;
  final VoidCallback onDuplicate;
  final VoidCallback onDeselect;

  const _SelectionJoystick({
    required this.item, required this.precision, required this.onPrecisionToggle,
    required this.onMove, required this.onRotate, required this.onFocus,
    required this.onDuplicate, required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.gold, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('✦ ${item.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
          Text(precision ? 'Précis (5 px)' : 'Normal (20 px)', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
        ])),
        // Mini D-pad pour déplacement précis
        _MiniDPad(onMove: onMove),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            _JoyBtn(icon: Icons.rotate_left_rounded, onTap: () => onRotate(-_kRotateStep), color: _C.blue),
            const SizedBox(width: 4),
            _JoyBtn(icon: Icons.rotate_right_rounded, onTap: () => onRotate(_kRotateStep), color: _C.blue),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _JoyBtn(icon: Icons.center_focus_strong_rounded, tooltip: 'Centrer', onTap: onFocus, color: _C.gold),
            const SizedBox(width: 4),
            _JoyBtn(icon: Icons.precision_manufacturing_rounded, tooltip: 'Précis', onTap: onPrecisionToggle, color: precision ? _C.green : Colors.white54, filled: precision),
            const SizedBox(width: 4),
            _JoyBtn(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: onDeselect, color: _C.rose),
          ]),
        ]),
      ]),
    );
  }
}

class _MiniDPad extends StatelessWidget {
  final void Function(double dx, double dy) onMove;
  const _MiniDPad({required this.onMove});

  @override
  Widget build(BuildContext context) {
    const sz = 26.0;
    return SizedBox(
      width: sz * 3 + 4, height: sz * 3 + 4,
      child: Stack(children: [
        Positioned(left: sz + 2, top: 0, child: _MiniDPadBtn(icon: Icons.arrow_upward_rounded, onTap: () => onMove(0, -1))),
        Positioned(left: sz + 2, bottom: 0, child: _MiniDPadBtn(icon: Icons.arrow_downward_rounded, onTap: () => onMove(0, 1))),
        Positioned(left: 0, top: sz + 2, child: _MiniDPadBtn(icon: Icons.arrow_back_rounded, onTap: () => onMove(-1, 0))),
        Positioned(right: 0, top: sz + 2, child: _MiniDPadBtn(icon: Icons.arrow_forward_rounded, onTap: () => onMove(1, 0))),
        Positioned(left: sz + 2, top: sz + 2, child: Container(width: sz, height: sz, decoration: BoxDecoration(color: _C.gold.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: _C.gold, width: 1)), child: const Icon(Icons.open_with_rounded, size: 12, color: _C.gold))),
      ]),
    );
  }
}

class _MiniDPadBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniDPadBtn({required this.icon, required this.onTap});
  @override
  State<_MiniDPadBtn> createState() => _MiniDPadBtnState();
}

class _MiniDPadBtnState extends State<_MiniDPadBtn> {
  Timer? _t;
  void _start() { widget.onTap(); _t = Timer.periodic(const Duration(milliseconds: 100), (_) => widget.onTap()); }
  void _stop() { _t?.cancel(); _t = null; }
  @override
  void dispose() { _stop(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _start(), onTapUp: (_) => _stop(), onTapCancel: _stop,
    child: Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24)), child: Icon(widget.icon, color: Colors.white, size: 14)),
  );
}

class _JoyBtn extends StatelessWidget {
  final IconData icon; final String? tooltip; final VoidCallback onTap; final Color color; final bool filled;
  const _JoyBtn({required this.icon, required this.onTap, required this.color, this.tooltip, this.filled = false});
  @override
  Widget build(BuildContext context) {
    final btn = InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(
      width: 28, height: 28, decoration: BoxDecoration(color: filled ? color : color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(filled ? 1 : 0.5), width: 1)),
      child: Icon(icon, size: 15, color: filled ? Colors.white : color),
    ));
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRILLE 2D
// ═══════════════════════════════════════════════════════════════════════════
class _GridPainter2D extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _C.gridLine..strokeWidth = 0.8..style = PaintingStyle.stroke;
    const step = 40.0;
    for (var x = 0.0; x <= size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (var y = 0.0; y <= size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    // Bordure dorée
    final border = Paint()..color = _C.gold..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), border);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// TABLE 2D
// ═══════════════════════════════════════════════════════════════════════════
class _Table2D extends StatelessWidget {
  final _Item item;
  final Map<int, _Guest> occ;
  final bool selected;
  final int? selSeat;
  final bool assigning;

  const _Table2D({required this.item, required this.occ, required this.selected, required this.selSeat, required this.assigning});

  @override
  Widget build(BuildContext context) {
    final b = item.body;
    final round = item.kind == _Kind.tableRound;
    final zc = _zoneColor(item.zone);
    final seats = item.seats;

    Widget chair(_Seat s) {
      final g = occ[s.index];
      final isSel = selSeat == s.index;
      final isPick = assigning && g == null;
      return Positioned(
        left: b.width / 2 + s.off.dx - 13, top: b.height / 2 + s.off.dy - 13,
        child: Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: g != null ? (g.isVip ? _C.gold : zc) : Colors.white,
            border: Border.all(color: isSel ? _C.gold : (isPick ? _C.green : zc.withOpacity(0.6)), width: isSel || isPick ? 2.5 : 1.5),
            boxShadow: (isSel || isPick) ? [BoxShadow(color: (isSel ? _C.gold : _C.green).withOpacity(0.5), blurRadius: 8, spreadRadius: 1)] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3)],
          ),
          child: g != null ? Text(g.initial, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)) : null,
        ),
      );
    }

    return Stack(clipBehavior: Clip.none, children: [
      // Sélection glow
      if (selected)
        Positioned(left: -14, top: -14, right: -14, bottom: -14, child: Container(
          decoration: BoxDecoration(shape: round ? BoxShape.circle : BoxShape.rectangle, borderRadius: round ? null : BorderRadius.circular(18), border: Border.all(color: _C.gold, width: 2.5), boxShadow: [BoxShadow(color: _C.gold.withOpacity(0.4), blurRadius: 18, spreadRadius: 2)]),
        )),
      // Ombre
      Positioned(left: 3, top: 3, right: -3, bottom: -3, child: Container(decoration: BoxDecoration(shape: round ? BoxShape.circle : BoxShape.rectangle, borderRadius: round ? null : BorderRadius.circular(12), color: Colors.black.withOpacity(0.08)))),
      // Table
      Center(child: Container(
        width: b.width, height: b.height,
        decoration: BoxDecoration(
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : BorderRadius.circular(12),
          gradient: const RadialGradient(colors: [Colors.white, Color(0xFFF3EEE0)]),
          border: Border.all(color: zc.withOpacity(0.85), width: 2.2),
        ),
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: zc, width: 1)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(item.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _C.ink)),
            Text('${occ.length}/${item.capacity}', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: occ.length >= item.capacity ? _C.rose : _C.ink2)),
          ]),
        )),
      )),
      // Chaises
      for (final s in seats) chair(s),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DÉCOR 2D
// ═══════════════════════════════════════════════════════════════════════════
class _Decor2D extends StatelessWidget {
  final _Item item;
  final bool selected;
  const _Decor2D({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    final b = item.body;
    final meta = _meta[item.kind]!;
    final zc = _zoneColor(item.zone);

    Color bgColor;
    Color borderColor;
    switch (item.kind) {
      case _Kind.stage: bgColor = const Color(0xFFFBF7EC); borderColor = _C.gold; break;
      case _Kind.dance: bgColor = const Color(0xFF2B2D42); borderColor = _C.purple; break;
      case _Kind.vip: bgColor = _C.gold.withOpacity(0.15); borderColor = _C.gold; break;
      case _Kind.entrance: bgColor = const Color(0xFFE11D48); borderColor = _C.rose; break;
      case _Kind.buffet: bgColor = _C.clothSide; borderColor = zc; break;
      case _Kind.bar: bgColor = const Color(0xFF3A271C); borderColor = _C.gold; break;
      case _Kind.cake: bgColor = const Color(0xFFFFF1F5); borderColor = _C.rose; break;
      case _Kind.dj: bgColor = const Color(0xFF1F2937); borderColor = _C.blue; break;
      case _Kind.plant: bgColor = const Color(0xFF15803D); borderColor = _C.green; break;
      case _Kind.photobooth: bgColor = const Color(0xFF7C2D12); borderColor = _C.gold; break;
      case _Kind.wishingTree: bgColor = const Color(0xFF16A34A); borderColor = _C.green; break;
      case _Kind.fountain: bgColor = const Color(0xFF60A5FA); borderColor = _C.blue; break;
      case _Kind.floralArch: bgColor = const Color(0xFFF472B6); borderColor = _C.rose; break;
      default: bgColor = Colors.white; borderColor = zc;
    }

    final isDark = item.kind == _Kind.dance || item.kind == _Kind.bar || item.kind == _Kind.dj || item.kind == _Kind.entrance || item.kind == _Kind.plant || item.kind == _Kind.photobooth;
    final textColor = isDark ? Colors.white : _C.ink;
    final iconColor = isDark ? Colors.white : zc;
    final isCircle = item.kind == _Kind.cake || item.kind == _Kind.plant || item.kind == _Kind.fountain || item.kind == _Kind.wishingTree;

    return Stack(clipBehavior: Clip.none, children: [
      if (selected)
        Positioned(left: -10, top: -10, right: -10, bottom: -10, child: Container(
          decoration: BoxDecoration(borderRadius: isCircle ? null : BorderRadius.circular(14), shape: isCircle ? BoxShape.circle : BoxShape.rectangle, border: Border.all(color: _C.gold, width: 2.5), boxShadow: [BoxShadow(color: _C.gold.withOpacity(0.4), blurRadius: 18, spreadRadius: 2)]),
        )),
      Center(child: Container(
        width: b.width, height: b.height,
        decoration: BoxDecoration(
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(10),
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(2, 3))],
        ),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(meta.icon, color: iconColor, size: math.min(b.width, b.height) * 0.35),
          if (math.min(b.width, b.height) > 40) ...[
            const SizedBox(height: 2),
            Text(meta.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: textColor)),
          ],
        ])),
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PETITS WIDGETS UI
// ═══════════════════════════════════════════════════════════════════════════
class _Pill extends StatelessWidget {
  final String? label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _Pill({this.label, required this.icon, this.selected = false, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AnimatedContainer(
    duration: const Duration(milliseconds: 160), padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 12, vertical: 6),
    decoration: BoxDecoration(color: selected ? _C.blue : Colors.white.withOpacity(0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? _C.blue : Colors.white.withOpacity(0.9))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: selected ? Colors.white : _C.ink2), if (label != null) ...[const SizedBox(width: 6), Text(label!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : _C.ink))]]),
  ));
}

class _Stepper extends StatelessWidget {
  final String label; final int value; final VoidCallback onMinus; final VoidCallback onPlus;
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(0.55), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 18), onPressed: onMinus),
      Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$value', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)), Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: _C.ink2))])),
      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 18), onPressed: onPlus),
    ]),
  );
}
