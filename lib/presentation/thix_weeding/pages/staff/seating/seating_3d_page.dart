// lib/presentation/thix_weeding/pages/staff/seating/seating_3d_page.dart
// ============================================================================
// THIX WEDDING — PLAN DE SALLE 3D STAFF (PRODUCTION v3)
// ✅ Vue PLEIN ÉCRAN verticale, caméra stable (aucun mouvement automatique)
// ✅ Boutons répartis sur les deux côtés : gauche = VUE, droite = OUTILS
// ✅ Curseurs X / Y / rotation pour chaque objet (+ boutons de réglage fin)
// ✅ Glisser un objet, glisser le fond = déplacer la vue, pincer = zoom
// ✅ Ranger en grille, placement auto, invités, verre dépoli
// ============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/hall_3d_core.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

typedef _CamState = ({double t, double r, double z, Offset p});

class Seating3dPage extends ConsumerStatefulWidget {
  final String weddingId;
  const Seating3dPage({super.key, required this.weddingId});

  @override
  ConsumerState<Seating3dPage> createState() => _Seating3dPageState();
}

class _Seating3dPageState extends ConsumerState<Seating3dPage>
    with SingleTickerProviderStateMixin {
  final _supa = Supabase.instance.client;
  final _labelCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  late final AnimationController _camCtrl;
  RealtimeChannel? _channel;
  Timer? _flushTimer;
  final Set<String> _dirty = {};

  List<HallItem> _items = [];
  List<HallGuest> _guests = [];
  bool _loaded = false;
  String? _selId;
  int? _selSeat;
  HallGuest? _assigning;
  bool _showPlaced = false;
  String _query = '';

  final HallCamera _cam = HallCamera();
  _CamState _camA = (t: 0.62, r: 0.0, z: 1.0, p: kDefaultPan);
  _CamState _camB = (t: 0.62, r: 0.0, z: 1.0, p: kDefaultPan);

  double _ambient = 0.9;
  bool _evening = false, _wall = true, _snap = true, _hq = true;
  bool _lockObjects = false, _moreOpen = false;

  double _zoomStart = 1;
  String? _dragId;
  Offset _dragOff = Offset.zero;
  Size _vp = Size.zero;

  @override
  void initState() {
    super.initState();
    _camCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
      ..addListener(_camTick);
    _bootstrap();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _flush();
    if (_channel != null) _supa.removeChannel(_channel!);
    _camCtrl.dispose();
    _labelCtrl.dispose();
    _searchCtrl.dispose();
    _tick.dispose();
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
          .map((e) => HallItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final lay = await _supa
          .from('thix_weeding_hall_layout')
          .select()
          .eq('wedding_id', widget.weddingId)
          .maybeSingle();
      if (lay != null) {
        _ambient = (lay['ambient_light'] as num?)?.toDouble() ?? _ambient;
        _wall = (lay['show_wall'] as bool?) ?? true;
        _evening = (lay['evening'] as bool?) ?? false;
      }
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
        .map((e) => HallGuest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _reloadGuests() async {
    try {
      await _fetchGuests();
      _touch();
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

  void _touch() {
    if (mounted) setState(() {});
    _tick.value++;
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

  Future<void> _saveLayout() async {
    try {
      await _supa.from('thix_weeding_hall_layout').upsert({
        'wedding_id': widget.weddingId,
        'ambient_light': _ambient,
        'show_wall': _wall,
        'evening': _evening,
      }, onConflict: 'wedding_id');
    } catch (e) {
      _toast('Réglages : $e', error: true);
    }
  }

  // ───────────────────────── HELPERS ─────────────────────────
  HallItem? _itemById(String? id) {
    if (id == null) return null;
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  HallItem? get _selected => _itemById(_selId);

  Map<int, HallGuest> _occupancy(String tableId, {String? exclude}) {
    final m = <int, HallGuest>{};
    for (final g in _guests) {
      if (!g.active || g.tableId != tableId || g.id == exclude) continue;
      for (final s in g.seats) {
        m[s] = g;
      }
    }
    return m;
  }

  Map<String, Map<int, HallGuest>> _occAll() => {
        for (final t in _items.where((i) => i.isTable)) t.id: _occupancy(t.id),
      };

  List<int> _freeSeats(HallItem t, {String? exclude}) {
    final occ = _occupancy(t.id, exclude: exclude);
    return [for (var i = 0; i < t.capacity; i++) if (!occ.containsKey(i)) i];
  }

  int get _totalSeats => _items.where((i) => i.isTable).fold(0, (s, i) => s + i.capacity);
  int get _seatedPersons =>
      _guests.where((g) => g.active && g.placed).fold(0, (s, g) => s + g.count);
  int get _totalPersons => _guests.where((g) => g.active).fold(0, (s, g) => s + g.count);
  int get _unplacedCount => _guests.where((g) => g.active && !g.placed).length;

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: error ? HallC.rose : HallC.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 90),
      ));
  }

  void _select(String? id) {
    setState(() {
      _selId = id;
      _selSeat = null;
      if (id == null) _moreOpen = false;
    });
    _labelCtrl.text = _itemById(id)?.label ?? '';
  }

  // ───────────────────────── CAMÉRA (par pas, stable) ─────────────────────────
  void _camTick() {
    final k = Curves.easeInOut.transform(_camCtrl.value);
    setState(() {
      _cam.tilt = _camA.t + (_camB.t - _camA.t) * k;
      _cam.rot = _camA.r + (_camB.r - _camA.r) * k;
      _cam.zoom = _camA.z + (_camB.z - _camA.z) * k;
      _cam.pan = Offset.lerp(_camA.p, _camB.p, k) ?? _camB.p;
    });
  }

  void _goTo({double? tilt, double? rot, double? zoom, Offset? pan}) {
    _camA = (t: _cam.tilt, r: _cam.rot, z: _cam.zoom, p: _cam.pan);
    _camB = (
      t: (tilt ?? _cam.tilt).clamp(0.0, 1.1).toDouble(),
      r: rot ?? _cam.rot,
      z: (zoom ?? _cam.zoom).clamp(0.6, 3.0).toDouble(),
      p: pan ?? _cam.pan,
    );
    _camCtrl.forward(from: 0);
  }

  void _clampPan() {
    final lim = 420.0 * _cam.zoom;
    _cam.pan = Offset(
      _cam.pan.dx.clamp(-lim, lim).toDouble(),
      _cam.pan.dy.clamp(-lim, lim).toDouble(),
    );
  }

  // ───────────────────────── GESTES ─────────────────────────
  void _onTapUp(TapUpDetails d) {
    final p = _cam.toRoom(d.localPosition, _vp);
    if (p == null) return;
    final hs = HallGeo.hitSeat(_items, p);
    if (hs != null) {
      _onSeatTap(hs.$1, hs.$2);
      return;
    }
    _select(HallGeo.hitItem(_items, p)?.id);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _zoomStart = _cam.zoom;
    _dragId = null;
    if (d.pointerCount >= 2 || _lockObjects) return;
    final p = _cam.toRoom(d.localFocalPoint, _vp);
    if (p == null) return;
    final it = HallGeo.hitItem(_items, p);
    if (it != null && !it.locked) {
      _dragId = it.id;
      _dragOff = it.c - p;
      if (_selId != it.id) _select(it.id);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_camCtrl.isAnimating) _camCtrl.stop();
    if (d.pointerCount >= 2) {
      _dragId = null;
      setState(() {
        _cam.zoom = (_zoomStart * d.scale).clamp(0.6, 3.0).toDouble();
        _cam.pan += d.focalPointDelta;
        _clampPan();
      });
      return;
    }
    final it = _itemById(_dragId);
    if (it != null) {
      final p = _cam.toRoom(d.localFocalPoint, _vp);
      if (p == null) return;
      var q = p + _dragOff;
      if (_snap) {
        q = Offset((q.dx / 10).round() * 10.0, (q.dy / 10).round() * 10.0);
      }
      setState(() {
        it.x = (q.dx / kRoomW).clamp(0.03, 0.97).toDouble();
        it.y = (q.dy / kRoomH).clamp(0.03, 0.97).toDouble();
      });
      return;
    }
    setState(() {
      _cam.pan += d.focalPointDelta;
      _clampPan();
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final id = _dragId;
    _dragId = null;
    if (id != null) _markDirty(id);
  }

  Future<void> _onSeatTap(HallItem t, int seat) async {
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

  // ───────────────────────── ÉLÉMENTS ─────────────────────────
  void _setPos(HallItem it, {double? x, double? y}) {
    setState(() {
      if (x != null) it.x = x.clamp(0.03, 0.97).toDouble();
      if (y != null) it.y = y.clamp(0.03, 0.97).toDouble();
    });
    _markDirty(it.id);
  }

  Future<void> _addItem(HallKind kind) async {
    final isTable = kind == HallKind.tableRound ||
        kind == HallKind.tableRect ||
        kind == HallKind.tableSquare;
    final nums = _items.where((i) => i.isTable).map((e) => e.tableNumber ?? 0);
    final n = nums.isEmpty ? 1 : nums.reduce(math.max) + 1;
    final row = {
      'wedding_id': widget.weddingId,
      'kind': kHallKindKey[kind],
      'label': isTable ? 'Table $n' : kHallMeta[kind]!.label,
      'table_number': isTable ? n : null,
      'capacity': isTable ? (kind == HallKind.tableSquare ? 4 : 8) : 0,
      'zone': 'general',
      'x': 0.5 + ((_items.length % 3) - 1) * 0.2,
      'y': 0.42 + ((_items.length ~/ 3) % 4) * 0.1,
      'w': 0,
      'h': 0,
      'rotation': 0,
      'order_index': _items.length,
    };
    try {
      final res = await _supa.from('thix_weeding_hall_items').insert(row).select().single();
      final it = HallItem.fromJson(Map<String, dynamic>.from(res));
      setState(() => _items.add(it));
      _select(it.id);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _toast('Ajout impossible : $e', error: true);
    }
  }

  Future<void> _duplicate(HallItem it) async {
    final nums = _items.where((i) => i.isTable).map((e) => e.tableNumber ?? 0);
    final n = nums.isEmpty ? 1 : nums.reduce(math.max) + 1;
    final row = it.toRow()
      ..['wedding_id'] = widget.weddingId
      ..['x'] = (it.x + 0.07).clamp(0.03, 0.97).toDouble()
      ..['y'] = (it.y + 0.05).clamp(0.03, 0.97).toDouble()
      ..['order_index'] = _items.length;
    if (it.isTable) {
      row['table_number'] = n;
      row['label'] = 'Table $n';
    }
    try {
      final res = await _supa.from('thix_weeding_hall_items').insert(row).select().single();
      final c = HallItem.fromJson(Map<String, dynamic>.from(res));
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
            style: FilledButton.styleFrom(backgroundColor: HallC.rose),
            onPressed: () => Navigator.pop(context, true),
            child: Text(ok),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _deleteItem(HallItem it) async {
    final ok = await _confirm(
      'Supprimer « ${it.label} » ?',
      it.isTable
          ? 'Les invités placés sur cette table seront libérés.'
          : 'Cet élément sera retiré de la salle.',
      'Supprimer',
    );
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

  void _arrangeGrid() {
    final tables = _items.where((i) => i.isTable).toList()
      ..sort((a, b) => (a.tableNumber ?? 0).compareTo(b.tableNumber ?? 0));
    if (tables.isEmpty) {
      _toast('Aucune table à ranger', error: true);
      return;
    }
    final maxW = tables.map((t) => t.extent.width).reduce(math.max);
    final maxH = tables.map((t) => t.extent.height).reduce(math.max);
    final cols = math.max(1, ((kRoomW - 40) / (maxW + 6)).floor());
    final cellW = (kRoomW - 40) / cols;
    final cellH = maxH + 10;
    const startY = 300.0;
    setState(() {
      for (var i = 0; i < tables.length; i++) {
        final col = i % cols, row = i ~/ cols;
        final cx = 20 + cellW * (col + 0.5);
        final cy = startY + cellH * (row + 0.5);
        tables[i].x = (cx / kRoomW).clamp(0.05, 0.95).toDouble();
        tables[i].y = (cy / kRoomH).clamp(0.05, 0.95).toDouble();
        tables[i].rotation = 0;
        _markDirty(tables[i].id);
      }
    });
    HapticFeedback.mediumImpact();
    _toast('${tables.length} table(s) rangée(s) en grille');
  }

  // ───────────────────────── PLACEMENT ─────────────────────────
  Future<bool> _assignSeats(HallGuest g, HallItem t, List<int> seats, {bool quiet = false}) async {
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': t.id,
        'seat_indices': seats,
        'table_number': t.tableNumber,
      }).eq('id', g.id);
      g.tableId = t.id;
      g.seats = seats;
      if (_assigning?.id == g.id) _assigning = null;
      _touch();
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

  Future<void> _assign(HallGuest g, HallItem t, int start) async {
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

  List<HallItem> _bestTables(HallGuest g) {
    final tables = _items.where((i) => i.isTable).toList()
      ..sort((a, b) => (a.tableNumber ?? 0).compareTo(b.tableNumber ?? 0));
    return [
      ...tables.where((t) => t.zone == g.zone),
      ...tables.where((t) => t.zone != g.zone),
    ];
  }

  Future<bool> _autoOne(HallGuest g, {HallItem? table, bool quiet = false}) async {
    final cands = table != null ? [table] : _bestTables(g);
    for (final t in cands) {
      final free = _freeSeats(t, exclude: g.id);
      if (free.length >= g.count) {
        return _assignSeats(g, t, free.take(g.count).toList(), quiet: quiet);
      }
    }
    if (!quiet) _toast('Aucune table n’a assez de places libres', error: true);
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
    _toast('$ok/${pending.length} invité(s) placé(s) automatiquement', error: ok < pending.length);
  }

  Future<void> _unplace(HallGuest g) async {
    try {
      await _supa.from('thix_weeding_guests').update({
        'hall_table_id': null,
        'seat_indices': <int>[],
        'table_number': null,
      }).eq('id', g.id);
      g.tableId = null;
      g.seats = [];
      _touch();
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

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFF3FA),
        body: Center(child: CircularProgressIndicator(color: HallC.gold)),
      );
    }
    final mq = MediaQuery.of(context);
    final sel = _selected;
    final bottomPad = mq.padding.bottom;
    final dockH = sel == null ? 78.0 : (_moreOpen ? mq.size.height * 0.55 : 238.0);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3FA),
      body: Stack(
        children: [
          Positioned.fill(child: _viewport()),
          Positioned(top: mq.padding.top + 6, left: 10, right: 10, child: _topBar()),

          // Rails latéraux (masqués quand le panneau détaillé est ouvert)
          Positioned(
            left: 6,
            top: mq.padding.top + 74,
            bottom: dockH + bottomPad + 14,
            child: _railWrap(_leftRail()),
          ),
          Positioned(
            right: 6,
            top: mq.padding.top + 74,
            bottom: dockH + bottomPad + 14,
            child: _railWrap(_rightRail()),
          ),

          if (_assigning != null)
            Positioned(
              top: mq.padding.top + 70,
              left: 64,
              right: 64,
              child: ThixGlass(
                radius: 16,
                blur: 14,
                tint: const Color(0xFFFFF3C4),
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(
                  children: [
                    const Icon(Icons.event_seat_rounded, size: 16, color: HallC.goldDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Placer ${_assigning!.name} (${_assigning!.count}) — touchez une chaise libre',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _assigning = null),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            left: 8,
            right: 8,
            bottom: 8 + bottomPad,
            child: sel == null ? _dockIdle() : _dockSelected(sel, dockH),
          ),
        ],
      ),
    );
  }

  Widget _railWrap(Widget child) => IgnorePointer(
        ignoring: _moreOpen,
        child: AnimatedOpacity(
          opacity: _moreOpen ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(child: child),
          ),
        ),
      );

  // ───────────────────────── VUE PLEIN ÉCRAN ─────────────────────────
  Widget _viewport() {
    return LayoutBuilder(builder: (context, c) {
      _vp = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _evening
                        ? const [Color(0xFF1B1F3B), Color(0xFF2E2A52)]
                        : const [Color(0xFFE8EFFA), Color(0xFFFBF8F0)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Hall3DView(
                camera: _cam,
                viewport: _vp,
                items: _items,
                occupancy: _occAll(),
                selectedId: _selId,
                selectedSeat: _selSeat,
                assigning: _assigning != null,
                showWall: _wall,
                evening: _evening,
                hq: _hq,
                ambient: _ambient,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ───────────────────────── BARRE DU HAUT ─────────────────────────
  Widget _topBar() {
    final top = _cam.tilt < 0.05;
    return ThixGlass(
      radius: 22,
      opacity: 0.62,
      blur: 16,
      padding: const EdgeInsets.fromLTRB(2, 3, 8, 3),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
            onPressed: () {
              if (context.canPop()) context.pop();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Plan de salle',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: HallC.ink)),
                Text('$_seatedPersons/$_totalPersons placés · $_totalSeats chaises',
                    style: GoogleFonts.inter(fontSize: 10, color: HallC.ink2, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _viewChip('Dessus', top, () => _goTo(tilt: 0)),
          const SizedBox(width: 4),
          _viewChip('3D', !top, () => _goTo(tilt: 0.62)),
        ],
      ),
    );
  }

  Widget _viewChip(String t, bool on, VoidCallback f) => GestureDetector(
        onTap: f,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: on ? HallC.rose : Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(t,
              style: GoogleFonts.inter(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: on ? Colors.white : HallC.ink)),
        ),
      );

  // ───────────────────────── RAIL GAUCHE : VUE ─────────────────────────
  Widget _leftRail() => ThixGlass(
        radius: 24,
        opacity: 0.58,
        blur: 16,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailBtn(icon: Icons.add_rounded, label: 'Zoom +', onTap: () => _goTo(zoom: _cam.zoom * 1.25)),
            _RailBtn(icon: Icons.remove_rounded, label: 'Zoom −', onTap: () => _goTo(zoom: _cam.zoom / 1.25)),
            _RailBtn(icon: Icons.keyboard_arrow_up_rounded, label: 'Incliner', onTap: () => _goTo(tilt: _cam.tilt + 0.12)),
            _RailBtn(icon: Icons.keyboard_arrow_down_rounded, label: 'Redresser', onTap: () => _goTo(tilt: _cam.tilt - 0.12)),
            _RailBtn(icon: Icons.rotate_left_rounded, label: 'Pivoter', onTap: () => _goTo(rot: _cam.rot - math.pi / 12)),
            _RailBtn(icon: Icons.rotate_right_rounded, label: 'Pivoter', onTap: () => _goTo(rot: _cam.rot + math.pi / 12)),
            _RailBtn(
              icon: Icons.center_focus_strong_rounded,
              label: 'Centrer',
              onTap: () => _goTo(tilt: 0.62, rot: 0, zoom: 1, pan: kDefaultPan),
            ),
          ],
        ),
      );

  // ───────────────────────── RAIL DROIT : OUTILS ─────────────────────────
  Widget _rightRail() => ThixGlass(
        radius: 24,
        opacity: 0.58,
        blur: 16,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailBtn(icon: Icons.add_circle_rounded, label: 'Ajouter', onTap: _openAddSheet, color: HallC.rose),
            _RailBtn(icon: Icons.groups_rounded, label: 'Invités', badge: _unplacedCount, onTap: _openGuests),
            _RailBtn(
              icon: _lockObjects ? Icons.lock_rounded : Icons.lock_open_rounded,
              label: _lockObjects ? 'Verrouillé' : 'Libre',
              active: _lockObjects,
              onTap: () => setState(() => _lockObjects = !_lockObjects),
            ),
            _RailBtn(
              icon: Icons.grid_4x4_rounded,
              label: 'Aimant',
              active: _snap,
              onTap: () => setState(() => _snap = !_snap),
            ),
            _RailBtn(
              icon: _evening ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              label: _evening ? 'Soir' : 'Jour',
              onTap: () {
                setState(() => _evening = !_evening);
                _saveLayout();
              },
            ),
            _RailBtn(
              icon: Icons.window_rounded,
              label: 'Mur',
              active: _wall,
              onTap: () {
                setState(() => _wall = !_wall);
                _saveLayout();
              },
            ),
            _RailBtn(icon: Icons.auto_awesome_mosaic_rounded, label: 'Grille', onTap: _arrangeGrid),
            _RailBtn(icon: Icons.tune_rounded, label: 'Réglages', onTap: _openSettings),
          ],
        ),
      );

  // ───────────────────────── DOCK (bas) ─────────────────────────
  Widget _dockIdle() => ThixGlass(
        radius: 24,
        opacity: 0.7,
        blur: 16,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE91E78), Color(0xFFC2185B)]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Touchez un objet pour le régler',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: HallC.ink)),
                  Text('Glissez-le, ou utilisez les curseurs X / Y.',
                      style: GoogleFonts.inter(fontSize: 10.5, color: HallC.ink2)),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HallC.rose,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openGuests,
              icon: const Icon(Icons.groups_rounded, size: 17),
              label: Text('$_unplacedCount', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );

  Widget _dockSelected(HallItem it, double maxH) {
    final meta = kHallMeta[it.kind]!;
    final zc = hallZoneColor(it.zone);
    final occ = it.isTable ? _occupancy(it.id) : <int, HallGuest>{};
    final seated = it.isTable
        ? _guests.where((g) => g.active && g.tableId == it.id).toList()
        : <HallGuest>[];
    final unplaced = _guests.where((g) => g.active && !g.placed).toList();
    final canRotate =
        it.kind != HallKind.tableRound && it.kind != HallKind.plant && it.kind != HallKind.cake;

    return ThixGlass(
      radius: 26,
      opacity: 0.82,
      blur: 18,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [zc, zc.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(meta.icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _labelCtrl,
                      onChanged: (v) {
                        it.label = v;
                        _markDirty(it.id);
                        setState(() {});
                      },
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14.5, color: HallC.ink),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Nom',
                      ),
                    ),
                  ),
                  _miniBtn(Icons.copy_rounded, () => _duplicate(it)),
                  _miniBtn(it.locked ? Icons.lock_rounded : Icons.lock_open_rounded, () {
                    setState(() => it.locked = !it.locked);
                    _markDirty(it.id);
                  }, active: it.locked),
                  _miniBtn(Icons.delete_outline_rounded, () => _deleteItem(it), color: HallC.rose),
                  _miniBtn(Icons.close_rounded, () => _select(null)),
                ],
              ),
              _axis('X', it.x, 0.03, 0.97, (v) => _setPos(it, x: v), (v) => '${(v * 100).round()}%'),
              _axis('Y', it.y, 0.03, 0.97, (v) => _setPos(it, y: v), (v) => '${(v * 100).round()}%'),
              if (canRotate)
                _axis('↻', it.rotation, -math.pi, math.pi, (v) {
                  setState(() => it.rotation = v);
                  _markDirty(it.id);
                }, (v) => '${(v * 180 / math.pi).round()}°', step: math.pi / 36),
              GestureDetector(
                onTap: () => setState(() => _moreOpen = !_moreOpen),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_moreOpen ? 'Moins d\'options' : 'Plus d\'options',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: HallC.rose)),
                      Icon(_moreOpen ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                          size: 18, color: HallC.rose),
                    ],
                  ),
                ),
              ),
              if (_moreOpen) ..._extras(it, occ, seated, unplaced),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _extras(HallItem it, Map<int, HallGuest> occ, List<HallGuest> seated, List<HallGuest> unplaced) {
    return [
      if (it.isTable) ...[
        Row(
          children: [
            Expanded(
              child: _Stepper(
                label: 'Chaises',
                value: it.capacity,
                onMinus: () {
                  final maxUsed = occ.keys.isEmpty ? -1 : occ.keys.reduce(math.max);
                  if (it.capacity - 1 <= maxUsed) {
                    _toast('Libérez d’abord la place ${maxUsed + 1}', error: true);
                    return;
                  }
                  if (it.capacity > 2) {
                    setState(() => it.capacity--);
                    _markDirty(it.id);
                  }
                },
                onPlus: () {
                  final cap = it.kind == HallKind.tableSquare ? 8 : 20;
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
          children: kHallZoneLabels.entries
              .map((e) => ChoiceChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 11)),
                    selected: it.zone == e.key,
                    selectedColor: hallZoneColor(e.key).withOpacity(0.25),
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
          children: [HallKind.tableRound, HallKind.tableRect, HallKind.tableSquare]
              .map((k) => ChoiceChip(
                    label: Text(kHallMeta[k]!.label, style: const TextStyle(fontSize: 11)),
                    avatar: Icon(kHallMeta[k]!.icon, size: 14),
                    selected: it.kind == k,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      if (k == HallKind.tableSquare && it.capacity > 8) {
                        _toast('Une table carrée a 8 chaises maximum', error: true);
                        return;
                      }
                      setState(() => it.kind = k);
                      _markDirty(it.id);
                    },
                  ))
              .toList(),
        ),
      ] else if (it.kind != HallKind.plant && it.kind != HallKind.cake) ...[
        _axis('L', it.body.width, 60, 520, (v) {
          setState(() => it.w = v);
          _markDirty(it.id);
        }, (v) => v.round().toString(), step: 6),
        _axis('P', it.body.height, 30, 320, (v) {
          setState(() => it.h = v);
          _markDirty(it.id);
        }, (v) => v.round().toString(), step: 6),
      ],
      if (it.isTable) ...[
        const SizedBox(height: 10),
        Text('À cette table (${occ.length}/${it.capacity})',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5, color: HallC.ink)),
        const SizedBox(height: 6),
        if (seated.isEmpty)
          Text('Personne pour l’instant', style: GoogleFonts.inter(fontSize: 11.5, color: HallC.ink2))
        else
          ...seated.map((g) => Padding(padding: const EdgeInsets.only(bottom: 6), child: _guestTile(g))),
        const SizedBox(height: 8),
        Text('Placer un invité ici',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5, color: HallC.ink)),
        const SizedBox(height: 6),
        if (unplaced.isEmpty)
          Text('Aucun invité libre', style: GoogleFonts.inter(fontSize: 11.5, color: HallC.ink2))
        else
          ...unplaced.map((g) => Padding(padding: const EdgeInsets.only(bottom: 6), child: _guestTile(g, table: it))),
      ],
      const SizedBox(height: 6),
    ];
  }

  Widget _miniBtn(IconData icon, VoidCallback f, {Color? color, bool active = false}) => GestureDetector(
        onTap: f,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 19, color: active ? HallC.rose : (color ?? HallC.ink)),
        ),
      );

  Widget _axis(String label, double v, double min, double max, ValueChanged<double> on,
      String Function(double) fmt, {double step = 0.005}) {
    double clampV(double x) => x.clamp(min, max).toDouble();
    Widget stepBtn(IconData i, double d) => GestureDetector(
          onTap: () => on(clampV(v + d)),
          behavior: HitTestBehavior.opaque,
          child: Padding(padding: const EdgeInsets.all(5), child: Icon(i, size: 20, color: HallC.rose)),
        );
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: HallC.ink)),
          ),
          stepBtn(Icons.chevron_left_rounded, -step),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: clampV(v),
                min: min,
                max: max,
                activeColor: HallC.rose,
                inactiveColor: HallC.rose.withOpacity(0.18),
                onChanged: on,
              ),
            ),
          ),
          stepBtn(Icons.chevron_right_rounded, step),
          SizedBox(
            width: 40,
            child: Text(fmt(v),
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: HallC.ink2)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── INVITÉS ─────────────────────────
  void _openGuests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.93,
        expand: false,
        builder: (ctx, sc) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: ThixGlass(
            radius: 28,
            opacity: 0.82,
            padding: EdgeInsets.zero,
            child: ValueListenableBuilder<int>(
              valueListenable: _tick,
              builder: (_, __, ___) => _guestsPanel(sc, ctx),
            ),
          ),
        ),
      ),
    );
  }

  Widget _guestsPanel(ScrollController sc, BuildContext sheetCtx) {
    final q = _query.toLowerCase();
    final list = _guests
        .where((g) =>
            g.active &&
            (_showPlaced ? g.placed : !g.placed) &&
            (q.isEmpty || g.name.toLowerCase().contains(q)))
        .toList();
    final ratio = _totalPersons == 0 ? 0.0 : _seatedPersons / _totalPersons;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Invités',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: HallC.ink)),
                  const Spacer(),
                  Text('${(ratio * 100).round()}% placés',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: HallC.green)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.6),
                  valueColor: const AlwaysStoppedAnimation(HallC.green),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        _query = v;
                        _tick.value++;
                      },
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Rechercher un invité',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sheetChip('À placer ($_unplacedCount)', !_showPlaced, () {
                    _showPlaced = false;
                    _tick.value++;
                  }),
                  const SizedBox(width: 4),
                  _sheetChip('Placés', _showPlaced, () {
                    _showPlaced = true;
                    _tick.value++;
                  }),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _autoPlaceAll();
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                      label: const Text('Tout placer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _releaseAll();
                      },
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      label: const Text('Tout libérer'),
                    ),
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
                    _showPlaced ? 'Personne n’est encore placé' : 'Tous les invités sont placés ✨',
                    style: GoogleFonts.inter(color: HallC.ink2, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _guestTile(list[i], sheetCtx: sheetCtx),
                ),
        ),
      ],
    );
  }

  Widget _sheetChip(String t, bool on, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: on ? HallC.blue : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(t,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800, color: on ? Colors.white : HallC.ink)),
        ),
      );

  Widget _guestTile(HallGuest g, {HallItem? table, BuildContext? sheetCtx}) {
    final t = _itemById(g.tableId);
    final sub = g.placed
        ? '${t?.label ?? 'Table'} · place${g.seats.length > 1 ? 's' : ''} ${(List<int>.from(g.seats)..sort()).map((s) => s + 1).join(', ')}'
        : '${kHallZoneLabels[g.zone] ?? 'Général'} · ${g.count} pers.';
    return GestureDetector(
      onTap: g.placed && t != null
          ? () {
              if (sheetCtx != null) Navigator.pop(sheetCtx);
              _select(t.id);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: hallZoneColor(g.zone).withOpacity(0.2),
              child: g.isVip
                  ? const Icon(Icons.star, size: 14, color: HallC.gold)
                  : Text(g.initial,
                      style: TextStyle(color: hallZoneColor(g.zone), fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5, color: HallC.ink)),
                  Text(sub, style: GoogleFonts.inter(fontSize: 10.5, color: HallC.ink2)),
                ],
              ),
            ),
            if (g.placed)
              IconButton(
                tooltip: 'Libérer la place',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.link_off_rounded, size: 19, color: HallC.rose),
                onPressed: () => _unplace(g),
              )
            else ...[
              IconButton(
                tooltip: table != null ? 'Placer sur ${table.label}' : 'Placement automatique',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 19, color: HallC.blue),
                onPressed: () => _autoOne(g, table: table),
              ),
              IconButton(
                tooltip: 'Choisir la chaise',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.event_seat_rounded, size: 19, color: HallC.goldDark),
                onPressed: () {
                  if (sheetCtx != null) Navigator.pop(sheetCtx);
                  setState(() {
                    _assigning = g;
                    _moreOpen = false;
                  });
                },
              ),
            ],
          ],
        ),
      ),
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
          opacity: 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajouter à la salle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HallKind.values.map((k) {
                  final m = kHallMeta[k]!;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _addItem(k);
                    },
                    child: Container(
                      width: 96,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        children: [
                          Icon(m.icon, color: HallC.blue, size: 24),
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

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: const EdgeInsets.all(12),
          child: ThixGlass(
            radius: 26,
            opacity: 0.82,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Réglages de la salle',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, size: 18),
                    Expanded(
                      child: Slider(
                        value: _ambient,
                        min: 0.4,
                        max: 1,
                        activeColor: HallC.gold,
                        onChanged: (v) {
                          setState(() => _ambient = v);
                          setM(() {});
                        },
                        onChangeEnd: (_) => _saveLayout(),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Haute qualité 3D'),
                  subtitle: const Text('Désactivez-la sur un téléphone lent'),
                  value: _hq,
                  onChanged: (v) {
                    setState(() => _hq = v);
                    setM(() {});
                  },
                ),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.auto_awesome_mosaic_rounded, color: HallC.blue),
                  title: const Text('Ranger les tables en grille'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _arrangeGrid();
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.auto_fix_high_rounded, color: HallC.blue),
                  title: const Text('Placer tous les invités automatiquement'),
                  subtitle: const Text('VIP d’abord, par zone de table'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _autoPlaceAll();
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.link_off_rounded, color: HallC.rose),
                  title: const Text('Libérer toutes les chaises'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _releaseAll();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PETITS WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _RailBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final int badge;
  final Color? color;
  const _RailBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? HallC.rose : Colors.white.withOpacity(0.78),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Icon(icon, size: 19, color: active ? Colors.white : (color ?? HallC.ink)),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: HallC.rose,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text('$badge',
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: HallC.ink2)),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 17), onPressed: onMinus),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$value', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14)),
                Text(label, style: GoogleFonts.inter(fontSize: 9, color: HallC.ink2)),
              ],
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 17), onPressed: onPlus),
        ],
      ),
    );
  }
}
