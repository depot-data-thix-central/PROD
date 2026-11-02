// lib/presentation/thix_weeding/pages/staff/seating/seating_3d_page.dart
// ============================================================================
// THIX WEDDING — PLAN DE SALLE (PRODUCTION v5 — VUE 2D FIXE + NAVIGATION)
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
const double _seatGap = 13;

const double _kMoveStep = 20.0;
const double _kRotateStep = 0.08;

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
  static const Color cloth = Color(0xFFFBF8F1);
  static const Color clothSide = Color(0xFFE7DFCC);
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
  'famille_marié': 'Famille du marié',
  'famille_mariée': 'Famille de la mariée',
  'amis': 'Amis',
  'collegues': 'Collègues',
};

Color _zoneColor(String z) => _zoneColors[z] ?? _zoneColors['general']!;

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES LOCAUX
// ═══════════════════════════════════════════════════════════════════════════
enum _Kind {
  tableRound,
  tableRect,
  tableSquare,
  stage,
  dance,
  buffet,
  bar,
  cake,
  dj,
  entrance,
  vip,
  plant,
  photobooth,
  wishingTree,
  fountain,
  floralArch,
}

const Map<_Kind, String> _kindKey = {
  _Kind.tableRound: 'table_round',
  _Kind.tableRect: 'table_rect',
  _Kind.tableSquare: 'table_square',
  _Kind.stage: 'stage',
  _Kind.dance: 'dance',
  _Kind.buffet: 'buffet',
  _Kind.bar: 'bar',
  _Kind.cake: 'cake',
  _Kind.dj: 'dj',
  _Kind.entrance: 'entrance',
  _Kind.vip: 'vip_zone',
  _Kind.plant: 'plant',
  _Kind.photobooth: 'photobooth',
  _Kind.wishingTree: 'wishing_tree',
  _Kind.fountain: 'fountain',
  _Kind.floralArch: 'floral_arch',
};

_Kind _kindFrom(String? k) => _kindKey.entries
    .firstWhere((e) => e.value == k,
        orElse: () => const MapEntry(_Kind.tableRound, 'table_round'))
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
  _Kind.tableRect: _KindMeta('Table rectangulaire', Icons.rectangle_outlined, 0, 0),
  _Kind.tableSquare: _KindMeta('Table carrée', Icons.crop_square, 0, 0),
  _Kind.stage: _KindMeta('Scène', Icons.theater_comedy, 360, 90),
  _Kind.dance: _KindMeta('Piste de danse', Icons.nightlife, 240, 160),
  _Kind.buffet: _KindMeta('Buffet', Icons.restaurant, 260, 50),
  _Kind.bar: _KindMeta('Bar', Icons.local_bar, 180, 44),
  _Kind.cake: _KindMeta('Gâteau', Icons.cake, 50, 50),
  _Kind.dj: _KindMeta('DJ / Sono', Icons.speaker, 130, 54),
  _Kind.entrance: _KindMeta('Entrée', Icons.door_front_door, 140, 44),
  _Kind.vip: _KindMeta('Zone VIP', Icons.star, 280, 200),
  _Kind.plant: _KindMeta('Plante', Icons.local_florist, 34, 34),
  _Kind.photobooth: _KindMeta('Photobooth', Icons.camera_alt, 160, 120),
  _Kind.wishingTree: _KindMeta('Arbre à vœux', Icons.park, 90, 90),
  _Kind.fountain: _KindMeta('Fontaine', Icons.water_drop, 110, 110),
  _Kind.floralArch: _KindMeta('Arche florale', Icons.local_florist_outlined, 180, 60),
};

class _Seat {
  final int index;
  final Offset off;
  final double phi;
  const _Seat(this.index, this.off, this.phi);
}

Offset _rot2(Offset o, double a) {
  final c = math.cos(a), s = math.sin(a);
  return Offset(o.dx * c - o.dy * s, o.dx * s + o.dy * c);
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
    required this.id,
    required this.kind,
    required this.label,
    this.tableNumber,
    this.capacity = 8,
    this.zone = 'general',
    this.x = 0.5,
    this.y = 0.5,
    this.w = 0,
    this.h = 0,
    this.rotation = 0,
    this.locked = false,
  });

  factory _Item.fromJson(Map<String, dynamic> j) => _Item(
        id: j['id'].toString(),
        kind: _kindFrom(j['kind'] as String?),
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
        'kind': _kindKey[kind],
        'label': label,
        'table_number': tableNumber,
        'capacity': capacity,
        'zone': zone,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'rotation': rotation,
        'locked': locked,
      };

  bool get isTable =>
      kind == _Kind.tableRound ||
      kind == _Kind.tableRect ||
      kind == _Kind.tableSquare;

  bool get isFlat =>
      kind == _Kind.vip || kind == _Kind.dance || kind == _Kind.entrance;

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
      ? Size(body.width + 78, body.height + 78)
      : Size(body.width + 24, body.height + 24);

  List<_Seat> get seats {
    final b = body;
    final n = capacity;
    final out = <_Seat>[];
    if (kind == _Kind.tableRound) {
      final r = b.width / 2 + _seatGap;
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        out.add(_Seat(i, Offset(math.cos(a) * r, math.sin(a) * r), a + math.pi / 2));
      }
    } else if (kind == _Kind.tableRect) {
      final top = (n + 1) ~/ 2, bot = n - top;
      var i = 0;
      for (var k = 0; k < top; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / top, -b.height / 2 - _seatGap), 0));
      }
      for (var k = 0; k < bot; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / bot, b.height / 2 + _seatGap), math.pi));
      }
    } else if (kind == _Kind.tableSquare) {
      final base = n ~/ 4, rem = n % 4;
      final top = base + (rem > 0 ? 1 : 0);
      final bot = base + (rem > 1 ? 1 : 0);
      final left = base + (rem > 2 ? 1 : 0);
      final right = base;
      var i = 0;
      for (var k = 0; k < top; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / top, -b.height / 2 - _seatGap), 0));
      }
      for (var k = 0; k < bot; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / bot, b.height / 2 + _seatGap), math.pi));
      }
      for (var k = 0; k < left; k++) {
        out.add(_Seat(i++, Offset(-b.width / 2 - _seatGap, -b.height / 2 + b.height * (k + 0.5) / left), -math.pi / 2));
      }
      for (var k = 0; k < right; k++) {
        out.add(_Seat(i++, Offset(b.width / 2 + _seatGap, -b.height / 2 + b.height * (k + 0.5) / right), math.pi / 2));
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
    required this.id,
    required this.name,
    required this.count,
    required this.isVip,
    required this.group,
    required this.active,
    required this.tableId,
    required this.seats,
  });

  factory _Guest.fromJson(Map<String, dynamic> j) => _Guest(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? '—',
        count: (j['guests_count'] as num?)?.toInt() ?? 1,
        isVip: (j['is_vip'] as bool?) ?? false,
        group: j['group_name'] as String?,
        active: (j['invitation_active'] as bool?) ?? true,
        tableId: j['hall_table_id'] as String?,
        seats: ((j['seat_indices'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  bool get placed => tableId != null && seats.isNotEmpty;
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
  String get zone => isVip ? 'vip' : (group ?? 'general');
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE
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

  // Caméra 2D
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  bool _visit = false;
  bool _snap = true;
  String? _dragId;
  Offset _dragOff = Offset.zero;
  double _zoomStart = 1;

  // Mode Fullscreen
  bool _showPanel = true;
  bool _precisionMode = false;
  bool _showGrid = false;

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
        .select(
            'id, name, guests_count, is_vip, group_name, hall_table_id, seat_indices, invitation_active')
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
      for (final s in g.seats) {
        m[s] = g;
      }
    }
    return m;
  }

  List<int> _freeSeats(_Item t, {String? exclude}) {
    final occ = _occupancy(t.id, exclude: exclude);
    return [for (var i = 0; i < t.capacity; i++) if (!occ.containsKey(i)) i];
  }

  int get _totalSeats =>
      _items.where((i) => i.isTable).fold(0, (s, i) => s + i.capacity);
  int get _seatedPersons => _guests
      .where((g) => g.active && g.placed)
      .fold(0, (s, g) => s + g.count);
  int get _totalPersons =>
      _guests.where((g) => g.active).fold(0, (s, g) => s + g.count);

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

  // ───────────────────────── CAMÉRA & NAVIGATION ─────────────────────────
  void _panBy(double dx, double dy) {
    setState(() => _pan += Offset(dx, dy));
  }

  void _zoomBy(double f) => setState(() => _zoom = (_zoom * f).clamp(0.4, 2.5).toDouble());

  void _resetView() {
    setState(() {
      _zoom = 1.0;
      _pan = Offset.zero;
    });
  }

  void _focusSelected() {
    final sel = _selected;
    if (sel == null) return;
    setState(() {
      _zoom = 1.4;
      // Centrer grossièrement sur l'élément
      _pan = Offset((_roomW/2) - sel.c.dx, (_roomH/2) - sel.c.dy) * 0.8;
    });
    _toast('Centré sur ${sel.label}');
  }

  void _camStart(ScaleStartDetails d) {
    _zoomStart = _zoom;
  }

  void _camUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        _zoom = (_zoomStart * d.scale).clamp(0.4, 2.5).toDouble();
      }
      _pan += d.focalPointDelta;
    });
  }

  // ───────────────────────── HIT-TEST (2D) ─────────────────────────
  bool _contains(_Item it, Offset p) {
    final d = p - it.c;
    final l = _rot2(d, -it.rotation);
    final b = it.body;
    if (it.kind == _Kind.tableRound) return d.distance <= b.width / 2 + 10;
    return l.dx.abs() <= b.width / 2 + 10 && l.dy.abs() <= b.height / 2 + 10;
  }

  _Item? _hitItem(Offset p) {
    _Item? best;
    var bestRank = -1;
    for (final it in _items) {
      if (!_contains(it, p)) continue;
      final rank = it.isTable ? 2 : (it.isFlat ? 0 : 1);
      if (rank >= bestRank) {
        best = it;
        bestRank = rank;
      }
    }
    return best;
  }

  (_Item, int)? _hitSeat(Offset p) {
    for (final it in _items.where((i) => i.isTable)) {
      for (final s in it.seats) {
        final pos = it.c + _rot2(s.off, it.rotation);
        if ((pos - p).distance < 18) return (it, s.index);
      }
    }
    return null;
  }

  void _onTap(Offset p) {
    final hs = _hitSeat(p);
    if (hs != null) {
      _onSeatTap(hs.$1, hs.$2);
      return;
    }
    _select(_hitItem(p)?.id);
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

  // ───────────────────────── GESTES ÉDITION ─────────────────────────
  void _editStart(ScaleStartDetails d) {
    _zoomStart = _zoom;
    _dragId = null;
    if (d.pointerCount >= 2) return;
    final it = _hitItem(d.localFocalPoint);
    if (it != null && !it.locked) {
      _dragId = it.id;
      _dragOff = it.c - d.localFocalPoint;
      if (_selId != it.id) _select(it.id);
      setState(() => _showGrid = _snap);
    }
  }

  void _editUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      _dragId = null;
      setState(() => _zoom = (_zoomStart * d.scale).clamp(0.4, 2.5).toDouble());
      return;
    }
    final it = _itemById(_dragId);
    if (it == null) return;
    var p = d.localFocalPoint + _dragOff;
    if (_snap) {
      p = Offset((p.dx / 10).round() * 10.0, (p.dy / 10).round() * 10.0);
    }
    setState(() {
      it.x = (p.dx / _roomW).clamp(0.03, 0.97).toDouble();
      it.y = (p.dy / _roomH).clamp(0.05, 0.95).toDouble();
    });
  }

  void _editEnd(ScaleEndDetails d) {
    final id = _dragId;
    _dragId = null;
    setState(() => _showGrid = false);
    if (id != null) _markDirty(id);
  }

  // ───────────────────────── MOUVEMENTS ─────────────────────────
  void _moveSelectedBy(double dx, double dy) {
    final sel = _selected;
    if (sel == null || sel.locked) return;
    final step = _precisionMode ? 5.0 : _kMoveStep;
    final nx = sel.x * _roomW + dx * step;
    final ny = sel.y * _roomH + dy * step;
    setState(() {
      sel.x = (nx / _roomW).clamp(0.03, 0.97).toDouble();
      sel.y = (ny / _roomH).clamp(0.05, 0.95).toDouble();
    });
    HapticFeedback.lightImpact();
    _markDirty(sel.id);
  }

  void _rotateSelectedBy(double delta) {
    final sel = _selected;
    if (sel == null || sel.locked) return;
    setState(() {
      sel.rotation += delta;
    });
    HapticFeedback.lightImpact();
    _markDirty(sel.id);
  }

  void _duplicateSelected() {
    final sel = _selected;
    if (sel == null) return;
    _duplicate(sel);
  }

  // ───────────────────────── ÉLÉMENTS ─────────────────────────
  Future<void> _addItem(_Kind kind) async {
    final isTable = kind == _Kind.tableRound ||
        kind == _Kind.tableRect ||
        kind == _Kind.tableSquare;
    final nums = _items.where((i) => i.isTable).map((e) => e.tableNumber ?? 0);
    final n = nums.isEmpty ? 1 : nums.reduce(math.max) + 1;
    final row = {
      'wedding_id': widget.weddingId,
      'kind': _kindKey[kind],
      'label': isTable ? 'Table $n' : _meta[kind]!.label,
      'table_number': isTable ? n : null,
      'capacity': isTable ? (kind == _Kind.tableSquare ? 4 : 8) : 0,
      'zone': 'general',
      'x': 0.5 + ((_items.length % 5) - 2) * 0.09,
      'y': 0.5 + (((_items.length ~/ 5) % 3) - 1) * 0.14,
      'w': 0,
      'h': 0,
      'rotation': 0,
      'order_index': _items.length,
    };
    try {
      final res = await _supa
          .from('thix_weeding_hall_items')
          .insert(row)
          .select()
          .single();
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
      ..['x'] = (it.x + 0.07).clamp(0.03, 0.97).toDouble()
      ..['y'] = (it.y + 0.07).clamp(0.05, 0.95).toDouble()
      ..['order_index'] = _items.length;
    if (it.isTable) {
      row['table_number'] = n;
      row['label'] = 'Table $n';
    }
    try {
      final res = await _supa
          .from('thix_weeding_hall_items')
          .insert(row)
          .select()
          .single();
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.rose),
            onPressed: () => Navigator.pop(context, true),
            child: Text(ok),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _deleteItem(_Item it) async {
    final ok = await _confirm('Supprimer « ${it.label} » ?',
        it.isTable ? 'Les invités placés sur cette table seront libérés.' : 'Cet élément sera retiré de la salle.', 'Supprimer');
    if (!ok) return;
    try {
      if (it.isTable) {
        await _supa.from('thix_weeding_guests').update({
          'hall_table_id': null,
          'seat_indices': <int>[],
          'table_number': null,
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

  // ───────────────────────── PLACEMENT ─────────────────────────
  Future<bool> _assignSeats(_Guest g, _Item t, List<int> seats,
      {bool quiet = false}) async {
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': t.id,
        'seat_indices': seats,
        'table_number': t.tableNumber,
      }).eq('id', g.id);
      g.tableId = t.id;
      g.seats = seats;
      if (mounted) {
        setState(() {
          if (_assigning?.id == g.id) _assigning = null;
        });
      }
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
    return [
      ...tables.where((t) => t.zone == g.zone),
      ...tables.where((t) => t.zone != g.zone),
    ];
  }

  Future<bool> _autoOne(_Guest g, {_Item? table, bool quiet = false}) async {
    final cands = table != null ? [table] : _bestTables(g);
    for (final t in cands) {
      final free = _freeSeats(t, exclude: g.id);
      if (free.length >= g.count) {
        return _assignSeats(g, t, free.take(g.count).toList(), quiet: quiet);
      }
    }
    if (!quiet) _toast('Aucune table n\'a assez de places libres', error: true);
    return false;
  }

  Future<void> _autoPlaceAll() async {
    final pending = _guests.where((g) => g.active && !g.placed).toList()
      ..sort((a, b) => (b.isVip ? 1 : 0).compareTo(a.isVip ? 1 : 0));
    if (pending.isEmpty) {
      _toast('Tous les invités sont déjà placés');
      return;
    }
    var ok = 0;
    for (final g in pending) {
      if (await _autoOne(g, quiet: true)) ok++;
    }
    HapticFeedback.heavyImpact();
    _toast('$ok/${pending.length} invité(s) placé(s) automatiquement',
        error: ok < pending.length);
  }

  Future<void> _unplace(_Guest g) async {
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': null,
        'seat_indices': <int>[],
        'table_number': null,
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
    final ok = await _confirm('Tout libérer ?',
        'Tous les invités seront retirés de leurs chaises (les invitations restent valides).', 'Libérer');
    if (!ok) return;
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': null,
        'seat_indices': <int>[],
        'table_number': null,
      }).eq('wedding_id', widget.weddingId).not('hall_table_id', 'is', null);
      await _reloadGuests();
      ref.invalidate(guestsProvider(widget.weddingId));
      _toast('Toutes les places sont libres');
    } catch (e) {
      _toast('Erreur : $e', error: true);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD FULLSCREEN
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B1F3B),
        body: Center(child: CircularProgressIndicator(color: _C.gold)),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = MediaQuery.of(context).size.height * 0.40;

    return Scaffold(
      backgroundColor: const Color(0xFF1B1F3B),
      body: Stack(
        children: [
          // 1. LA VUE 2D
          Positioned.fill(child: _viewport()),

          // 2. LA BARRE D'OUTILS
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _toolbar(),
              ),
            ),
          ),

          // 3. BOUTONS DE NAVIGATION GAUCHE / DROITE
          Positioned(
            left: 8,
            top: MediaQuery.of(context).size.height / 2 - 40,
            child: FloatingActionButton(
              heroTag: 'nav_left',
              backgroundColor: Colors.black.withOpacity(0.6),
              onPressed: () => _panBy(150, 0),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          Positioned(
            right: 8,
            top: MediaQuery.of(context).size.height / 2 - 40,
            child: FloatingActionButton(
              heroTag: 'nav_right',
              backgroundColor: Colors.black.withOpacity(0.6),
              onPressed: () => _panBy(-150, 0),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
            ),
          ),

          // 4. BOUTON PANNEAU
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 12,
            child: FloatingActionButton.small(
              backgroundColor: _showPanel ? _C.rose : _C.blue,
              onPressed: () => setState(() => _showPanel = !_showPanel),
              child: Icon(_showPanel ? Icons.close : Icons.tune, color: Colors.white),
            ),
          ),

          // 5. PANNEAU DE CONFIGURATION
          if (_showPanel)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + bottomInset,
              height: panelHeight,
              child: ThixGlass(
                radius: 24,
                padding: EdgeInsets.zero,
                child: _selected == null ? _guestsPanel() : _itemPanel(_selected!),
              ),
            ),

          // 6. JOYSTICK DE DÉPLACEMENT
          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: _showPanel ? panelHeight + 24 + bottomInset : 12 + bottomInset,
              child: _SelectionJoystick(
                item: _selected!,
                precision: _precisionMode,
                onPrecisionToggle: () => setState(() => _precisionMode = !_precisionMode),
                onMove: _moveSelectedBy,
                onRotate: _rotateSelectedBy,
                onFocus: _focusSelected,
                onDuplicate: _duplicateSelected,
                onDeselect: () => _select(null),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── TOOLBAR (HUD Sombre) ─────────────────────────
  Widget _toolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 4),
          _Pill(
            label: 'Éditer',
            icon: Icons.open_with_rounded,
            selected: !_visit,
            onTap: () => setState(() => _visit = false),
          ),
          const SizedBox(width: 4),
          _Pill(
            label: 'Visiter',
            icon: Icons.explore_outlined,
            selected: _visit,
            onTap: () => setState(() => _visit = true),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.zoom_in, color: Colors.white70, size: 22),
            onPressed: () => _zoomBy(1.2),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.zoom_out, color: Colors.white70, size: 22),
            onPressed: () => _zoomBy(0.8),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.center_focus_strong, color: Colors.white70, size: 22),
            onPressed: _resetView,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, color: _C.gold, size: 24),
            onPressed: _openAddSheet,
          ),
        ],
      ),
    );
  }

  // ───────────────────────── VIEWPORT 2D FIXE ─────────────────────────
  Widget _viewport() {
    return LayoutBuilder(builder: (context, c) {
      final fit = math.min(c.maxWidth / _roomW, c.maxHeight / _roomH) * 0.9;
      final s = fit * _zoom;
      
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: _visit ? _camStart : null,
        onScaleUpdate: _visit ? _camUpdate : null,
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF1B1F3B)),
          child: ClipRRect(
            child: Stack(
              children: [
                // Fond
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2E2A52), Color(0xFF1B1F3B)],
                      ),
                    ),
                  ),
                ),
                // Plan 2D (sans rotation 3D)
                Positioned.fill(
                  child: OverflowBox(
                    minWidth: _roomW,
                    maxWidth: _roomW,
                    minHeight: _roomH,
                    maxHeight: _roomH,
                    child: Transform.translate(
                      offset: _pan,
                      child: Transform.scale(
                        scale: s,
                        child: _room(),
                      ),
                    ),
                  ),
                ),
                // Bannière
                if (_assigning != null)
                  Positioned(
                    top: 90,
                    left: 10,
                    right: 60,
                    child: ThixGlass(
                      radius: 16,
                      blur: 14,
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      tint: const Color(0xFFFFF3C4),
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat_rounded, size: 18, color: _C.goldDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Placer ${_assigning!.name} (${_assigning!.count} pers.) — touchez une chaise',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _assigning = null),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Stats
                Positioned(
                  left: 10,
                  bottom: _showPanel ? 16 : 80,
                  child: ThixGlass(
                    radius: 14,
                    blur: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_seatedPersons/$_totalPersons placés · $_totalSeats chaises',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: _C.ink),
                        ),
                        Text(
                          _visit ? 'Glissez pour déplacer' : 'Glissez un élément • pincez pour zoomer',
                          style: GoogleFonts.inter(fontSize: 9.5, color: _C.ink2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _room() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.localPosition),
      onScaleStart: _visit ? null : _editStart,
      onScaleUpdate: _visit ? null : _editUpdate,
      onScaleEnd: _visit ? null : _editEnd,
      child: Container(
        width: _roomW,
        height: _roomH,
        decoration: BoxDecoration(
          color: const Color(0xFFF5E6C4), // Sol de la salle
          border: Border.all(color: _C.gold, width: 8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_showGrid)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GridPainter()),
                ),
              ),
            for (final it in _items) _placed(it),
          ],
        ),
      ),
    );
  }

  Widget _placed(_Item it) {
    final e = it.extent;
    final c = it.c;
    final sel = it.id == _selId;
    return Positioned(
      left: c.dx - e.width / 2,
      top: c.dy - e.height / 2,
      width: e.width,
      height: e.height,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: it.rotation,
          child: it.isTable
              ? _TableView(
                  item: it,
                  occ: _occupancy(it.id),
                  selected: sel,
                  selSeat: sel ? _selSeat : null,
                  assigning: _assigning != null,
                )
              : _DecorView(
                  item: it,
                  selected: sel,
                ),
        ),
      ),
    );
  }

  // ───────────────────────── PANNEAU INVITÉS ─────────────────────────
  Widget _guestsPanel() {
    final q = _query.toLowerCase();
    final list = _guests
        .where((g) =>
            g.active &&
            (_showPlaced ? g.placed : !g.placed) &&
            (q.isEmpty || g.name.toLowerCase().contains(q)))
        .toList();
    final unplacedCount = _guests.where((g) => g.active && !g.placed).length;
    final ratio = _totalPersons == 0 ? 0.0 : _seatedPersons / _totalPersons;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Invités',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _C.ink)),
                  const Spacer(),
                  Text('${(ratio * 100).round()}% placés',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _C.green)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.6),
                  valueColor: const AlwaysStoppedAnimation(_C.green),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Rechercher un invité',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    label: 'À placer ($unplacedCount)',
                    icon: Icons.person_outline,
                    selected: !_showPlaced,
                    onTap: () => setState(() => _showPlaced = false),
                  ),
                  const SizedBox(width: 4),
                  _Pill(
                    icon: Icons.event_seat_rounded,
                    selected: _showPlaced,
                    onTap: () => setState(() => _showPlaced = true),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    _showPlaced ? 'Personne n\'est encore placé' : 'Tous les invités sont placés ✨',
                    style: GoogleFonts.inter(color: _C.ink2, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _guestTile(list[i]),
                ),
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
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _zoneColor(g.zone).withOpacity(0.2),
              child: g.isVip
                  ? const Icon(Icons.star, size: 15, color: _C.gold)
                  : Text(g.initial, style: TextStyle(color: _zoneColor(g.zone), fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _C.ink)),
                  Text(sub, style: GoogleFonts.inter(fontSize: 10.5, color: _C.ink2)),
                ],
              ),
            ),
            if (g.placed)
              IconButton(
                tooltip: 'Libérer la place',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.link_off_rounded, size: 19, color: _C.rose),
                onPressed: () => _unplace(g),
              )
            else ...[
              IconButton(
                tooltip: table != null ? 'Placer sur ${table.label}' : 'Placement automatique',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 19, color: _C.blue),
                onPressed: () => _autoOne(g, table: table),
              ),
              IconButton(
                tooltip: 'Choisir la chaise',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.event_seat_rounded, size: 19, color: _C.goldDark),
                onPressed: () {
                  setState(() {
                    _assigning = g;
                    _visit = false;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────── PANNEAU ÉLÉMENT ─────────────────────────
  Widget _itemPanel(_Item it) {
    final meta = _meta[it.kind]!;
    final zc = _zoneColor(it.zone);
    final occ = it.isTable ? _occupancy(it.id) : <int, _Guest>{};
    final seated = it.isTable
        ? _guests.where((g) => g.active && g.tableId == it.id).toList()
        : <_Guest>[];
    final unplaced = _guests.where((g) => g.active && !g.placed).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [zc, zc.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _labelCtrl,
                onChanged: (v) {
                  it.label = v;
                  _markDirty(it.id);
                  setState(() {});
                },
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: _C.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Nom',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _select(null),
            ),
          ],
        ),
        if (it.isTable) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Stepper(
                  label: 'Chaises',
                  value: it.capacity,
                  onMinus: () {
                    final maxUsed = occ.keys.isEmpty ? -1 : occ.keys.reduce(math.max);
                    if (it.capacity - 1 <= maxUsed) {
                      _toast('Libérez d\'abord la place ${maxUsed + 1}', error: true);
                      return;
                    }
                    if (it.capacity > 2) {
                      setState(() => it.capacity--);
                      _markDirty(it.id);
                    }
                  },
                  onPlus: () {
                    final cap = it.kind == _Kind.tableSquare ? 8 : 20;
                    if (it.capacity < cap) {
                      setState(() => it.capacity++);
                      _markDirty(it.id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stepper(
                  label: 'N° table',
                  value: it.tableNumber ?? 0,
                  onMinus: () {
                    if ((it.tableNumber ?? 1) > 1) {
                      setState(() => it.tableNumber = (it.tableNumber ?? 1) - 1);
                      _markDirty(it.id);
                    }
                  },
                  onPlus: () {
                    setState(() => it.tableNumber = (it.tableNumber ?? 0) + 1);
                    _markDirty(it.id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: _zoneLabels.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 11)),
                      selected: it.zone == e.key,
                      selectedColor: _zoneColor(e.key).withOpacity(0.25),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        setState(() => it.zone = e.key);
                        _markDirty(it.id);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [_Kind.tableRound, _Kind.tableRect, _Kind.tableSquare]
                .map((k) => ChoiceChip(
                      label: Text(_meta[k]!.label, style: const TextStyle(fontSize: 11)),
                      avatar: Icon(_meta[k]!.icon, size: 14),
                      selected: it.kind == k,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        if (k == _Kind.tableSquare && it.capacity > 8) {
                          _toast('Une table carrée a 8 chaises maximum', error: true);
                          return;
                        }
                        setState(() => it.kind = k);
                        _markDirty(it.id);
                      },
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _duplicate(it),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Dupliquer'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => it.locked = !it.locked);
                  _markDirty(it.id);
                },
                icon: Icon(it.locked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16),
                label: Text(it.locked ? 'Verrouillé' : 'Verrouiller'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: _C.rose),
              onPressed: () => _deleteItem(it),
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
          ],
        ),
        if (it.isTable) ...[
          const SizedBox(height: 14),
          Text('À cette table (${occ.length}/${it.capacity} chaises)',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: _C.ink)),
          const SizedBox(height: 6),
          if (seated.isEmpty)
            Text('Personne pour l\'instant', style: GoogleFonts.inter(fontSize: 12, color: _C.ink2))
          else
            ...seated.map((g) => Padding(padding: const EdgeInsets.only(bottom: 6), child: _guestTile(g))),
          const SizedBox(height: 12),
          Text('Placer un invité ici',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: _C.ink)),
          const SizedBox(height: 6),
          if (unplaced.isEmpty)
            Text('Aucun invité libre', style: GoogleFonts.inter(fontSize: 12, color: _C.ink2))
          else
            ...unplaced.map((g) => Padding(padding: const EdgeInsets.only(bottom: 6), child: _guestTile(g, table: it))),
        ],
      ],
    );
  }

  // ───────────────────────── SHEETS ─────────────────────────
  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: ThixGlass(
          radius: 26,
          opacity: 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajouter à la salle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _Kind.values.map((k) {
                  final m = _meta[k]!;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _addItem(k);
                    },
                    child: Container(
                      width: 96,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        children: [
                          Icon(m.icon, color: _C.blue, size: 24),
                          const SizedBox(height: 6),
                          Text(m.label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// JOYSTICK (Dark Mode HUD)
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
    required this.item,
    required this.precision,
    required this.onPrecisionToggle,
    required this.onMove,
    required this.onRotate,
    required this.onFocus,
    required this.onDuplicate,
    required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.gold, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '✦ ${item.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  precision ? 'Précis (5 px)' : 'Normal (20 px)',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
          _DPad(onMove: onMove),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _JoyButton(icon: Icons.rotate_left_rounded, onTap: () => onRotate(-_kRotateStep), color: _C.blue),
                  const SizedBox(width: 4),
                  _JoyButton(icon: Icons.rotate_right_rounded, onTap: () => onRotate(_kRotateStep), color: _C.blue),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _JoyButton(icon: Icons.center_focus_strong_rounded, tooltip: 'Centrer', onTap: onFocus, color: _C.gold),
                  const SizedBox(width: 4),
                  _JoyButton(icon: Icons.precision_manufacturing_rounded, tooltip: 'Précis', onTap: onPrecisionToggle, color: precision ? _C.green : Colors.white54, filled: precision),
                  const SizedBox(width: 4),
                  _JoyButton(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: onDeselect, color: _C.rose),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  final void Function(double dx, double dy) onMove;
  const _DPad({required this.onMove});

  @override
  Widget build(BuildContext context) {
    const sz = 34.0;
    return SizedBox(
      width: sz * 3 + 6,
      height: sz * 3 + 6,
      child: Stack(
        children: [
          Positioned(left: sz + 3, top: 0, child: _DPadButton(icon: Icons.arrow_upward_rounded, onTap: () => onMove(0, -1))),
          Positioned(left: sz + 3, bottom: 0, child: _DPadButton(icon: Icons.arrow_downward_rounded, onTap: () => onMove(0, 1))),
          Positioned(left: 0, top: sz + 3, child: _DPadButton(icon: Icons.arrow_back_rounded, onTap: () => onMove(-1, 0))),
          Positioned(right: 0, top: sz + 3, child: _DPadButton(icon: Icons.arrow_forward_rounded, onTap: () => onMove(1, 0))),
          Positioned(
            left: sz + 3,
            top: sz + 3,
            child: Container(
              width: sz,
              height: sz,
              decoration: BoxDecoration(
                color: _C.gold.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: _C.gold, width: 1.2),
              ),
              child: const Icon(Icons.open_with_rounded, size: 14, color: _C.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _DPadButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DPadButton({required this.icon, required this.onTap});

  @override
  State<_DPadButton> createState() => _DPadButtonState();
}

class _DPadButtonState extends State<_DPadButton> {
  Timer? _repeatTimer;

  void _start() {
    widget.onTap();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) => widget.onTap());
  }

  void _stop() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(widget.icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _JoyButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final Color color;
  final bool filled;
  const _JoyButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.tooltip,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(filled ? 1 : 0.5), width: 1),
        ),
        child: Icon(icon, size: 16, color: filled ? Colors.white : color),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRILLE MAGNÉTIQUE
// ═══════════════════════════════════════════════════════════════════════════
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.gold.withOpacity(0.18)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const step = 40.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// PETITS WIDGETS UI
// ═══════════════════════════════════════════════════════════════════════════
class _Pill extends StatelessWidget {
  final String? label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({this.label, required this.icon, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _C.blue : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _C.blue : Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.white70),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 18), onPressed: onMinus),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$value', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: _C.ink2)),
              ],
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 18), onPressed: onPlus),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TABLE 2D
// ═══════════════════════════════════════════════════════════════════════════
class _TableView extends StatelessWidget {
  final _Item item;
  final Map<int, _Guest> occ;
  final bool selected;
  final int? selSeat;
  final bool assigning;

  const _TableView({
    required this.item,
    required this.occ,
    required this.selected,
    required this.selSeat,
    required this.assigning,
  });

  @override
  Widget build(BuildContext context) {
    final b = item.body;
    final round = item.kind == _Kind.tableRound;
    final zc = _zoneColor(item.zone);
    final seats = item.seats;

    BoxDecoration shape({Gradient? gradient, Color? color, Border? border}) => BoxDecoration(
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : BorderRadius.circular(12),
          gradient: gradient,
          color: color,
          border: border,
        );

    final topSurface = SizedBox(
      width: b.width,
      height: b.height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: shape(
              color: Colors.white,
              border: Border.all(color: zc.withOpacity(0.85), width: 2.2),
            ),
          ),
          Container(
            width: b.width * 0.62,
            height: b.height * 0.62,
            decoration: BoxDecoration(
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(8),
              color: zc.withOpacity(0.14),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.max(34, b.shortestSide * 0.62)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: zc, width: 1.3),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4)],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.label,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _C.ink)),
                    Text('${occ.length}/${item.capacity}',
                        style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: occ.length >= item.capacity ? _C.rose : _C.ink2)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (selected)
          Container(
            width: b.width + 24,
            height: b.height + 24,
            decoration: BoxDecoration(
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(18),
              border: Border.all(color: _C.gold, width: 2.5),
              boxShadow: [BoxShadow(color: _C.gold.withOpacity(0.5), blurRadius: 22, spreadRadius: 2)],
            ),
          ),
        Container(
          width: b.width + 6,
          height: b.height + 6,
          decoration: BoxDecoration(
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(4, 6))],
          ),
        ),
        // La table
        topSurface,
        // Les chaises
        for (final s in seats)
          Transform.translate(
            offset: s.off,
            child: _ChairView(
              occupied: occ[s.index] != null,
              initial: occ[s.index]?.initial ?? '',
              color: occ[s.index] == null ? zc : (occ[s.index]!.isVip ? _C.gold : zc),
              selected: selSeat == s.index,
              pick: assigning && occ[s.index] == null,
            ),
          ),
      ],
    );
  }
}

class _ChairView extends StatelessWidget {
  final bool occupied, selected, pick;
  final String initial;
  final Color color;

  const _ChairView({
    required this.occupied,
    required this.selected,
    required this.pick,
    required this.initial,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final seatColor = occupied ? color : const Color(0xFFFBF8EF);
    final glow = selected ? _C.gold : (pick ? _C.green : null);
    
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(2, 2))],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: seatColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : (pick ? _C.green : (occupied ? Colors.white : _C.gold)),
                width: selected || pick ? 2.5 : 1.5,
              ),
              boxShadow: glow == null ? null : [BoxShadow(color: glow.withOpacity(0.7), blurRadius: 10, spreadRadius: 1)],
            ),
            child: occupied
                ? Text(initial, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))
                : null,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DÉCORS 2D
// ═══════════════════════════════════════════════════════════════════════════
class _DecorView extends StatelessWidget {
  final _Item item;
  final bool selected;

  const _DecorView({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final b = item.body;
    
    Widget content;
    switch (item.kind) {
      case _Kind.stage:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1B2A57),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.gold, width: 3),
          ),
          child: Text('SCÈNE', style: GoogleFonts.cinzel(fontSize: 16, color: _C.gold, letterSpacing: 5, fontWeight: FontWeight.w700)),
        );
        break;
      case _Kind.dance:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2D42),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.purple, width: 2),
          ),
          child: Text('PISTE DE DANSE', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, letterSpacing: 2)),
        );
        break;
      case _Kind.vip:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _C.gold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.gold, width: 2),
          ),
          child: Text('ZONE VIP', style: GoogleFonts.inter(fontSize: 12, color: _C.goldDark, letterSpacing: 3)),
        );
        break;
      case _Kind.entrance:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.gold, width: 2),
          ),
          child: Text('ENTRÉE', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, letterSpacing: 2)),
        );
        break;
      case _Kind.buffet:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _C.cloth,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.gold, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Icon(Icons.restaurant, color: _C.goldDark, size: 18),
              Text('BUFFET', style: GoogleFonts.inter(fontSize: 10, color: _C.ink, fontWeight: FontWeight.bold)),
            ],
          ),
        );
        break;
      case _Kind.bar:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF6B4A33),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.gold, width: 1.5),
          ),
          child: Text('BAR', style: GoogleFonts.inter(fontSize: 11, color: _C.gold, fontWeight: FontWeight.bold, letterSpacing: 2)),
        );
        break;
      case _Kind.dj:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.rose, width: 2),
          ),
          child: const Icon(Icons.speaker, color: _C.gold, size: 28),
        );
        break;
      case _Kind.cake:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F5),
            shape: BoxShape.circle,
            border: Border.all(color: _C.rose, width: 2),
          ),
          child: const Icon(Icons.cake, color: _C.rose, size: 24),
        );
        break;
      case _Kind.plant:
        content = Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_florist, color: Colors.white, size: 18),
        );
        break;
      default:
        content = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_meta[item.kind]!.icon, color: Colors.black54),
        );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (selected)
          Container(
            width: b.width + 16,
            height: b.height + 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.gold, width: 2.5),
              boxShadow: [BoxShadow(color: _C.gold.withOpacity(0.5), blurRadius: 22, spreadRadius: 2)],
            ),
          ),
        Container(
          width: b.width,
          height: b.height,
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(3, 5))],
          ),
          child: content,
        ),
      ],
    );
  }
}
