// lib/presentation/thix_market/widgets/products/local_hero_banner.dart
// ============================================================================
// HERO BANNER THIX LOCAL — les 10 nouveaux produits, défilement automatique
//  • boucle infinie, pause au toucher / en arrière-plan
//  • carte centrale mise en avant (échelle), badge NOUVEAU, compteur n/10
//  • prix converti dans la devise choisie
// ============================================================================
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/african_currencies.dart';
import '../../core/currency_service.dart';
import '../../core/local_sectors.dart';
import '../../providers/currency_provider.dart';

const double _kHeroHeight = 214;
const int _kLoopFactor = 400; // nombre de « tours » simulés (boucle infinie)
const Duration _kAutoDelay = Duration(seconds: 4);
const Color _kMint = Color(0xFFB9F0C8);

// ── Extraction tolérante des champs produit ─────────────────────────────────
String? _okUrl(dynamic v) {
  final s = v?.toString().trim();
  return (s != null && s.startsWith('http')) ? s : null;
}

String? _heroImage(Map<String, dynamic> p) {
  for (final k in const ['cover_url', 'image_url', 'thumbnail_url', 'thumbnail', 'image', 'photo_url', 'main_image']) {
    final r = _okUrl(p[k]);
    if (r != null) return r;
  }
  for (final k in const ['images', 'photos', 'media']) {
    final v = p[k];
    if (v is List) {
      for (final e in v) {
        final r = e is Map ? (_okUrl(e['url']) ?? _okUrl(e['image_url'])) : _okUrl(e);
        if (r != null) return r;
      }
    }
  }
  return null;
}

String _heroTitle(Map<String, dynamic> p) {
  final t = (p['title'] ?? p['name'] ?? p['product_name'] ?? '').toString().trim();
  return t.isEmpty ? '—' : t;
}

String _normCurrency(String raw) {
  final v = raw.toUpperCase().trim();
  if (AfricanCurrencies.byCode(v) != null) return v;
  const aliases = <String, String>{'FC': 'CDF', 'FCFA': 'XOF', r'$': 'USD', 'DOLLAR': 'USD', 'US': 'USD', 'EURO': 'EUR', '€': 'EUR'};
  return aliases[v] ?? 'CDF';
}

class LocalHeroBanner extends ConsumerStatefulWidget {
  /// Déjà limité aux 10 plus récents.
  final List<Map<String, dynamic>> products;
  final bool loading;
  final String lang;

  const LocalHeroBanner({
    super.key,
    required this.products,
    required this.loading,
    required this.lang,
  });

  @override
  ConsumerState<LocalHeroBanner> createState() => _LocalHeroBannerState();
}

class _LocalHeroBannerState extends ConsumerState<LocalHeroBanner> with WidgetsBindingObserver {
  late PageController _ctrl;
  Timer? _timer;
  int _page = 0;
  bool _dragging = false;
  bool _paused = false;

  int get _n => widget.products.length;

  PageController _makeCtrl(int n) {
    final start = n > 0 ? n * (_kLoopFactor ~/ 2) : 0;
    _page = start;
    return PageController(viewportFraction: 0.9, initialPage: start);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = _makeCtrl(_n);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LocalHeroBanner old) {
    super.didUpdateWidget(old);
    if (old.products.length != widget.products.length) {
      final oldCtrl = _ctrl;
      _ctrl = _makeCtrl(_n);
      WidgetsBinding.instance.addPostFrameCallback((_) => oldCtrl.dispose());
      _startTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
  }

  void _startTimer() {
    _timer?.cancel();
    if (_n < 2) return;
    _timer = Timer.periodic(_kAutoDelay, (_) {
      if (!mounted || _dragging || _paused || !_ctrl.hasClients || _n < 2) return;
      _ctrl.nextPage(duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _n;

    if (n == 0) {
      if (!widget.loading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: _kHeroHeight - 14,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: kLocalGreenDeep.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: kLocalGreen))),
        ),
      );
    }

    final displayCode = ref.watch(currencyProvider);
    final current = _page % n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _kHeroHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (nt) {
              if (nt is ScrollStartNotification && nt.dragDetails != null) {
                _dragging = true;
              } else if (nt is ScrollEndNotification && _dragging) {
                _dragging = false;
                _startTimer(); // relance un délai complet après l'interaction
              }
              return false;
            },
            child: PageView.builder(
              controller: _ctrl,
              itemCount: n * _kLoopFactor,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final idx = i % n;
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, child) {
                    final cur = (_ctrl.hasClients && _ctrl.position.haveDimensions) ? (_ctrl.page ?? _page.toDouble()) : _page.toDouble();
                    final d = (cur - i).abs().clamp(0.0, 1.0);
                    return Transform.scale(scale: 1 - d * 0.07, child: child);
                  },
                  child: _HeroCard(
                    product: widget.products[idx],
                    index: idx,
                    total: n,
                    displayCode: displayCode,
                    lang: widget.lang,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: i == current ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == current ? kLocalGreen : kLocalGreen.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// CARTE
// ============================================================================
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;
  final int total;
  final String displayCode;
  final String lang;

  const _HeroCard({
    required this.product,
    required this.index,
    required this.total,
    required this.displayCode,
    required this.lang,
  });

  String _price(BuildContext context) {
    final raw = product['price'];
    final num? n = raw is num ? raw : num.tryParse('${raw ?? ''}');
    if (n == null) return '';
    final from = _normCurrency('${product['currency_code'] ?? product['currency'] ?? 'CDF'}');
    try {
      final svc = CurrencyService.instance;
      final conv = svc.convert(n.toDouble(), from: from, to: displayCode);
      return svc.formatPrice(conv, currencyCode: displayCode, lang: Localizations.localeOf(context).languageCode);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _heroImage(product);
    final title = _heroTitle(product);
    final price = _price(context);
    final id = product['id']?.toString() ?? '';
    final newLabel = lang == 'fr' ? 'NOUVEAU' : (lang == 'sw' ? 'MPYA' : 'NEW');

    return GestureDetector(
      onTap: id.isEmpty
          ? null
          : () {
              HapticFeedback.selectionClick();
              context.push('/market/product/$id');
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: kLocalGreenDeep.withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img != null)
                  CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _HeroFallback(),
                    errorWidget: (_, __, ___) => const _HeroFallback(),
                  )
                else
                  const _HeroFallback(),

                // Voile vert pour la lisibilité
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, kLocalGreenDeep.withOpacity(0.25), kLocalGreenDeep.withOpacity(0.94)],
                      stops: const [0.30, 0.62, 1.0],
                    ),
                  ),
                ),

                // Badge NOUVEAU
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.96), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bolt_rounded, size: 13, color: kLocalGreen),
                      const SizedBox(width: 3),
                      Text(newLabel, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: kLocalGreenDeep, letterSpacing: 0.6)),
                    ]),
                  ),
                ),

                // Compteur
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.28), borderRadius: BorderRadius.circular(20)),
                    child: Text('${index + 1}/$total', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),

                // Texte + flèche
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.3),
                            ),
                            if (price.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(price, style: const TextStyle(color: _kMint, fontSize: 15, fontWeight: FontWeight.w900)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_outward_rounded, size: 20, color: kLocalGreenDeep),
                      ),
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

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kLocalGreen, kLocalGreenDeep]),
      ),
      child: Center(child: Icon(Icons.agriculture_rounded, size: 64, color: Colors.white.withOpacity(0.22))),
    );
  }
}
