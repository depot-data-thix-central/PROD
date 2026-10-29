// lib/presentation/thix_market/pages/supermarket_space_widgets.dart
// ============================================================================
// SUPERMARCHÉ — Design system + composants (fichier 2/2)
// Palette : bleu RDC profond, ciel, jaune, rouge — fond bleu-gris très clair
// ============================================================================

import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';

const String kSmAll = '__all';
const String kSmPromo = '__promo';

// ============================================================================
// TOKENS
// ============================================================================
class SmColors {
  SmColors._();

  static const Color bg = Color(0xFFF3F6FB);
  static const Color surface = Color(0xFFEAF0F8);
  static const Color ink = Color(0xFF0B1B33);
  static const Color inkSoft = Color(0xFF4A5B75);
  static const Color inkMuted = Color(0xFF8A99B0);
  static const Color border = Color(0xFFE1E8F2);

  static const Color blue = Color(0xFF0A5CD8);
  static const Color blueDark = Color(0xFF062F73);
  static const Color sky = Color(0xFF3FA9F5);
  static const Color skySoft = Color(0xFFE5F2FE);
  static const Color yellow = Color(0xFFFCD116);
  static const Color red = Color(0xFFD7263D);
  static const Color green = Color(0xFF12A150);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueDark, blue],
  );

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x120B1B33), blurRadius: 14, offset: Offset(0, 5)),
  ];
}

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

String? smZoneTag(SmZone z) {
  switch (z) {
    case SmZone.frozen:
      return '-18°C';
    case SmZone.drinks:
      return '+2°C';
    case SmZone.fresh:
      return '+4°C';
    case SmZone.produce:
      return 'FRAIS DU JOUR';
    case SmZone.standard:
      return null;
  }
}

Color smZoneColor(SmZone z) {
  switch (z) {
    case SmZone.frozen:
      return const Color(0xFF0277BD);
    case SmZone.drinks:
      return const Color(0xFF00838F);
    case SmZone.fresh:
      return SmColors.green;
    case SmZone.produce:
      return const Color(0xFF65A30D);
    case SmZone.standard:
      return SmColors.blue;
  }
}

// ============================================================================
// PRIMITIVES
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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class SmPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const SmPill({super.key, required this.text, required this.bg, this.fg = Colors.white, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class SmShopLogo extends StatelessWidget {
  final String? url;
  final double size;
  const SmShopLogo({super.key, required this.url, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
      ),
      child: ClipOval(
        child: has
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: smMemW(140),
                errorWidget: (_, __, ___) => const Icon(Icons.storefront_rounded, color: SmColors.blue),
              )
            : Icon(Icons.storefront_rounded, color: SmColors.blue, size: size * 0.5),
      ),
    );
  }
}

class SmAddButton extends StatelessWidget {
  final SupermarketProduct product;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onAdd;
  final double size;
  const SmAddButton({
    super.key,
    required this.product,
    required this.added,
    required this.onAdd,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final out = smStockOf(product) <= 0;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: added,
      builder: (_, set, __) {
        final done = set.contains(smPid(product));
        final color = out ? SmColors.inkMuted : (done ? SmColors.green : SmColors.blue);
        return SmTapScale(
          onTap: out ? null : () => onAdd(product),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: out ? null : [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(
              out ? Icons.block_rounded : (done ? Icons.check_rounded : Icons.add_rounded),
              size: size * 0.55,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class SmEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const SmEmpty({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: SmColors.skySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: SmColors.blue),
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: SmColors.inkSoft)),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE PRODUIT
// ============================================================================
class SmProductCard extends StatelessWidget {
  final SupermarketProduct product;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTap;
  final ValueChanged<SupermarketProduct> onAdd;

  const SmProductCard({
    super.key,
    required this.product,
    required this.added,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = smStockOf(p) <= 0;
    final double rating = (p.rating as num?)?.toDouble() ?? 0;

    return SmTapScale(
      onTap: () => onTap(p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SmColors.border),
          boxShadow: SmColors.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 1.08, child: _image(p, out)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, height: 1.2, fontWeight: FontWeight.w800, color: SmColors.ink),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (rating > 0) ...[
                                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF5A300)),
                                const SizedBox(width: 2),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w800, color: SmColors.inkSoft)),
                                const SizedBox(width: 6),
                              ],
                              if (p.unit != null)
                                Flexible(
                                  child: Text('${p.unit}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: SmColors.inkMuted)),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${p.priceLabel()} ${p.currency}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: out ? SmColors.inkMuted : (p.onPromo ? SmColors.red : SmColors.blue),
                                    ),
                                  ),
                                ),
                                if (p.onPromo)
                                  Text('${p.price}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: SmColors.inkMuted,
                                          decoration: TextDecoration.lineThrough)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          SmAddButton(product: p, added: added, onAdd: onAdd),
                        ],
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
  }

  Widget _image(SupermarketProduct p, bool out) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: SmColors.surface,
          child: p.hasPhotos
              ? CachedNetworkImage(
                  imageUrl: p.mainPhoto,
                  fit: BoxFit.cover,
                  memCacheWidth: smMemW(360),
                  fadeInDuration: const Duration(milliseconds: 120),
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) =>
                      const Center(child: Icon(Icons.shopping_basket_rounded, size: 28, color: SmColors.inkMuted)),
                )
              : const Center(child: Icon(Icons.shopping_basket_rounded, size: 28, color: SmColors.inkMuted)),
        ),
        if (out)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.72),
              alignment: Alignment.center,
              child: const Text('RUPTURE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: SmColors.inkMuted, letterSpacing: 1)),
            ),
          ),
        if (p.onPromo)
          Positioned(top: 8, left: 8, child: SmPill(text: '-${p.promoPercent}%', bg: SmColors.red)),
        if (p.isPerishable)
          Positioned(
            top: 8,
            right: 8,
            child: SmPill(
              text: p.isExpired ? 'EXPIRÉ' : (p.isFreshSoon ? 'J-${p.daysToExpiry}' : 'FRAIS'),
              bg: p.isExpired ? SmColors.inkMuted : (p.isFreshSoon ? const Color(0xFFF59E0B) : SmColors.green),
            ),
          ),
      ],
    );
  }
}

class SmSeeAllTile extends StatelessWidget {
  final Color color;
  final int remaining;
  final VoidCallback onTap;
  const SmSeeAllTile({super.key, required this.color, required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SmTapScale(
      onTap: onTap,
      child: Container(
        width: 108,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text('Voir tout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text('+$remaining produit(s)', style: const TextStyle(fontSize: 10, color: SmColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HERO PROMOS
// ============================================================================
class SmPromoHero extends StatefulWidget {
  final List<SupermarketProduct> products;
  final String storeName;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTap;
  final ValueChanged<SupermarketProduct> onAdd;

  const SmPromoHero({
    super.key,
    required this.products,
    required this.storeName,
    required this.added,
    required this.onTap,
    required this.onAdd,
  });

  @override
  State<SmPromoHero> createState() => _SmPromoHeroState();
}

class _SmPromoHeroState extends State<SmPromoHero> {
  final PageController _ctrl = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _index = 0;
  DateTime _resumeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      final n = _items().length;
      if (!mounted || n <= 1 || !_ctrl.hasClients) return;
      if (DateTime.now().isBefore(_resumeAt)) return;
      final next = (_index + 1) % n;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  List<SupermarketProduct> _items() {
    final promos = <SupermarketProduct>[
      for (final p in widget.products) if (p.onPromo && smStockOf(p) > 0) p,
    ];
    if (promos.isNotEmpty) return promos.take(6).toList();

    final featured = <SupermarketProduct>[
      for (final p in widget.products) if ((p.isFeatured || p.rating >= 4.5) && smStockOf(p) > 0) p,
    ];
    if (featured.isNotEmpty) return featured.take(5).toList();

    return <SupermarketProduct>[
      for (final p in widget.products) if (p.hasPhotos && smStockOf(p) > 0) p,
    ].take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (_index >= items.length && items.isNotEmpty) _index = 0;
    if (items.isEmpty) return _welcome();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.horizontal &&
            ((n is ScrollStartNotification && n.dragDetails != null) ||
                (n is ScrollUpdateNotification && n.dragDetails != null))) {
          _resumeAt = DateTime.now().add(const Duration(seconds: 4));
        }
        return false;
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _tile(items[i]),
          ),
          if (items.length > 1)
            Positioned(
              top: 14,
              right: 26,
              child: Row(
                children: List<Widget>.generate(items.length, (i) {
                  final on = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: on ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: on ? SmColors.yellow : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _welcome() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: SmColors.headerGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName.isEmpty ? 'Bienvenue' : 'Chez ${widget.storeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text('Découvrez tous nos rayons',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(SupermarketProduct p) {
    final promo = p.onPromo;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SmTapScale(
        onTap: () => widget.onTap(p),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x330B1B33), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (p.hasPhotos)
                  CachedNetworkImage(
                    imageUrl: p.mainPhoto,
                    fit: BoxFit.cover,
                    memCacheWidth: smMemW(800),
                    placeholder: (_, __) => Container(color: SmColors.blueDark),
                    errorWidget: (_, __, ___) => Container(color: SmColors.blueDark),
                  )
                else
                  Container(decoration: const BoxDecoration(gradient: SmColors.headerGradient)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        SmColors.blueDark.withOpacity(0.92),
                        SmColors.blueDark.withOpacity(0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SmPill(
                              text: promo ? 'PROMO -${p.promoPercent}%' : 'SÉLECTION',
                              bg: SmColors.yellow,
                              fg: SmColors.ink,
                              icon: promo ? Icons.local_fire_department_rounded : Icons.star_rounded,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16, height: 1.15, fontWeight: FontWeight.w900, color: Colors.white)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('${p.priceLabel()} ${p.currency}',
                                        style: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w900, color: SmColors.yellow)),
                                    if (promo) ...[
                                      const SizedBox(width: 8),
                                      Text('${p.price}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white.withOpacity(0.7),
                                              decoration: TextDecoration.lineThrough)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SmAddButton(product: p, added: widget.added, onAdd: widget.onAdd, size: 42),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STATS + BANNIÈRE + EN-TÊTE DE SECTION
// ============================================================================
class SmStat {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const SmStat({required this.value, required this.label, required this.icon, required this.color});
}

class SmStatsStrip extends StatelessWidget {
  final List<SmStat> stats;
  const SmStatsStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      final s = stats[i];
      if (i > 0) cells.add(const SizedBox(width: 8));
      cells.add(
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SmColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(s.icon, size: 16, color: s.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: SmColors.ink)),
                      Text(s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: SmColors.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      child: Row(children: cells),
    );
  }
}

class SmBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SmBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, SmColors.ink, 0.38)!],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            SmTapScale(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: color)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: color),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SmSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? tag;
  final Color? tagColor;
  final VoidCallback onTap;

  const SmSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.tag,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SmTapScale(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900, color: SmColors.ink, letterSpacing: -0.2)),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 6),
                        SmPill(text: tag!, bg: (tagColor ?? SmColors.blue).withOpacity(0.14), fg: tagColor ?? SmColors.blue),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: SmColors.inkMuted)),
                ],
              ),
            ),
            const Text('Voir tout', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: SmColors.blue)),
            const Icon(Icons.chevron_right_rounded, size: 18, color: SmColors.blue),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RAIL DE RAYONS (épinglé)
// ============================================================================
class SmRailItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const SmRailItem({required this.id, required this.label, required this.icon, required this.color});
}

class SmDeptRail extends StatelessWidget {
  final List<SmRailItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  const SmDeptRail({super.key, required this.items, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SmColors.bg,
        border: Border(bottom: BorderSide(color: SmColors.border, width: 0.6)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final it = items[i];
          final sel = it.id == selectedId;
          return SmTapScale(
            onTap: () => onSelect(it.id),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: sel ? it.color : it.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                      boxShadow: sel
                          ? [BoxShadow(color: it.color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: Icon(it.icon, size: 22, color: sel ? Colors.white : it.color),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: sel ? FontWeight.w900 : FontWeight.w700,
                      color: sel ? SmColors.ink : SmColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SmPinnedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  SmPinnedHeader({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant SmPinnedHeader oldDelegate) => true;
}

// ============================================================================
// RÉSULTAT DE RECHERCHE
// ============================================================================
class SmResultTile extends StatelessWidget {
  final SupermarketProduct product;
  final String location;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTap;
  final ValueChanged<SupermarketProduct> onAdd;

  const SmResultTile({
    super.key,
    required this.product,
    required this.location,
    required this.added,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return SmTapScale(
      onTap: () => onTap(p),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SmColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 60,
                height: 60,
                child: p.hasPhotos
                    ? CachedNetworkImage(
                        imageUrl: p.mainPhoto,
                        fit: BoxFit.cover,
                        memCacheWidth: smMemW(160),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: SmColors.surface,
                          child: Icon(Icons.shopping_basket_rounded, color: SmColors.inkMuted),
                        ),
                      )
                    : const ColoredBox(
                        color: SmColors.surface,
                        child: Icon(Icons.shopping_basket_rounded, color: SmColors.inkMuted),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: SmColors.ink)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded, size: 11, color: SmColors.blue),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, color: SmColors.inkMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${p.priceLabel()} ${p.currency}',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: p.onPromo ? SmColors.red : SmColors.blue)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SmAddButton(product: p, added: added, onAdd: onAdd, size: 38),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BARRE PANIER FLOTTANTE
// ============================================================================
class SmCartBar extends StatelessWidget {
  final ValueNotifier<int> count;
  final VoidCallback onTap;
  const SmCartBar({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: count,
      builder: (_, n, __) {
        final show = n > 0;
        return AnimatedSlide(
          offset: show ? Offset.zero : const Offset(0, 1.8),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !show,
              child: SmTapScale(
                onTap: onTap,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: SmColors.ink,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [BoxShadow(color: Color(0x550B1B33), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: SmColors.yellow, shape: BoxShape.circle),
                        child: const Icon(Icons.shopping_bag_rounded, size: 18, color: SmColors.ink),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Voir mon panier',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 28),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: SmColors.yellow, borderRadius: BorderRadius.circular(12)),
                        child: Text('$n',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: SmColors.ink)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// FICHE PRODUIT
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
        decoration: BoxDecoration(
          color: onTap == null ? Colors.transparent : Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: onTap == null ? SmColors.inkMuted : SmColors.ink),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final stock = smStockOf(p);
    final out = stock <= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: SmColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
                      decoration: BoxDecoration(color: SmColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SmGallery(photos: p.photos),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(p.title,
                            style: const TextStyle(
                                fontSize: 18, height: 1.2, fontWeight: FontWeight.w900, color: SmColors.ink)),
                      ),
                      if (p.onPromo) ...[
                        const SizedBox(width: 8),
                        SmPill(text: '-${p.promoPercent}%', bg: SmColors.red),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${p.priceLabel()} ${p.currency}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: p.onPromo ? SmColors.red : SmColors.blue)),
                      if (p.onPromo) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('${p.price} ${p.currency}',
                              style: const TextStyle(
                                  fontSize: 12, color: SmColors.inkMuted, decoration: TextDecoration.lineThrough)),
                        ),
                      ],
                      if (p.unit != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('/ ${p.unit}', style: const TextStyle(fontSize: 12, color: SmColors.inkMuted)),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: SmColors.border),
                      ),
                      child: Column(
                        children: [
                          BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: p.barcode!,
                            height: 44,
                            drawText: false,
                            color: SmColors.ink,
                          ),
                          const SizedBox(height: 6),
                          Text(p.barcode!,
                              style: const TextStyle(
                                  fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 2, color: SmColors.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    Text(smTr(widget.l10n, 'sm_description', 'Description'),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: SmColors.ink)),
                    const SizedBox(height: 6),
                    Text(p.description!,
                        style: const TextStyle(fontSize: 12.5, color: SmColors.inkSoft, height: 1.5)),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(ctx).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: SmColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: SmColors.surface, borderRadius: BorderRadius.circular(24)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _qtyBtn(Icons.remove_rounded, (out || _qty <= 1) ? null : () => setState(() => _qty--)),
                        SizedBox(
                          width: 28,
                          child: Text('$_qty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: SmColors.ink)),
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
                          backgroundColor: SmColors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: SmColors.inkMuted,
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

class _SmGallery extends StatefulWidget {
  final List<String> photos;
  const _SmGallery({required this.photos});

  @override
  State<_SmGallery> createState() => _SmGalleryState();
}

class _SmGalleryState extends State<_SmGallery> {
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
        decoration: BoxDecoration(color: SmColors.surface, borderRadius: BorderRadius.circular(22)),
        child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 38, color: SmColors.inkMuted)),
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
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2, color: SmColors.blue)),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: SmColors.inkMuted)),
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
                        color: on ? Colors.white : Colors.white.withOpacity(0.55),
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
        color: stock > 0 ? SmColors.green : SmColors.red,
      ),
      _SmInfoCell(icon: Icons.straighten_rounded, label: 'Unité', value: '${product.unit ?? 'pcs'}', color: SmColors.blue),
      if (product.isPerishable)
        _SmInfoCell(
          icon: product.isExpired ? Icons.warning_amber_rounded : Icons.event_rounded,
          label: 'Expiration',
          value: smFmtDate(product.expiryDate),
          color: product.isExpired ? SmColors.red : (product.isFreshSoon ? const Color(0xFFF59E0B) : SmColors.green),
        ),
      if (product.onPromo)
        _SmInfoCell(
          icon: Icons.local_offer_rounded,
          label: 'Prix promo',
          value: '${product.priceLabel()} ${product.currency}',
          color: SmColors.red,
        ),
    ];
    final w = (MediaQuery.of(context).size.width - 32 - 8) / 2;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cells.map((c) => SizedBox(width: w, child: c)).toList(),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SmColors.border),
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
                Text(label,
                    style: const TextStyle(fontSize: 9.5, color: SmColors.inkMuted, fontWeight: FontWeight.w700)),
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

// ============================================================================
// FICHE MAGASIN
// ============================================================================
void showSmShopInfo(
  BuildContext context, {
  required Map<String, dynamic> shop,
  required int departments,
  required int products,
}) {
  HapticFeedback.selectionClick();
  final name = shop['name']?.toString() ?? '';
  final city = shop['city']?.toString() ?? '';
  final address = shop['address']?.toString() ?? '';
  final phone = shop['phone']?.toString() ?? '';
  final desc = shop['description']?.toString() ?? '';
  final logo = shop['logo_url']?.toString();
  final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
  final isOpen = (shop['is_open'] as bool?) ?? true;

  Widget line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: SmColors.skySoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 15, color: SmColors.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600, color: SmColors.inkSoft)),
              ),
            ),
          ],
        ),
      );

  Widget stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: SmColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SmColors.blue)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SmColors.inkMuted)),
            ],
          ),
        ),
      );

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: SmColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: SmColors.border, width: 2),
                    ),
                    child: SmShopLogo(url: logo, size: 54),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: SmColors.ink)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            SmPill(text: isOpen ? 'OUVERT' : 'FERMÉ', bg: isOpen ? SmColors.green : SmColors.red),
                            if (rating > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A300)),
                              const SizedBox(width: 2),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w900, color: SmColors.inkSoft)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  stat('$departments', 'Rayons'),
                  const SizedBox(width: 8),
                  stat('$products', 'Produits'),
                ],
              ),
              if (city.isNotEmpty) line(Icons.place_rounded, city),
              if (address.isNotEmpty) line(Icons.map_outlined, address),
              if (phone.isNotEmpty) line(Icons.phone_outlined, phone),
              if (desc.isNotEmpty) line(Icons.info_outline_rounded, desc),
            ],
          ),
        ),
      ),
    ),
  );
}

// ============================================================================
// CHARGEMENT (skeleton)
// ============================================================================
class SmLoadingView extends StatefulWidget {
  const SmLoadingView({super.key});

  @override
  State<SmLoadingView> createState() => _SmLoadingViewState();
}

class _SmLoadingViewState extends State<SmLoadingView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double h, {double? w, double r = 18}) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(color: SmColors.border, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: 0.55 + 0.45 * _c.value,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                height: 150 + MediaQuery.of(context).padding.top,
                decoration: const BoxDecoration(
                  gradient: SmColors.headerGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(170, r: 24),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _box(50, w: 50, r: 25),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _box(220)),
                        const SizedBox(width: 10),
                        Expanded(child: _box(220)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
