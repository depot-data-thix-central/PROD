// lib/presentation/thix_weeding/widgets/hall_3d_core.dart
// ============================================================================
// THIX WEDDING — MOTEUR 3D DE LA SALLE (partagé staff + invités)
// ✅ Salle verticale (portrait) • caméra stable (inclinaison/rotation par pas)
// ✅ Conversion écran → plan (glisser-déposer exact même en perspective)
// ✅ Point rouge pulsant pour « votre place »
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const double kRoomW = 640;
const double kRoomH = 1000;
const double kWallH = 260;
const double kSeatGap = 13;
const double kPersp = 0.0006;
const Offset kDefaultPan = Offset(0, 10);

class HallC {
  static const gold = Color(0xFFD4AF37);
  static const goldDark = Color(0xFFB8860B);
  static const rose = Color(0xFFD81B60);
  static const red = Color(0xFFE11D2E);
  static const blue = Color(0xFF0B3B8F);
  static const purple = Color(0xFF6B46C1);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
  static const ink = Color(0xFF111827);
  static const ink2 = Color(0xFF6B7280);
  static const cloth = Color(0xFFFBF8F1);
  static const clothSide = Color(0xFFE7DFCC);
}

const Map<String, Color> kHallZoneColors = {
  'general': Color(0xFF94A3B8),
  'vip': HallC.gold,
  'famille_marié': HallC.blue,
  'famille_mariée': HallC.rose,
  'amis': HallC.purple,
  'collegues': HallC.amber,
};

const Map<String, String> kHallZoneLabels = {
  'general': 'Général',
  'vip': 'VIP',
  'famille_marié': 'Famille du marié',
  'famille_mariée': 'Famille de la mariée',
  'amis': 'Amis',
  'collegues': 'Collègues',
};

Color hallZoneColor(String z) => kHallZoneColors[z] ?? kHallZoneColors['general']!;

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════
enum HallKind {
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
}

const Map<HallKind, String> kHallKindKey = {
  HallKind.tableRound: 'table_round',
  HallKind.tableRect: 'table_rect',
  HallKind.tableSquare: 'table_square',
  HallKind.stage: 'stage',
  HallKind.dance: 'dance',
  HallKind.buffet: 'buffet',
  HallKind.bar: 'bar',
  HallKind.cake: 'cake',
  HallKind.dj: 'dj',
  HallKind.entrance: 'entrance',
  HallKind.vip: 'vip_zone',
  HallKind.plant: 'plant',
};

HallKind hallKindFrom(String? k) => kHallKindKey.entries
    .firstWhere((e) => e.value == k,
        orElse: () => const MapEntry(HallKind.tableRound, 'table_round'))
    .key;

class HallKindMeta {
  final String label;
  final IconData icon;
  final double w;
  final double h;
  const HallKindMeta(this.label, this.icon, this.w, this.h);
}

const Map<HallKind, HallKindMeta> kHallMeta = {
  HallKind.tableRound: HallKindMeta('Table ronde', Icons.circle_outlined, 0, 0),
  HallKind.tableRect: HallKindMeta('Table rectangulaire', Icons.rectangle_outlined, 0, 0),
  HallKind.tableSquare: HallKindMeta('Table carrée', Icons.crop_square, 0, 0),
  HallKind.stage: HallKindMeta('Scène', Icons.theater_comedy, 380, 84),
  HallKind.dance: HallKindMeta('Piste de danse', Icons.nightlife, 220, 150),
  HallKind.buffet: HallKindMeta('Buffet', Icons.restaurant, 240, 46),
  HallKind.bar: HallKindMeta('Bar', Icons.local_bar, 170, 42),
  HallKind.cake: HallKindMeta('Gâteau', Icons.cake, 50, 50),
  HallKind.dj: HallKindMeta('DJ / Sono', Icons.speaker, 130, 52),
  HallKind.entrance: HallKindMeta('Entrée', Icons.door_front_door, 130, 40),
  HallKind.vip: HallKindMeta('Zone VIP', Icons.star, 260, 180),
  HallKind.plant: HallKindMeta('Plante', Icons.local_florist, 34, 34),
};

class HallSeat {
  final int index;
  final Offset off;
  final double phi;
  const HallSeat(this.index, this.off, this.phi);
}

Offset hallRot2(Offset o, double a) {
  final c = math.cos(a), s = math.sin(a);
  return Offset(o.dx * c - o.dy * s, o.dx * s + o.dy * c);
}

class HallItem {
  final String id;
  HallKind kind;
  String label;
  int? tableNumber;
  int capacity;
  String zone;
  double x, y, w, h, rotation;
  bool locked;

  HallItem({
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

  factory HallItem.fromJson(Map<String, dynamic> j) => HallItem(
        id: j['id'].toString(),
        kind: hallKindFrom(j['kind'] as String?),
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
        'kind': kHallKindKey[kind],
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
      kind == HallKind.tableRound ||
      kind == HallKind.tableRect ||
      kind == HallKind.tableSquare;

  bool get isFlat =>
      kind == HallKind.vip || kind == HallKind.dance || kind == HallKind.entrance;

  Offset get c => Offset(x * kRoomW, y * kRoomH);

  Size get body {
    switch (kind) {
      case HallKind.tableRound:
        final r = 20 + capacity * 2.6;
        return Size(r * 2, r * 2);
      case HallKind.tableRect:
        final per = (capacity / 2).ceil();
        return Size(math.max(96.0, per * 34.0 + 14), 54);
      case HallKind.tableSquare:
        return const Size(78, 78);
      default:
        final m = kHallMeta[kind]!;
        return Size(w > 0 ? w : m.w, h > 0 ? h : m.h);
    }
  }

  Size get extent => isTable
      ? Size(body.width + 78, body.height + 78)
      : Size(body.width + 24, body.height + 24);

  /// Ordre des places : ronde = horaire depuis le haut ; rect = haut G→D puis bas G→D ;
  /// carrée = haut, bas, gauche, droite.
  List<HallSeat> get seats {
    final b = body;
    final n = capacity;
    final out = <HallSeat>[];
    if (kind == HallKind.tableRound) {
      final r = b.width / 2 + kSeatGap;
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        out.add(HallSeat(i, Offset(math.cos(a) * r, math.sin(a) * r), a + math.pi / 2));
      }
    } else if (kind == HallKind.tableRect) {
      final top = (n + 1) ~/ 2, bot = n - top;
      var i = 0;
      for (var k = 0; k < top; k++) {
        out.add(HallSeat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / top, -b.height / 2 - kSeatGap), 0));
      }
      for (var k = 0; k < bot; k++) {
        out.add(HallSeat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / bot, b.height / 2 + kSeatGap), math.pi));
      }
    } else if (kind == HallKind.tableSquare) {
      final base = n ~/ 4, rem = n % 4;
      final top = base + (rem > 0 ? 1 : 0);
      final bot = base + (rem > 1 ? 1 : 0);
      final left = base + (rem > 2 ? 1 : 0);
      final right = base;
      var i = 0;
      for (var k = 0; k < top; k++) {
        out.add(HallSeat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / top, -b.height / 2 - kSeatGap), 0));
      }
      for (var k = 0; k < bot; k++) {
        out.add(HallSeat(i++, Offset(-b.width / 2 + b.width * (k + 0.5) / bot, b.height / 2 + kSeatGap), math.pi));
      }
      for (var k = 0; k < left; k++) {
        out.add(HallSeat(i++, Offset(-b.width / 2 - kSeatGap, -b.height / 2 + b.height * (k + 0.5) / left), -math.pi / 2));
      }
      for (var k = 0; k < right; k++) {
        out.add(HallSeat(i++, Offset(b.width / 2 + kSeatGap, -b.height / 2 + b.height * (k + 0.5) / right), math.pi / 2));
      }
    }
    return out;
  }
}

class HallGuest {
  final String id;
  final String name;
  final int count;
  final bool isVip;
  final String? group;
  final bool active;
  String? tableId;
  List<int> seats;

  HallGuest({
    required this.id,
    required this.name,
    required this.count,
    required this.isVip,
    required this.group,
    required this.active,
    required this.tableId,
    required this.seats,
  });

  factory HallGuest.fromJson(Map<String, dynamic> j) => HallGuest(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? '—',
        count: (j['guests_count'] as num?)?.toInt() ?? 1,
        isVip: (j['is_vip'] as bool?) ?? false,
        group: j['group_name'] as String?,
        active: (j['invitation_active'] as bool?) ?? true,
        tableId: j['hall_table_id'] as String?,
        seats: ((j['seat_indices'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      );

  bool get placed => tableId != null && seats.isNotEmpty;
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
  String get zone => isVip ? 'vip' : (group ?? 'general');
}

// ═══════════════════════════════════════════════════════════════════════════
// CAMÉRA (stable) + CONVERSIONS
// ═══════════════════════════════════════════════════════════════════════════
class HallCamera {
  double tilt;
  double rot;
  double zoom;
  Offset pan;

  HallCamera({this.tilt = 0.62, this.rot = 0, this.zoom = 1, this.pan = kDefaultPan});

  double fit(Size v) {
    final c = math.cos(rot).abs(), s = math.sin(rot).abs();
    final w = kRoomW * c + kRoomH * s;
    final h = (kRoomW * s + kRoomH * c) * 0.82;
    return math.min(v.width / w, v.height / h) * 0.96;
  }

  Matrix4 matrix(Size v) {
    final k = fit(v) * zoom;
    return Matrix4.identity()
      ..setEntry(3, 2, kPersp)
      ..rotateX(tilt)
      ..rotateZ(rot)
      ..scale(k, k, k);
  }

  /// Point écran → point du plan (sol), exact même en perspective.
  Offset? toRoom(Offset local, Size v) {
    final m = matrix(v);
    final sx = local.dx - v.width / 2 - pan.dx;
    final sy = local.dy - v.height / 2 - pan.dy;
    final a = m.entry(0, 0) - sx * m.entry(3, 0);
    final b = m.entry(0, 1) - sx * m.entry(3, 1);
    final e = sx * m.entry(3, 3) - m.entry(0, 3);
    final c = m.entry(1, 0) - sy * m.entry(3, 0);
    final d = m.entry(1, 1) - sy * m.entry(3, 1);
    final f = sy * m.entry(3, 3) - m.entry(1, 3);
    final det = a * d - b * c;
    if (det.abs() < 1e-9) return null;
    final x = (e * d - b * f) / det;
    final y = (a * f - e * c) / det;
    return Offset(x + kRoomW / 2, y + kRoomH / 2);
  }

  /// Point du plan → écran (relatif au centre de la vue, sans pan).
  Offset project(Offset room, Size v) {
    final m = matrix(v);
    final x = room.dx - kRoomW / 2, y = room.dy - kRoomH / 2;
    final X = m.entry(0, 0) * x + m.entry(0, 1) * y + m.entry(0, 3);
    final Y = m.entry(1, 0) * x + m.entry(1, 1) * y + m.entry(1, 3);
    final W = m.entry(3, 0) * x + m.entry(3, 1) * y + m.entry(3, 3);
    return Offset(X / W, Y / W);
  }

  void focusOn(Offset room, Size v, {double? zoomTo}) {
    if (zoomTo != null) zoom = zoomTo;
    final p = project(room, v);
    pan = Offset(-p.dx, -p.dy);
  }
}

class HallGeo {
  static bool contains(HallItem it, Offset p) {
    final d = p - it.c;
    final l = hallRot2(d, -it.rotation);
    final b = it.body;
    if (it.kind == HallKind.tableRound) return d.distance <= b.width / 2 + 6;
    return l.dx.abs() <= b.width / 2 + 6 && l.dy.abs() <= b.height / 2 + 6;
  }

  static HallItem? hitItem(List<HallItem> items, Offset p) {
    HallItem? best;
    var bestRank = -1;
    for (final it in items) {
      if (!contains(it, p)) continue;
      final rank = it.isTable ? 2 : (it.isFlat ? 0 : 1);
      if (rank >= bestRank) {
        best = it;
        bestRank = rank;
      }
    }
    return best;
  }

  static (HallItem, int)? hitSeat(List<HallItem> items, Offset p, {double radius = 24}) {
    (HallItem, int)? best;
    var bd = radius;
    for (final it in items.where((i) => i.isTable)) {
      for (final s in it.seats) {
        final pos = it.c + hallRot2(s.off, it.rotation);
        final d = (pos - p).distance;
        if (d < bd) {
          bd = d;
          best = (it, s.index);
        }
      }
    }
    return best;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS 3D
// ═══════════════════════════════════════════════════════════════════════════
Widget hallZ(double z, Widget child) =>
    Transform(transform: Matrix4.translationValues(0, 0, z), child: child);

Widget hallShadow(double w, double h,
        {bool circle = false, double radius = 8, double o = 0.28}) =>
    hallZ(
      0,
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(o),
              blurRadius: 18,
              offset: const Offset(6, 10),
            ),
          ],
        ),
      ),
    );

List<Widget> hallCuboid({
  required double w,
  required double h,
  required double height,
  required Color side,
  required Color top,
  bool circle = false,
  double radius = 6,
  double base = 0,
  double step = 4,
  Gradient? topGradient,
  Color? rim,
}) {
  final n = math.max(1, (height / step).ceil());
  final out = <Widget>[];
  for (var i = 0; i <= n; i++) {
    final isTop = i == n;
    final t = i / n;
    final z = base + height * t;
    final c = isTop ? top : Color.lerp(Color.lerp(side, Colors.black, 0.18), side, t)!;
    out.add(hallZ(
      z,
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          color: (isTop && topGradient != null) ? null : c,
          gradient: isTop ? topGradient : null,
          border: isTop
              ? Border.all(color: rim ?? Colors.white.withOpacity(0.55), width: 0.9)
              : null,
        ),
      ),
    ));
  }
  return out;
}

Widget hallUpright(String t,
        {required double angle,
        double size = 11,
        Color color = HallC.ink,
        FontWeight w = FontWeight.w800,
        double ls = 0}) =>
    Transform.rotate(
      angle: angle,
      child: Text(
        t,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: size, fontWeight: w, color: color, letterSpacing: ls),
      ),
    );

// ═══════════════════════════════════════════════════════════════════════════
// SCÈNE COMPLÈTE
// ═══════════════════════════════════════════════════════════════════════════
class Hall3DView extends StatelessWidget {
  final HallCamera camera;
  final Size viewport;
  final List<HallItem> items;
  final Map<String, Map<int, HallGuest>> occupancy;
  final String? selectedId;
  final int? selectedSeat;
  final bool assigning;
  final Map<String, Set<int>> mySeats;
  final bool showInitials;
  final bool showWall;
  final bool evening;
  final bool hq;
  final double ambient;

  const Hall3DView({
    super.key,
    required this.camera,
    required this.viewport,
    required this.items,
    required this.occupancy,
    this.selectedId,
    this.selectedSeat,
    this.assigning = false,
    this.mySeats = const {},
    this.showInitials = true,
    this.showWall = true,
    this.evening = false,
    this.hq = true,
    this.ambient = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    final sc = math.sin(camera.rot), cc = math.cos(camera.rot);
    double depth(HallItem i) => sc * (i.c.dx - kRoomW / 2) + cc * (i.c.dy - kRoomH / 2);
    final flat = items.where((i) => i.isFlat).toList();
    final solids = items.where((i) => !i.isFlat).toList()
      ..sort((a, b) => depth(a).compareTo(depth(b)));
    final rn = ((camera.rot + math.pi) % (2 * math.pi)) - math.pi;
    final wall = showWall && camera.tilt > 0.3 && rn.abs() < 1.15;

    Widget placed(HallItem it) {
      final e = it.extent;
      final c = it.c;
      final sel = it.id == selectedId;
      return Positioned(
        left: c.dx - e.width / 2,
        top: c.dy - e.height / 2,
        width: e.width,
        height: e.height,
        child: Transform.rotate(
          angle: it.rotation,
          child: it.isTable
              ? HallTableView(
                  item: it,
                  occ: occupancy[it.id] ?? const {},
                  selected: sel,
                  selSeat: sel ? selectedSeat : null,
                  assigning: assigning,
                  camRot: camera.rot,
                  hq: hq,
                  mySeats: mySeats[it.id] ?? const {},
                  showInitials: showInitials,
                )
              : HallDecorView(
                  item: it,
                  selected: sel,
                  camRot: camera.rot,
                  hq: hq,
                  evening: evening,
                ),
        ),
      );
    }

    final room = SizedBox(
      width: kRoomW,
      height: kRoomH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (wall)
            Positioned(
              left: 0,
              top: -kWallH,
              width: kRoomW,
              height: kWallH,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()..rotateX(-math.pi / 2),
                child: CustomPaint(
                  size: const Size(kRoomW, kWallH),
                  painter: HallWallPainter(evening: evening),
                ),
              ),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: HallFloorPainter(
                ambient: ambient,
                evening: evening,
                glows: [for (final t in items.where((i) => i.isTable)) t.c],
              ),
            ),
          ),
          for (final it in flat) placed(it),
          for (final it in solids) placed(it),
        ],
      ),
    );

    return SizedBox(
      width: viewport.width,
      height: viewport.height,
      child: IgnorePointer(
        child: ClipRect(
          child: OverflowBox(
            minWidth: kRoomW,
            maxWidth: kRoomW,
            minHeight: kRoomH,
            maxHeight: kRoomH,
            child: Transform.translate(
              offset: camera.pan,
              child: Transform(
                alignment: Alignment.center,
                transform: camera.matrix(viewport),
                child: room,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TABLE 3D
// ═══════════════════════════════════════════════════════════════════════════
class HallTableView extends StatelessWidget {
  final HallItem item;
  final Map<int, HallGuest> occ;
  final bool selected;
  final int? selSeat;
  final bool assigning;
  final double camRot;
  final bool hq;
  final Set<int> mySeats;
  final bool showInitials;

  const HallTableView({
    super.key,
    required this.item,
    required this.occ,
    required this.selected,
    required this.selSeat,
    required this.assigning,
    required this.camRot,
    required this.hq,
    this.mySeats = const {},
    this.showInitials = true,
  });

  @override
  Widget build(BuildContext context) {
    final b = item.body;
    final round = item.kind == HallKind.tableRound;
    final zc = hallZoneColor(item.zone);
    final seats = item.seats;
    final cr = math.cos(item.rotation), sr = math.sin(item.rotation);
    final sc = math.sin(camRot), cc = math.cos(camRot);
    double depth(Offset o) => sc * (o.dx * cr - o.dy * sr) + cc * (o.dx * sr + o.dy * cr);

    final sorted = [...seats]..sort((a, c) => depth(a.off).compareTo(depth(c.off)));
    final back = sorted.where((s) => depth(s.off) < 0).toList();
    final front = sorted.where((s) => depth(s.off) >= 0).toList();
    final step = hq ? 4.0 : 9.0;
    final upAngle = -(camRot + item.rotation);

    Widget chair(HallSeat s) {
      final g = occ[s.index];
      final mine = mySeats.contains(s.index);
      final backNear = depth(Offset(math.sin(s.phi), -math.cos(s.phi))) > 0;
      return Transform.translate(
        offset: s.off,
        child: Transform.rotate(
          angle: s.phi,
          child: HallChairView(
            occupied: g != null || mine,
            initial: (showInitials && g != null) ? g.initial : '',
            color: mine ? HallC.red : (g == null ? zc : (g.isVip ? HallC.gold : zc)),
            selected: selSeat == s.index,
            pick: assigning && g == null && !mine,
            backNear: backNear,
            labelAngle: upAngle - s.phi,
            hq: hq,
          ),
        ),
      );
    }

    Offset plate(HallSeat s) {
      final dist = round ? kSeatGap + b.width / 2 * 0.26 : kSeatGap + 11;
      return s.off - Offset(math.sin(s.phi), -math.cos(s.phi)) * dist;
    }

    BoxDecoration shape({Gradient? gradient, Color? color, Border? border}) => BoxDecoration(
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : BorderRadius.circular(12),
          gradient: gradient,
          color: color,
          border: border,
        );

    final used = occ.length + mySeats.where((s) => !occ.containsKey(s)).length;

    final topSurface = SizedBox(
      width: b.width,
      height: b.height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: shape(
              gradient: const RadialGradient(colors: [Colors.white, Color(0xFFF3EEE0)]),
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
          for (final s in seats)
            Transform.translate(
              offset: plate(s),
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mySeats.contains(s.index)
                      ? HallC.red
                      : (occ[s.index] != null ? zc.withOpacity(0.85) : Colors.white),
                  border: Border.all(color: const Color(0xFFD8D0BC), width: 1.2),
                ),
              ),
            ),
          Transform.rotate(
            angle: upAngle,
            child: ConstrainedBox(
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
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: HallC.ink)),
                      Text('$used/${item.capacity}',
                          style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: used >= item.capacity ? HallC.rose : HallC.ink2)),
                    ],
                  ),
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
          hallZ(
            0,
            Container(
              width: b.width + 24,
              height: b.height + 24,
              decoration: BoxDecoration(
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: round ? null : BorderRadius.circular(18),
                border: Border.all(color: HallC.gold, width: 2.5),
                boxShadow: [BoxShadow(color: HallC.gold.withOpacity(0.5), blurRadius: 22, spreadRadius: 2)],
              ),
            ),
          ),
        hallShadow(b.width + 6, b.height + 6, circle: round, radius: 14),
        ...back.map(chair),
        ...hallCuboid(
          w: b.width,
          h: b.height,
          height: 24,
          side: HallC.clothSide,
          top: HallC.cloth,
          circle: round,
          radius: 12,
          step: step,
        ),
        hallZ(24.5, topSurface),
        ...front.map(chair),
        // Point rouge « votre place » : toujours au-dessus de tout
        for (final s in seats)
          if (mySeats.contains(s.index))
            Transform.translate(
              offset: s.off,
              child: hallZ(34, _MineMarker(labelAngle: upAngle)),
            ),
      ],
    );
  }
}

class _MineMarker extends StatefulWidget {
  final double labelAngle;
  const _MineMarker({required this.labelAngle});

  @override
  State<_MineMarker> createState() => _MineMarkerState();
}

class _MineMarkerState extends State<_MineMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: 0.6 + 1.4 * t,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HallC.red.withOpacity(0.55 * (1 - t)),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: HallC.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: HallC.red.withOpacity(0.8), blurRadius: 10)],
                ),
              ),
              Positioned(
                top: -22,
                child: UnconstrainedBox(
                  child: Transform.rotate(
                    angle: widget.labelAngle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HallC.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Text('VOUS',
                          style: GoogleFonts.inter(
                              fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HallChairView extends StatelessWidget {
  final bool occupied, selected, pick, backNear, hq;
  final String initial;
  final Color color;
  final double labelAngle;

  const HallChairView({
    super.key,
    required this.occupied,
    required this.selected,
    required this.pick,
    required this.backNear,
    required this.hq,
    required this.initial,
    required this.color,
    required this.labelAngle,
  });

  @override
  Widget build(BuildContext context) {
    final seatColor = occupied ? color : const Color(0xFFFBF8EF);
    final backRest = Positioned(
      left: 1,
      top: -1,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..translate(0.0, 0.0, 12.0)
          ..rotateX(math.pi / 2),
        child: Container(
          width: 24,
          height: 16,
          decoration: BoxDecoration(
            color: occupied ? Color.lerp(color, Colors.black, 0.12) : const Color(0xFFEFE8D6),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: HallC.gold, width: 1.1),
          ),
        ),
      ),
    );
    final glow = selected ? HallC.gold : (pick ? HallC.green : null);
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          hallShadow(24, 24, radius: 7, o: 0.22),
          ...hallCuboid(
            w: 22,
            h: 22,
            height: 11,
            side: const Color(0xFFB89B55),
            top: const Color(0xFFB89B55),
            radius: 6,
            step: hq ? 5.5 : 11,
          ),
          if (!backNear) backRest,
          hallZ(
            12.5,
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: seatColor,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selected ? Colors.white : (pick ? HallC.green : HallC.gold),
                  width: selected || pick ? 2.2 : 1.2,
                ),
                boxShadow: glow == null
                    ? null
                    : [BoxShadow(color: glow.withOpacity(0.7), blurRadius: 10, spreadRadius: 1)],
              ),
              child: initial.isNotEmpty
                  ? Transform.rotate(
                      angle: labelAngle,
                      child: Text(initial,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                    )
                  : null,
            ),
          ),
          if (backNear) backRest,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DÉCORS 3D
// ═══════════════════════════════════════════════════════════════════════════
class HallDecorView extends StatelessWidget {
  final HallItem item;
  final bool selected;
  final double camRot;
  final bool hq;
  final bool evening;

  const HallDecorView({
    super.key,
    required this.item,
    required this.selected,
    required this.camRot,
    required this.hq,
    required this.evening,
  });

  @override
  Widget build(BuildContext context) {
    final b = item.body;
    final up = -(camRot + item.rotation);
    final backNear = math.cos(camRot + item.rotation) < 0;
    final st = hq ? 3.0 : 7.0;

    final List<Widget> body;
    switch (item.kind) {
      case HallKind.stage:
        body = _stage(b, up, backNear, st);
        break;
      case HallKind.dance:
        body = [
          hallZ(
            0.6,
            SizedBox(
              width: b.width,
              height: b.height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: b, painter: HallDancePainter(evening: evening)),
                  hallUpright('PISTE DE DANSE', angle: up, size: 11, color: Colors.white, ls: 2),
                ],
              ),
            ),
          ),
        ];
        break;
      case HallKind.vip:
        body = [
          hallZ(
            0.6,
            Container(
              width: b.width,
              height: b.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [
                  HallC.gold.withOpacity(0.32),
                  HallC.gold.withOpacity(0.12),
                ]),
                border: Border.all(color: HallC.gold, width: 2),
              ),
              child: hallUpright('ZONE VIP', angle: up, size: 12, color: HallC.goldDark, ls: 3),
            ),
          ),
        ];
        break;
      case HallKind.entrance:
        body = _entrance(b, up, st);
        break;
      case HallKind.buffet:
        body = _buffet(b, up, st);
        break;
      case HallKind.bar:
        body = _bar(b, up, st);
        break;
      case HallKind.cake:
        body = _cake(b, st);
        break;
      case HallKind.dj:
        body = _dj(b, up, st);
        break;
      case HallKind.plant:
        body = _plant(b);
        break;
      default:
        body = const [];
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (selected)
          hallZ(
            0,
            Container(
              width: b.width + 16,
              height: b.height + 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HallC.gold, width: 2.5),
                boxShadow: [BoxShadow(color: HallC.gold.withOpacity(0.5), blurRadius: 22, spreadRadius: 2)],
              ),
            ),
          ),
        ...body,
      ],
    );
  }

  List<Widget> _stage(Size b, double up, bool backNear, double st) {
    final backdrop = Positioned(
      left: 12,
      top: 12,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..translate(0.0, 0.0, 18.0)
          ..rotateX(math.pi / 2),
        child: Container(
          width: b.width,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B2A57), Color(0xFF3B2A63)],
            ),
            border: const Border(bottom: BorderSide(color: HallC.gold, width: 3)),
          ),
          child: Text('THIX WEDDING',
              style: GoogleFonts.cinzel(
                  fontSize: 14, color: HallC.gold, letterSpacing: 5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
    return [
      hallShadow(b.width + 6, b.height + 6),
      if (!backNear) backdrop,
      ...hallCuboid(
        w: b.width,
        h: b.height,
        height: 18,
        side: const Color(0xFFCDBF9F),
        top: const Color(0xFFFBF7EC),
        radius: 8,
        step: st * 1.6,
      ),
      hallZ(
        18.5,
        Container(
          width: b.width,
          height: b.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF5E9C8)]),
            border: Border.all(color: HallC.gold, width: 1.6),
          ),
          child: hallUpright('SCÈNE', angle: up, size: 12, color: HallC.goldDark, ls: 6),
        ),
      ),
      if (backNear) backdrop,
    ];
  }

  List<Widget> _entrance(Size b, double up, double st) {
    Widget post(double dx) => Transform.translate(
          offset: Offset(dx, 0),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: hallCuboid(
              w: 10,
              h: 10,
              height: 62,
              side: const Color(0xFFE9DFC4),
              top: HallC.gold,
              radius: 3,
              step: st * 3,
            ),
          ),
        );
    return [
      hallZ(
        0.6,
        Container(
          width: b.width,
          height: b.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [Color(0xFF9F1239), Color(0xFFE11D48)]),
            border: Border.all(color: HallC.gold, width: 2),
          ),
          child: hallUpright('ENTRÉE', angle: up, size: 12, color: Colors.white, ls: 4),
        ),
      ),
      post(-b.width / 2 + 5),
      post(b.width / 2 - 5),
      hallZ(
        62,
        Container(
          width: b.width,
          height: 8,
          decoration: BoxDecoration(
            color: HallC.gold,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: HallC.gold.withOpacity(0.6), blurRadius: 8)],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buffet(Size b, double up, double st) {
    final dishes = math.max(3, (b.width / 48).floor());
    return [
      hallShadow(b.width + 4, b.height + 4),
      ...hallCuboid(
        w: b.width,
        h: b.height,
        height: 20,
        side: HallC.clothSide,
        top: HallC.cloth,
        radius: 8,
        step: st * 1.6,
      ),
      hallZ(
        20.6,
        SizedBox(
          width: b.width,
          height: b.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < dishes; i++)
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [Colors.white, Color(0xFFC8CDD6)]),
                    border: Border.all(color: const Color(0xFF9AA3B2)),
                  ),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: [
                        const Color(0xFFF59E0B),
                        const Color(0xFFE11D48),
                        const Color(0xFF16A34A),
                        const Color(0xFF7C3AED),
                      ][i % 4],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _bar(Size b, double up, double st) {
    return [
      hallShadow(b.width + 4, b.height + 4),
      ...hallCuboid(
        w: b.width,
        h: b.height,
        height: 28,
        side: const Color(0xFF6B4A33),
        top: const Color(0xFF2A1B14),
        radius: 8,
        step: st * 2,
        topGradient: const LinearGradient(colors: [Color(0xFF3A271C), Color(0xFF1B110C)]),
        rim: HallC.gold,
      ),
      hallZ(
        28.6,
        SizedBox(
          width: b.width,
          height: b.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: [
                      const Color(0xFF16A34A),
                      const Color(0xFFF59E0B),
                      const Color(0xFF3B82F6),
                      const Color(0xFFE11D48),
                      const Color(0xFF7C3AED),
                    ][i],
                    boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 3)],
                  ),
                ),
            ],
          ),
        ),
      ),
      hallZ(29, hallUpright('BAR', angle: up, size: 10, color: HallC.gold, ls: 3)),
    ];
  }

  List<Widget> _cake(Size b, double st) {
    return [
      hallShadow(b.width, b.width, circle: true),
      ...hallCuboid(w: 46, h: 46, height: 12, side: HallC.clothSide, top: HallC.cloth, circle: true, step: st * 2),
      ...hallCuboid(w: 38, h: 38, height: 8, base: 12, side: const Color(0xFFFFE4EC), top: const Color(0xFFFFF1F5), circle: true, step: st * 2),
      ...hallCuboid(w: 28, h: 28, height: 8, base: 20, side: const Color(0xFFFFE4EC), top: const Color(0xFFFFF7FA), circle: true, step: st * 2),
      ...hallCuboid(w: 18, h: 18, height: 8, base: 28, side: const Color(0xFFFFE4EC), top: Colors.white, circle: true, step: st * 2),
      hallZ(
        37,
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: HallC.rose),
        ),
      ),
    ];
  }

  List<Widget> _dj(Size b, double up, double st) {
    Widget speaker(double dx) => Transform.translate(
          offset: Offset(dx, 0),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: hallCuboid(
              w: 26,
              h: 26,
              height: 42,
              side: const Color(0xFF1F2937),
              top: const Color(0xFF111827),
              radius: 5,
              step: st * 3,
            ),
          ),
        );
    return [
      hallShadow(b.width, b.height),
      speaker(-b.width / 2 + 14),
      speaker(b.width / 2 - 14),
      ...hallCuboid(
        w: b.width - 64,
        h: b.height,
        height: 18,
        side: const Color(0xFF374151),
        top: const Color(0xFF111827),
        radius: 6,
        step: st * 2,
      ),
      hallZ(
        18.6,
        SizedBox(
          width: b.width - 64,
          height: b.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 6,
                  height: 22,
                  decoration: BoxDecoration(
                    color: [HallC.rose, HallC.gold, HallC.blue, HallC.green][i],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _plant(Size b) {
    return [
      hallShadow(24, 24, circle: true),
      ...hallCuboid(w: 20, h: 20, height: 14, side: const Color(0xFFB45309), top: const Color(0xFF7C4A21), circle: true, step: 7),
      hallZ(18, Container(width: 30, height: 30, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF15803D)))),
      hallZ(26, Container(width: 25, height: 25, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF16A34A)))),
      hallZ(34, Container(width: 19, height: 19, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E)))),
      hallZ(41, Container(width: 11, height: 11, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4ADE80)))),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PEINTURES
// ═══════════════════════════════════════════════════════════════════════════
class HallFloorPainter extends CustomPainter {
  final double ambient;
  final bool evening;
  final List<Offset> glows;
  HallFloorPainter({required this.ambient, required this.evening, required this.glows});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F5EE), Color(0xFFEDE6D6)],
        ).createShader(rect),
    );
    const t = 80.0;
    final rnd = math.Random(7);
    for (var gy = 0; gy * t < size.height; gy++) {
      for (var gx = 0; gx * t < size.width; gx++) {
        final alt = (gx + gy).isEven;
        final r = Rect.fromLTWH(gx * t, gy * t, t, t);
        canvas.drawRect(
          r,
          Paint()
            ..color = (alt ? Colors.white : const Color(0xFFEFE8D8)).withOpacity(alt ? 0.35 : 0.45),
        );
        final p = Path()
          ..moveTo(r.left + rnd.nextDouble() * t, r.top)
          ..quadraticBezierTo(r.left + rnd.nextDouble() * t, r.center.dy, r.left + rnd.nextDouble() * t, r.bottom);
        canvas.drawPath(
          p,
          Paint()
            ..color = const Color(0xFFB9AE95).withOpacity(0.10 + rnd.nextDouble() * 0.06)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke,
        );
      }
    }
    final joint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 1.6;
    final joint2 = Paint()
      ..color = const Color(0xFFCFC5AE).withOpacity(0.7)
      ..strokeWidth = 0.6;
    for (var x = 0.0; x <= size.width; x += t) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), joint);
      canvas.drawLine(Offset(x + 1.2, 0), Offset(x + 1.2, size.height), joint2);
    }
    for (var y = 0.0; y <= size.height; y += t) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), joint);
      canvas.drawLine(Offset(0, y + 1.2), Offset(size.width, y + 1.2), joint2);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.30), Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.14)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    for (final g in glows) {
      canvas.drawCircle(
        g,
        120,
        Paint()
          ..shader = RadialGradient(colors: [
            (evening ? const Color(0xFFFFD27A) : Colors.white).withOpacity(evening ? 0.32 : 0.22),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: g, radius: 120)),
      );
    }
    final dark = (1 - ambient) * 0.5 + (evening ? 0.34 : 0.0);
    if (dark > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF0B1030).withOpacity(dark.clamp(0.0, 0.8).toDouble()),
      );
    }
    canvas.drawRect(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFD9CFB6),
    );
  }

  @override
  bool shouldRepaint(covariant HallFloorPainter old) =>
      old.ambient != ambient || old.evening != evening || !listEquals(old.glows, glows);
}

class HallWallPainter extends CustomPainter {
  final bool evening;
  HallWallPainter({required this.evening});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: evening
              ? const [Color(0xFF2B2740), Color(0xFF3A3556)]
              : const [Color(0xFFFFFDF8), Color(0xFFF1EADB)],
        ).createShader(r),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32),
      Paint()..color = (evening ? const Color(0xFF4A4468) : Colors.white).withOpacity(0.75),
    );
    for (var x = 30.0; x < size.width - 60; x += 100) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height * 0.72, 76, size.height * 0.2), const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = HallC.gold.withOpacity(0.45),
      );
    }
    const n = 4;
    const ww = 100.0;
    final gap = (size.width - n * ww) / (n + 1);
    for (var i = 0; i < n; i++) {
      final left = gap + i * (ww + gap);
      const top = 36.0;
      final h = size.height * 0.56;
      final win = Path()
        ..moveTo(left, top + h)
        ..lineTo(left, top + ww / 2)
        ..arcToPoint(Offset(left + ww, top + ww / 2), radius: const Radius.circular(ww / 2), clockwise: true)
        ..lineTo(left + ww, top + h)
        ..close();
      canvas.drawPath(
        win,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: evening
                ? const [Color(0xFF141A3A), Color(0xFF2A2F5E)]
                : const [Color(0xFFBFE0FF), Color(0xFFEAF6FF)],
          ).createShader(Rect.fromLTWH(left, top, ww, h)),
      );
      final frame = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = HallC.gold.withOpacity(0.9);
      canvas.drawPath(win, frame);
      canvas.drawLine(Offset(left + ww / 2, top), Offset(left + ww / 2, top + h), frame..strokeWidth = 1.6);
      canvas.drawLine(Offset(left, top + h * 0.45), Offset(left + ww, top + h * 0.45), frame);
      for (final side in [-1.0, 1.0]) {
        final cx = side < 0 ? left - 10 : left + ww + 10;
        final drape = RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 9, top + 6, 18, h - 6), const Radius.circular(8));
        canvas.drawRRect(
          drape,
          Paint()
            ..shader = LinearGradient(colors: [
              Colors.white.withOpacity(evening ? 0.35 : 0.95),
              const Color(0xFFEADFC4),
            ]).createShader(drape.outerRect),
        );
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 14), Paint()..color = HallC.gold.withOpacity(0.85));
    canvas.drawRect(Rect.fromLTWH(0, size.height - 10, size.width, 10), Paint()..color = const Color(0xFFD9CFB6));
  }

  @override
  bool shouldRepaint(covariant HallWallPainter old) => old.evening != evening;
}

class HallDancePainter extends CustomPainter {
  final bool evening;
  HallDancePainter({required this.evening});

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 8, rows = 5;
    final tw = size.width / cols, th = size.height / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final even = (r + c).isEven;
        final col = evening
            ? (even ? const Color(0xFF7C3AED) : const Color(0xFF2563EB))
            : (even ? const Color(0xFFDDEBFF) : Colors.white);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(c * tw + 1.5, r * th + 1.5, tw - 3, th - 3), const Radius.circular(3)),
          Paint()..color = col.withOpacity(0.88),
        );
      }
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.35), Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = HallC.gold,
    );
  }

  @override
  bool shouldRepaint(covariant HallDancePainter old) => old.evening != evening;
}
