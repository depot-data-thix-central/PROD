// lib/presentation/thix_market/pages/supermarket_space_widgets.dart
// ============================================================================
// SUPERMARCHÉ 3D — Monde 3D + design system (fichier 2/2)
// Allées pseudo-3D, rayons, frigos, produits, fiche produit
// ============================================================================

import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';

// ============================================================================
// DESIGN TOKENS — palette marketplace : blanc pur + accent orange
// ============================================================================
const Color kBg = Colors.white;
const Color kSurface = Color(0xFFF8FAFC);
const Color kInk = Color(0xFF0F172A);
const Color kInkSoft = Color(0xFF475569);
const Color kInkMuted = Color(0xFF94A3B8);
const Color kBorder = Color(0xFFE2E8F0);

const Color kAccent = Color(0xFFF97316);
const Color kAccentDark = Color(0xFFC2410C);
const Color kAccentSoft = Color(0xFFFFEDD5);

const Color kDanger = Color(0xFFEF4444);
const Color kSuccess = Color(0xFF16A34A);
const Color kGold = Color(0xFFE3B848);

// Couleurs de rayons (cohérence métier)
const Color kSmRed = Color(0xFFD93025);
const Color kSmRedDark = Color(0xFFB3261E);
const Color _kWood = Color(0xFF9A7B52);
const Color _kWoodDark = Color(0xFF7A5D3A);
const Color _kMetalWhite = Color(0xFFFAFAFA);
const Color _kMetalEdge = Color(0xFFE3E6EA);
const Color _kMeshWire = Color(0xFFC9CED6);
const Color _kPerfDot = Color(0xFFD5DAE0);

// Dimensions partagées
const double kSmViewport = 0.86;
const double kSmLevelH = 128;
const double kSmRailH = 18;
const double kSmSignH = 72;
const double kSmDoorH = 24 + kSmLevelH * 2 + 3 + 6;
const double kSmDoorGap = 12;
const double kSmHeroH = 196;
const double kSmCeilH = 40;
const int kSmCols = 3;
const int kSmFloorSize = 4;
const Duration kSmDbTimeout = Duration(seconds: 15);

// ============================================================================
// HELPERS
// ============================================================================
String smTr(AppLocalizations l10n, String key, String fb) {
  final v = l10n.t(key);
  return (v.isEmpty || v == key) ? fb : v;
}

String smFold(String s) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

bool _smWord(String n, String w) => RegExp('(^|[^a-z])$w([^a-z]|\$)').hasMatch(n);
int smStockOf(SupermarketProduct p) => ((p.stock as num?) ?? 0).toInt();
int? smMemW(int w) => kIsWeb ? null : w;
String smPid(SupermarketProduct p) => p.id.toString();
String smFloorName(int i) => i == 0 ? 'RDC' : 'Étage $i';
String smFloorShort(int i) => i == 0 ? 'RDC' : '$i';

String smFmtDate(dynamic v) {
  if (v == null) return '—';
  final s = v.toString();
  try {
    final d = DateTime.parse(s);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return s;
  }
}

enum SmZone { standard, produce, fresh, frozen, drinks }

SmZone smZoneOf(String name) {
  final n = smFold(name);
  if (n.contains('surg') || n.contains('glac') || n.contains('frozen')) return SmZone.frozen;
  const drinks = [
    'boisson', 'drink', 'soda', 'biere', 'beverage', 'alcool',
    'liqueur', 'cocktail', 'limonade', 'brasserie', 'sirop',
  ];
  for (final k in drinks) {
    if (n.contains(k)) return SmZone.drinks;
  }
  if (_smWord(n, 'eau') || _smWord(n, 'eaux') || _smWord(n, 'jus') || _smWord(n, 'vin') || _smWord(n, 'vins')) {
    return SmZone.drinks;
  }
  const fresh = [
    'frais', 'lait', 'cremerie', 'boucher', 'viande', 'poisson',
    'charcut', 'traiteur', 'fromage', 'yaourt', 'oeuf',
  ];
  for (final k in fresh) {
    if (n.contains(k)) return SmZone.fresh;
  }
  const produce = ['fruit', 'legum', 'boulang', 'pain', 'patiss', 'primeur'];
  for (final k in produce) {
    if (n.contains(k)) return SmZone.produce;
  }
  return SmZone.standard;
}

bool smIsCooler(SmZone z) => z == SmZone.frozen || z == SmZone.fresh || z == SmZone.drinks;

String smZoneTagline(SmZone z) {
  switch (z) {
    case SmZone.frozen:
      return 'SURGELÉS · -18°C';
    case SmZone.fresh:
      return 'FRAIS · +4°C';
    case SmZone.drinks:
      return 'BOISSONS · +2°C';
    case SmZone.produce:
      return 'FRAIS DU JOUR';
    case SmZone.standard:
      return 'RAYON';
  }
}

String smZoneTemp(SmZone z) {
  switch (z) {
    case SmZone.frozen:
      return '-18°C';
    case SmZone.drinks:
      return '+2°C';
    default:
      return '+4°C';
  }
}

Color smZoneAccent(SmZone z) {
  switch (z) {
    case SmZone.frozen:
      return const Color(0xFF0277BD);
    case SmZone.drinks:
      return const Color(0xFF00838F);
    default:
      return kSuccess;
  }
}

List<Color> smZoneInterior(SmZone z) {
  switch (z) {
    case SmZone.frozen:
      return const [Color(0xFFE1F5FE), Color(0xFFB3E5FC)];
    case SmZone.drinks:
      return const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)];
    default:
      return const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)];
  }
}

List<Color> smZoneGlass(SmZone z) {
  switch (z) {
    case SmZone.frozen:
      return const [Color(0xC7E3F2FD), Color(0xBFB3E5FC)];
    case SmZone.drinks:
      return const [Color(0xC7E0F7FA), Color(0xBFB2EBF2)];
    default:
      return const [Color(0xC7E8F5E9), Color(0xBFC8E6C9)];
  }
}

// ============================================================================
// TAP-SCALE (feedback tactile)
// ============================================================================
class SmTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const SmTapScale({super.key, required this.child, this.onTap});

  @override
  State<SmTapScale> createState() => _SmTapScaleState();
}

class _SmTapScaleState extends State<SmTapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// PAINTERS : mur, plafond, spots, perforations, grillage, givre
// ============================================================================
class SmBackdropPainter extends CustomPainter {
  const SmBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.80;

    final wallRect = Rect.fromLTWH(0, 0, w, horizon);
    canvas.drawRect(
      wallRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ).createShader(wallRect),
    );

    final seam = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(w * i / 4, kSmCeilH), Offset(w * i / 4, horizon), seam);
    }

    canvas.drawRect(Rect.fromLTWH(0, horizon - 5, w, 5), Paint()..color = const Color(0xFFCBD5E1));

    final floorRect = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
      floorRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
        ).createShader(floorRect),
    );

    canvas.save();
    canvas.clipRect(floorRect);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1;
    final vp = Offset(w / 2, horizon - (h - horizon) * 1.2);
    for (var i = -6; i <= 6; i++) {
      canvas.drawLine(vp, Offset(w / 2 + i * w * 0.22, h), line);
    }
    for (var k = 1; k <= 6; k++) {
      final y = horizon + (h - horizon) * math.pow(k / 6, 2).toDouble();
      canvas.drawLine(Offset(0, y), Offset(w, y), line);
    }
    canvas.restore();

    for (final fx in const [0.14, 0.38, 0.62, 0.86]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * fx, horizon + (h - horizon) * 0.38), width: w * 0.30, height: (h - horizon) * 0.46),
        Paint()..color = Colors.white.withOpacity(0.28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SmCeilingPainter extends CustomPainter {
  const SmCeilingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final ceilRect = Rect.fromLTWH(0, 0, w, kSmCeilH);
    canvas.drawRect(
      ceilRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
        ).createShader(ceilRect),
    );
    final tile = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.3)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(Offset(w * i / 6, 0), Offset(w * i / 6, kSmCeilH), tile);
    }
    canvas.drawRect(Rect.fromLTWH(0, kSmCeilH - 2, w, 2), Paint()..color = const Color(0xFF94A3B8));

    final shRect = Rect.fromLTWH(0, kSmCeilH, w, 16);
    canvas.drawRect(
      shRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.08), Colors.black.withOpacity(0.0)],
        ).createShader(shRect),
    );

    final railY = kSmCeilH * 0.38;
    canvas.drawRect(Rect.fromLTWH(0, railY, w, 3), Paint()..color = const Color(0xFF64748B));

    for (final fx in const [0.14, 0.38, 0.62, 0.86]) {
      final cx = w * fx;
      final cy = railY + 3;

      final coneBottom = h * 0.60;
      final coneRect = Rect.fromLTWH(cx - w * 0.16, cy, w * 0.32, coneBottom - cy);
      final cone = Path()
        ..moveTo(cx - 6, cy + 8)
        ..lineTo(cx + 6, cy + 8)
        ..lineTo(cx + w * 0.16, coneBottom)
        ..lineTo(cx - w * 0.16, coneBottom)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.24), Colors.white.withOpacity(0.0)],
          ).createShader(coneRect),
      );

      canvas.drawRect(Rect.fromLTWH(cx - 1.5, cy, 3, 5), Paint()..color = const Color(0xFF475569));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 8), width: 14, height: 8), const Radius.circular(3)),
        Paint()..color = const Color(0xFF334155),
      );

      final glowC = Offset(cx, cy + 12);
      canvas.drawCircle(
        glowC,
        16,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.0)],
          ).createShader(Rect.fromCircle(center: glowC, radius: 16)),
      );
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 12), width: 9, height: 3.5), Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PerfPainter extends CustomPainter {
  const _PerfPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[];
    for (var y = 5.0; y < size.height; y += 8) {
      for (var x = 5.0; x < size.width; x += 8) {
        pts.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, pts, Paint()
      ..color = _kPerfDot
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MeshPainter extends CustomPainter {
  const _MeshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kMeshWire
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var y = 0.0; y <= size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = 0.0; x <= size.width; x += 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrostPainter extends CustomPainter {
  const _FrostPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint()..color = Colors.white.withOpacity(0.55);
    for (var i = 0; i < 40; i++) {
      final edge = rnd.nextDouble();
      final x = i.isEven ? rnd.nextDouble() * size.width * 0.28 : size.width - rnd.nextDouble() * size.width * 0.28;
      final y = edge * size.height;
      canvas.drawCircle(Offset(x, y), 0.7 + rnd.nextDouble() * 2.0, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ALLÉE EN PERSPECTIVE
// ============================================================================
class SmAisleCarouselItem extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;
  const SmAisleCarouselItem({super.key, required this.controller, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: RepaintBoundary(child: child),
      builder: (_, ch) {
        var current = controller.initialPage.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          current = controller.page ?? current;
        }
        final delta = (index - current).clamp(-1.5, 1.5);
        final angle = delta * 0.42;
        final scale = 1 - delta.abs() * 0.08;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle)
            ..scale(scale, scale, 1.0),
          child: Opacity(opacity: (1 - delta.abs() * 0.25).clamp(0.4, 1.0), child: ch),
        );
      },
    );
  }
}

class SmAislePage extends StatefulWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final List<SupermarketProduct> products;
  final SmZone zone;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;
  final VoidCallback onOpenAisle;

  const SmAislePage({
    super.key,
    required this.dept,
    required this.aisleNumber,
    required this.products,
    required this.zone,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
    required this.onOpenAisle,
  });

  @override
  State<SmAislePage> createState() => _SmAislePageState();
}

class _SmAislePageState extends State<SmAislePage> {
  final ScrollController _scroll = ScrollController();

  bool get _cooler => smIsCooler(widget.zone);
  int get _perUnit => _cooler ? kSmCols * 2 : kSmCols;
  double get _unitExtent => _cooler ? kSmDoorH + kSmDoorGap : kSmLevelH + kSmRailH;

  @override
  void initState() {
    super.initState();
    widget.highlight.addListener(_onHighlight);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onHighlight());
  }

  @override
  void dispose() {
    widget.highlight.removeListener(_onHighlight);
    _scroll.dispose();
    super.dispose();
  }

  void _onHighlight() {
    final id = widget.highlight.value;
    if (id == null) return;
    final idx = widget.products.indexWhere((p) => smPid(p) == id);
    if (idx < 0) return;
    final unit = idx ~/ _perUnit;
    final target = kSmSignH + unit * _unitExtent - 30;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        target.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    final units = (products.length / _perUnit).ceil();
    final total = (units == 0 ? 1 : units) + 2;

    return ListView.builder(
      controller: _scroll,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(2, kSmCeilH, 2, 110),
      itemCount: total,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return SmAisleSign(
            dept: widget.dept,
            aisleNumber: widget.aisleNumber,
            count: products.length,
            zone: widget.zone,
            onTap: widget.onOpenAisle,
          );
        }
        if (i == total - 1) return const SmFixtureBase();
        if (units == 0) return SmEmptyAisle(color: widget.dept.color);

        final u = i - 1;
        final slice = products.skip(u * _perUnit).take(_perUnit).toList();

        if (_cooler) {
          return Padding(
            padding: const EdgeInsets.only(bottom: kSmDoorGap),
            child: SmCoolerDoor(
              products: slice,
              zone: widget.zone,
              highlight: widget.highlight,
              added: widget.added,
              onTapProduct: widget.onTapProduct,
              onAdd: widget.onAdd,
            ),
          );
        }

        final wood = widget.zone == SmZone.produce;
        return SmGondolaLevel(
          products: slice,
          rail: wood ? _kWood : kSmRed,
          railDark: wood ? _kWoodDark : kSmRedDark,
          highlight: widget.highlight,
          added: widget.added,
          onTapProduct: widget.onTapProduct,
          onAdd: widget.onAdd,
        );
      },
    );
  }
}

// ============================================================================
// PANNEAU D'ALLÉE (enseigne suspendue)
// ============================================================================
class SmAisleSign extends StatelessWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final int count;
  final SmZone zone;
  final VoidCallback onTap;
  const SmAisleSign({
    super.key,
    required this.dept,
    required this.aisleNumber,
    required this.count,
    required this.zone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(dept.color, Colors.black, 0.28)!;
    return SizedBox(
      height: kSmSignH,
      child: Column(
        children: [
          SizedBox(
            height: 10,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF334155), shape: BoxShape.circle)),
                ],
              ),
            ),
          ),
          Expanded(
            child: SmTapScale(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [dept.color, dark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                  boxShadow: [BoxShadow(color: dept.color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$aisleNumber',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dept.color)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(dept.icon, size: 17, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dept.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2)),
                          Text('ALLÉE $aisleNumber · ${smZoneTagline(zone)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.85), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(8)),
                      child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SmFixtureBase extends StatelessWidget {
  const SmFixtureBase({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(color: Color(0xFF64748B), borderRadius: BorderRadius.vertical(bottom: Radius.circular(5))),
        ),
        const SizedBox(height: 3),
        Container(
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        ),
      ],
    );
  }
}

class SmEmptyAisle extends StatelessWidget {
  final Color color;
  const SmEmptyAisle({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 32, color: color.withOpacity(0.5)),
          const SizedBox(height: 6),
          const Text('Rayon en réapprovisionnement',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kInkMuted)),
        ],
      ),
    );
  }
}

// ============================================================================
// ÉTAGÈRE (gondole) + RAIL + RANGÉE DE SLOTS
// ============================================================================
class SmGondolaLevel extends StatelessWidget {
  final List<SupermarketProduct> products;
  final Color rail;
  final Color railDark;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;

  const SmGondolaLevel({
    super.key,
    required this.products,
    required this.rail,
    required this.railDark,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSmLevelH + kSmRailH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 8, child: CustomPaint(painter: _MeshPainter())),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF1F3F6), _kMetalWhite],
                ),
                border: Border.symmetric(vertical: BorderSide(color: _kMetalEdge)),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _PerfPainter())),
                  Column(
                    children: [
                      SizedBox(
                        height: kSmLevelH,
                        child: SmSlotsRow(
                          products: products,
                          highlight: highlight,
                          added: added,
                          onTapProduct: onTapProduct,
                          onAdd: onAdd,
                        ),
                      ),
                      _Rail(color: rail, dark: railDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8, child: CustomPaint(painter: _MeshPainter())),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final Color color;
  final Color dark;
  const _Rail({required this.color, required this.dark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSmRailH,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 2,
            right: 2,
            height: 6,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFEDEFF2)],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1))],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 12,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, dark]),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: dark.withOpacity(0.35), blurRadius: 4, offset: const Offset(0, 2))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SmSlotsRow extends StatelessWidget {
  final List<SupermarketProduct> products;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;

  const SmSlotsRow({
    super.key,
    required this.products,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(kSmCols, (c) {
        if (c >= products.length) return const Expanded(child: SizedBox.shrink());
        return Expanded(
          child: SmProductSlot(
            product: products[c],
            highlight: highlight,
            added: added,
            onTap: onTapProduct,
            onAdd: onAdd,
          ),
        );
      }),
    );
  }
}

// ============================================================================
// FRIGO / CONGÉLATEUR / BOISSONS
// ============================================================================
class SmCoolerDoor extends StatefulWidget {
  final List<SupermarketProduct> products;
  final SmZone zone;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;

  const SmCoolerDoor({
    super.key,
    required this.products,
    required this.zone,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
  });

  @override
  State<SmCoolerDoor> createState() => _SmCoolerDoorState();
}

class _SmCoolerDoorState extends State<SmCoolerDoor> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.highlight.addListener(_checkHighlight);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkHighlight());
  }

  @override
  void dispose() {
    widget.highlight.removeListener(_checkHighlight);
    _ctrl.dispose();
    super.dispose();
  }

  void _checkHighlight() {
    final id = widget.highlight.value;
    if (id == null || _open) return;
    if (widget.products.any((p) => smPid(p) == id)) _setOpen(true);
  }

  void _setOpen(bool v) {
    if (!mounted || _open == v) return;
    HapticFeedback.mediumImpact();
    setState(() => _open = v);
    if (v) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  List<SupermarketProduct> _row(int r) => widget.products.skip(r * kSmCols).take(kSmCols).toList();

  Widget _tempChip(Color color) {
    final frozen = widget.zone == SmZone.frozen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(frozen ? Icons.ac_unit_rounded : Icons.thermostat_rounded, size: 10, color: color),
          const SizedBox(width: 2),
          Text(smZoneTemp(widget.zone), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = smZoneAccent(widget.zone);
    final interiorColors = smZoneInterior(widget.zone);
    final glassColors = smZoneGlass(widget.zone);

    final interior = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: interiorColors),
      ),
      child: Column(
        children: [
          Container(
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.0)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _tempChip(accent),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _open ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: SmTapScale(
                      onTap: _open ? () => _setOpen(false) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(7)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text('Fermer', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: kSmLevelH,
            child: SmSlotsRow(
              products: _row(0),
              highlight: widget.highlight,
              added: widget.added,
              onTapProduct: widget.onTapProduct,
              onAdd: widget.onAdd,
            ),
          ),
          Container(height: 2, color: Colors.white.withOpacity(0.85)),
          SizedBox(
            height: kSmLevelH,
            child: SmSlotsRow(
              products: _row(1),
              highlight: widget.highlight,
              added: widget.added,
              onTapProduct: widget.onTapProduct,
              onAdd: widget.onAdd,
            ),
          ),
        ],
      ),
    );

    final doorPanel = SmTapScale(
      onTap: () => _setOpen(true),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: glassColors),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _FrostPainter())),
            Positioned(top: 6, left: 8, child: _tempChip(accent)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.75), shape: BoxShape.circle),
                    child: Icon(Icons.touch_app_rounded, size: 24, color: accent),
                  ),
                  const SizedBox(height: 5),
                  Text('Ouvrir', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: accent)),
                ],
              ),
            ),
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 5,
                  height: 78,
                  decoration: BoxDecoration(color: const Color(0xFF475569), borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      height: kSmDoorH,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF94A3B8), width: 2.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(11), child: interior)),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ctrl,
                child: doorPanel,
                builder: (_, child) {
                  final t = Curves.easeInOutCubic.transform(_ctrl.value);
                  return IgnorePointer(
                    ignoring: _open,
                    child: Opacity(
                      opacity: (1 - (t - 0.8).clamp(0.0, 0.2) * 3).clamp(0.0, 1.0),
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0008)
                          ..rotateY(-t * 1.2),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRODUIT SUR L'ÉTAGÈRE — carte blanche + bouton rond « + »
// ============================================================================
class SmProductSlot extends StatelessWidget {
  final SupermarketProduct product;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTap;
  final ValueChanged<SupermarketProduct> onAdd;

  const SmProductSlot({
    super.key,
    required this.product,
    required this.highlight,
    required this.added,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = smStockOf(p) <= 0;

    return ValueListenableBuilder<String?>(
      valueListenable: highlight,
      builder: (_, hl, child) {
        final on = hl == smPid(p);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: on ? kGold : kBorder, width: on ? 1.8 : 1),
            boxShadow: [
              BoxShadow(
                color: on ? kGold.withOpacity(0.55) : const Color(0x120F172A),
                blurRadius: on ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: SmTapScale(
        onTap: () => onTap(p),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(child: _image(p, out)),
              const SizedBox(height: 3),
              SizedBox(
                height: 11,
                width: double.infinity,
                child: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: kInk),
                ),
              ),
              SizedBox(
                height: 14,
                child: FittedBox(fit: BoxFit.scaleDown, child: _price(p, out)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(SupermarketProduct p, bool out) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Container(
              color: kSurface,
              child: p.hasPhotos
                  ? CachedNetworkImage(
                      imageUrl: p.mainPhoto,
                      fit: BoxFit.cover,
                      memCacheWidth: smMemW(240),
                      fadeInDuration: const Duration(milliseconds: 120),
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) =>
                          const Center(child: Icon(Icons.inventory_2_rounded, size: 18, color: kInkMuted)),
                    )
                  : const Center(child: Icon(Icons.inventory_2_rounded, size: 18, color: kInkMuted)),
            ),
          ),
        ),
        if (out)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(9)),
              child: const Center(
                child: Text('RUPTURE', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.grey)),
              ),
            ),
          ),
        if (p.onPromo)
          Positioned(
            top: 3,
            left: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(color: kSmRed, borderRadius: BorderRadius.circular(5)),
              child: Text('-${p.promoPercent}%',
                  style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        if (p.isPerishable)
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: p.isExpired ? Colors.grey : (p.isFreshSoon ? Colors.orange : kSuccess),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                p.isExpired ? 'EXPIRÉ' : (p.isFreshSoon ? 'J-${p.daysToExpiry}' : 'FRAIS'),
                style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
        if (!out)
          Positioned(
            bottom: 3,
            right: 3,
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: added,
              builder: (_, set, __) {
                final done = set.contains(smPid(p));
                return SmTapScale(
                  onTap: () => onAdd(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done ? kSuccess : kAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [BoxShadow(color: (done ? kSuccess : kAccent).withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Icon(done ? Icons.check_rounded : Icons.add_rounded, size: 14, color: Colors.white),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _price(SupermarketProduct p, bool out) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${p.priceLabel()} ${p.currency}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: out ? kInkMuted : (p.onPromo ? kSmRed : kAccentDark),
          ),
        ),
        if (p.onPromo) ...[
          const SizedBox(width: 3),
          Text('${p.price}',
              style: const TextStyle(fontSize: 7.5, color: kInkMuted, decoration: TextDecoration.lineThrough)),
        ],
      ],
    );
  }
}

// ============================================================================
// FICHE PRODUIT RAPIDE (avec quantité)
// ============================================================================
class SmProductQuickView extends StatefulWidget {
  final SupermarketProduct product;
  final AppLocalizations l10n;
  final ValueChanged<int> onAdd;
  const SmProductQuickView({super.key, required this.product, required this.l10n, required this.onAdd});

  @override
  State<SmProductQuickView> createState() => _SmProductQuickViewState();
}

class _SmProductQuickViewState extends State<SmProductQuickView> {
  int _qty = 1;

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return SmTapScale(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: onTap == null ? Colors.transparent : Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: onTap == null ? kInkMuted : kInk),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final stock = smStockOf(p);
    final out = stock <= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SmPhotoGallery(photos: p.photos),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(p.title,
                            style: const TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w900, color: kInk)),
                      ),
                      if (p.onPromo)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: kSmRed, borderRadius: BorderRadius.circular(9)),
                          child: Text('-${p.promoPercent}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${p.priceLabel()} ${p.currency}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: p.onPromo ? kSmRed : kAccent)),
                      if (p.onPromo) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('${p.price} ${p.currency}',
                              style: const TextStyle(fontSize: 12, color: kInkMuted, decoration: TextDecoration.lineThrough)),
                        ),
                      ],
                      if (p.unit != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('/ ${p.unit}', style: const TextStyle(fontSize: 12, color: kInkMuted)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SmInfoGrid(product: p),
                  const SizedBox(height: 14),
                  if (p.barcode != null && p.barcode!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        children: [
                          BarcodeWidget(barcode: Barcode.code128(), data: p.barcode!, height: 44, drawText: false, color: kInk),
                          const SizedBox(height: 6),
                          Text(p.barcode!,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 2, color: kInkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    Text(smTr(widget.l10n, 'sm_description', 'Description'),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: kInk)),
                    const SizedBox(height: 6),
                    Text(p.description!, style: const TextStyle(fontSize: 12.5, color: kInkSoft, height: 1.5)),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(ctx).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(24), border: Border.all(color: kBorder)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _qtyBtn(Icons.remove_rounded, (out || _qty <= 1) ? null : () => setState(() => _qty--)),
                        SizedBox(
                          width: 28,
                          child: Text('$_qty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
                        ),
                        _qtyBtn(Icons.add_rounded, (out || _qty >= stock) ? null : () => setState(() => _qty++)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: out
                            ? null
                            : () {
                                widget.onAdd(_qty);
                                Navigator.pop(context);
                              },
                        icon: Icon(out ? Icons.block_rounded : Icons.add_shopping_cart_rounded, size: 18),
                        label: Text(out ? 'Rupture de stock' : 'Ajouter au panier',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade400,
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmPhotoGallery extends StatefulWidget {
  final List<String> photos;
  const _SmPhotoGallery({required this.photos});

  @override
  State<_SmPhotoGallery> createState() => _SmPhotoGalleryState();
}

class _SmPhotoGalleryState extends State<_SmPhotoGallery> {
  final PageController _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(22)),
        child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 38, color: kInkMuted)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 240,
        child: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: widget.photos[i],
                fit: BoxFit.cover,
                width: double.infinity,
                memCacheWidth: smMemW(900),
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kAccent)),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: kInkMuted)),
              ),
            ),
            if (widget.photos.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.photos.length, (i) {
                    final on = i == _i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: on ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: on ? kAccent : Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SmInfoGrid extends StatelessWidget {
  final SupermarketProduct product;
  const _SmInfoGrid({required this.product});

  @override
  Widget build(BuildContext context) {
    final stock = smStockOf(product);
    final cells = <Widget>[
      _SmInfoCell(
        icon: Icons.inventory_2_rounded,
        label: 'Stock',
        value: '$stock${product.unit != null ? ' ${product.unit}' : ''}',
        color: stock > 0 ? kSuccess : kDanger,
      ),
      _SmInfoCell(icon: Icons.straighten_rounded, label: 'Unité', value: '${product.unit ?? 'pcs'}', color: kAccent),
      if (product.isPerishable)
        _SmInfoCell(
          icon: product.isExpired ? Icons.warning_amber_rounded : Icons.event_rounded,
          label: 'Expiration',
          value: smFmtDate(product.expiryDate),
          color: product.isExpired ? kDanger : (product.isFreshSoon ? Colors.orange : kSuccess),
        ),
      if (product.onPromo)
        _SmInfoCell(
          icon: Icons.local_offer_rounded,
          label: 'Prix promo',
          value: '${product.priceLabel()} ${product.currency}',
          color: kSmRed,
        ),
    ];

    final cellWidth = (MediaQuery.of(context).size.width - 32 - 8) / 2;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cells.map((c) => SizedBox(width: cellWidth, child: c)).toList(),
    );
  }
}

class _SmInfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SmInfoCell({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9.5, color: kInkMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
