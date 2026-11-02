// lib/presentation/thix_weeding/pages/guest/guest_table_page.dart
// ============================================================================
// THIX WEDDING — MA TABLE (INVITÉ) : plan 3D du staff + point rouge « VOUS »
// ✅ Même plan que le staff, lecture seule, en direct
// ✅ Caméra centrée sur votre table, point rouge pulsant sur votre chaise
// ✅ Voisins de table (prénoms uniquement) • accès à mon QR code
// ============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/widgets/hall_3d_core.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

class GuestTablePage extends StatefulWidget {
  final String weddingId;
  const GuestTablePage({super.key, required this.weddingId});

  @override
  State<GuestTablePage> createState() => _GuestTablePageState();
}

class _GuestTablePageState extends State<GuestTablePage> {
  final _supa = Supabase.instance.client;
  final HallCamera _cam = HallCamera();
  Size _vp = Size.zero;
  double _zoomStart = 1;

  List<HallItem> _items = [];
  List<HallGuest> _guests = [];
  bool _loading = true;
  String? _error;
  double _ambient = 0.9;
  bool _wall = true, _evening = false;

  String? _myTableId;
  List<int> _mySeats = [];
  String? _selId;
  bool _needsFocus = true;

  RealtimeChannel? _ch;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _load();
    _ch = _supa
        .channel('guest-table-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_hall_items',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) => _later(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_guests',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) => _later(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) _supa.removeChannel(_ch!);
    super.dispose();
  }

  void _later() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final rows = await _supa
          .from('thix_weeding_hall_items')
          .select()
          .eq('wedding_id', widget.weddingId)
          .order('order_index', ascending: true);
      final items = (rows as List)
          .map((e) => HallItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final lay = await _supa
          .from('thix_weeding_hall_layout')
          .select()
          .eq('wedding_id', widget.weddingId)
          .maybeSingle();

      final guests = <HallGuest>[];
      String? myTable;
      var mySeats = <int>[];

      try {
        final res = await _supa.rpc('thix_weeding_seat_map', params: {'p_wedding_id': widget.weddingId});
        for (final raw in (res as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final seats = ((m['seat_indices'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
          final g = HallGuest(
            id: '${m['guest_id']}',
            name: '${m['first_name'] ?? ''}',
            count: 1,
            isVip: false,
            group: null,
            active: true,
            tableId: m['hall_table_id'] as String?,
            seats: seats,
          );
          if (m['is_me'] == true) {
            myTable = g.tableId;
            mySeats = seats..sort();
          } else {
            guests.add(g);
          }
        }
      } catch (_) {
        // Repli : uniquement ma propre place
        final user = _supa.auth.currentUser;
        if (user != null) {
          final g = await _supa
              .from('thix_weeding_guests')
              .select('hall_table_id, seat_indices')
              .eq('wedding_id', widget.weddingId)
              .eq('user_id', user.id)
              .maybeSingle();
          if (g != null) {
            myTable = g['hall_table_id'] as String?;
            mySeats = ((g['seat_indices'] as List?) ?? const []).map((e) => (e as num).toInt()).toList()..sort();
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _guests = guests;
        _myTableId = myTable;
        _mySeats = mySeats;
        if (lay != null) {
          _ambient = (lay['ambient_light'] as num?)?.toDouble() ?? 0.9;
          _wall = (lay['show_wall'] as bool?) ?? true;
          _evening = (lay['evening'] as bool?) ?? false;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() { _loading = false; _error = '$e'; });
    }
  }

  HallItem? get _myTable {
    for (final i in _items) {
      if (i.id == _myTableId) return i;
    }
    return null;
  }

  HallItem? _byId(String? id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Map<String, Map<int, HallGuest>> _occ() {
    final out = <String, Map<int, HallGuest>>{};
    for (final g in _guests) {
      if (g.tableId == null) continue;
      final m = out.putIfAbsent(g.tableId!, () => {});
      for (final s in g.seats) {
        m[s] = g;
      }
    }
    return out;
  }

  void _focusMine({bool smooth = false}) {
    final t = _myTable;
    if (t == null || _vp.isEmpty) return;
    setState(() => _cam.focusOn(t.c, _vp, zoomTo: 1.7));
  }

  // ───────────────────────── GESTES (vue seulement) ─────────────────────────
  void _onTapUp(TapUpDetails d) {
    final p = _cam.toRoom(d.localPosition, _vp);
    if (p == null) return;
    final hit = HallGeo.hitItem(_items, p);
    setState(() => _selId = (hit != null && hit.isTable) ? hit.id : null);
  }

  void _onScaleStart(ScaleStartDetails d) => _zoomStart = _cam.zoom;

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        _cam.zoom = (_zoomStart * d.scale).clamp(0.6, 3.0).toDouble();
      }
      _cam.pan += d.focalPointDelta;
      final lim = 420.0 * _cam.zoom;
      _cam.pan = Offset(_cam.pan.dx.clamp(-lim, lim).toDouble(), _cam.pan.dy.clamp(-lim, lim).toDouble());
    });
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3FA),
      body: Stack(
        children: [
          Positioned.fill(child: _body()),
          Positioned(top: mq.padding.top + 6, left: 10, right: 10, child: _topBar()),
          if (!_loading && _error == null)
            Positioned(
              left: 6,
              top: mq.padding.top + 74,
              bottom: 250 + mq.padding.bottom,
              child: Align(alignment: Alignment.center, child: SingleChildScrollView(child: _rail())),
            ),
          if (!_loading && _error == null)
            Positioned(left: 8, right: 8, bottom: 8 + mq.padding.bottom, child: _card()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: HallC.rose));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ThixGlass(
            radius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: HallC.rose, size: 40),
                const SizedBox(height: 10),
                Text('Plan indisponible\n$_error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: HallC.rose),
                  onPressed: () {
                    setState(() { _loading = true; _error = null; });
                    _load();
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ThixGlass(
            radius: 24,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_restaurant_outlined, color: HallC.rose, size: 42),
                const SizedBox(height: 10),
                Text('Le plan de salle n\'est pas encore prêt',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                Text('Les mariés l\'afficheront ici dès qu\'il sera publié.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: HallC.ink2, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      _vp = Size(c.maxWidth, c.maxHeight);
      if (_needsFocus && _myTable != null) {
        _needsFocus = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusMine();
        });
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
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
                occupancy: _occ(),
                selectedId: _selId ?? _myTableId,
                mySeats: _myTableId == null ? const {} : {_myTableId!: _mySeats.toSet()},
                showInitials: false,
                showWall: _wall,
                evening: _evening,
                hq: true,
                ambient: _ambient,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _topBar() => ThixGlass(
        radius: 22,
        opacity: 0.62,
        blur: 16,
        padding: const EdgeInsets.fromLTRB(2, 3, 10, 3),
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
                  Text('Ma table',
                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: HallC.ink)),
                  Text('Plan de la salle en direct',
                      style: GoogleFonts.inter(fontSize: 10, color: HallC.ink2, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: HallC.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: HallC.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('Votre place',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: HallC.red)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _rail() => ThixGlass(
        radius: 24,
        opacity: 0.58,
        blur: 16,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.my_location_rounded, 'Ma place', _focusMine, color: HallC.red),
            _btn(Icons.add_rounded, 'Zoom +', () => setState(() => _cam.zoom = (_cam.zoom * 1.25).clamp(0.6, 3.0).toDouble())),
            _btn(Icons.remove_rounded, 'Zoom −', () => setState(() => _cam.zoom = (_cam.zoom / 1.25).clamp(0.6, 3.0).toDouble())),
            _btn(Icons.grid_view_rounded, 'Dessus', () => setState(() => _cam.tilt = 0)),
            _btn(Icons.view_in_ar_rounded, '3D', () => setState(() => _cam.tilt = 0.62)),
            _btn(Icons.rotate_left_rounded, 'Pivoter', () => setState(() => _cam.rot -= math.pi / 12)),
            _btn(Icons.rotate_right_rounded, 'Pivoter', () => setState(() => _cam.rot += math.pi / 12)),
            _btn(Icons.center_focus_strong_rounded, 'Tout', () {
              setState(() {
                _cam.tilt = 0.62;
                _cam.rot = 0;
                _cam.zoom = 1;
                _cam.pan = kDefaultPan;
              });
            }),
          ],
        ),
      );

  Widget _btn(IconData i, String l, VoidCallback f, {Color? color}) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          f();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.78),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Icon(i, size: 19, color: color ?? HallC.ink),
                ),
                const SizedBox(height: 2),
                Text(l, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: HallC.ink2)),
              ],
            ),
          ),
        ),
      );

  // ───────────────────────── CARTE DU BAS ─────────────────────────
  Widget _card() {
    final mine = _myTable;
    final shown = _byId(_selId) ?? mine;
    final isMine = shown != null && shown.id == _myTableId;
    final mates = shown == null
        ? <HallGuest>[]
        : _guests.where((g) => g.tableId == shown.id).toList();
    final occupiedSeats = shown == null
        ? 0
        : (_occ()[shown.id]?.length ?? 0) + (isMine ? _mySeats.length : 0);

    return ThixGlass(
      radius: 26,
      opacity: 0.82,
      blur: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE91E78), Color(0xFFC2185B)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMine ? 'VOTRE TABLE' : 'TABLE',
                        style: GoogleFonts.inter(
                            fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: HallC.ink2)),
                    Text(
                      shown?.label ?? 'En cours d\'attribution',
                      style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w900, color: HallC.ink),
                    ),
                  ],
                ),
              ),
              if (shown != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: HallC.rose.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$occupiedSeats/${shown.capacity}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: HallC.rose)),
                ),
            ],
          ),
          if (isMine && _mySeats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: HallC.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.6),
                    boxShadow: [BoxShadow(color: HallC.red.withOpacity(0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Text('Votre place : ',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: HallC.ink)),
                ..._mySeats.map((s) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: HallC.red, width: 2),
                      ),
                      child: Text('${s + 1}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: HallC.red)),
                    )),
              ],
            ),
          ] else if (mine == null) ...[
            const SizedBox(height: 8),
            Text('Votre table et votre place apparaîtront ici dès que les mariés les auront choisies.',
                style: GoogleFonts.inter(fontSize: 12, color: HallC.ink2, height: 1.35)),
          ],
          if (mates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(isMine ? 'À votre table' : 'À cette table',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: HallC.ink2)),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(mates[i].name,
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: HallC.ink)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: mine == null ? null : () => _focusMine(),
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Me montrer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HallC.red,
                    side: BorderSide(color: HallC.red.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: HallC.rose,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.push('/thix-weeding/guest/${widget.weddingId}/invitation'),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Mon QR code'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
