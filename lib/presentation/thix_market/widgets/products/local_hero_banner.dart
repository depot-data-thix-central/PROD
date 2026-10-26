// lib/presentation/thix_market/widgets/products/local_hero_banner.dart
// ============================================================================
// HERO BANNER « MADE IN CONGO » — les 10 nouveaux produits, défilement auto
//  • même taille / même style que le hero de market_home_page
//    (hauteur 46 % de l'écran, clamp 300–420, viewport 0.92, Ken Burns)
//  • boucle infinie, pause au toucher / en arrière-plan
//  • badge NEW (rouge), puce MADE IN CONGO, prix converti, bouton Découvrir
// ============================================================================
import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/african_currencies.dart';
import '../../core/currency_service.dart';
import '../../core/drc_portal_theme.dart';
import '../../providers/currency_provider.dart';

const int _kLoopFactor = 400; // boucle infinie simulée
const Duration _kAutoDelay = Duration(seconds: 5);

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

String _plain(dynamic v, {int max = 200}) {
  final s = (v ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > max ? s.substring(0, max) : s;
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
    return PageController(viewportFraction: 0.92, initialPage: start);
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
      _ctrl.nextPage(duration: const Duration(milliseconds: 750), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _n;
    final heroH = (MediaQuery.sizeOf(context).height * 0.46).clamp(300.0, 420.0);

    if (n == 0) {
      if (!widget.loading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: heroH - 14,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: kDrcNavy.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: kDrcBlue))),
        ),
      );
    }

    final displayCode = ref.watch(currencyProvider);
    final current = _page % n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: heroH,
          child: NotificationListener<ScrollNotification>(
            onNotification: (nt) {
              if (nt is ScrollStartNotification && nt.dragDetails != null) {
                _dragging = true;
              } else if (nt is ScrollEndNotification && _dragging) {
                _dragging = false;
                _startTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _ctrl,
              itemCount: n * _kLoopFactor,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final idx = i % n;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _HeroCard(
                    product: widget.products[idx],
                    displayCode: displayCode,
                    lang: widget.lang,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 3.5,
                width: i == current ? 20 : 8,
                decoration: BoxDecoration(
                  color: i == current ? kDrcBlue : const Color(0xFFD8DEE7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ============================================================================
// CARTE (style market_home_page)
// ============================================================================
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String displayCode;
  final String lang;

  const _HeroCard({
    required this.product,
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
    final subtitle = _plain(product['description']);
    final price = _price(context);
    final id = product['id']?.toString() ?? '';
    final newLabel = lang == 'fr' ? 'NOUVEAU' : (lang == 'sw' ? 'MPYA' : 'NEW');
    final cta = lang == 'fr' ? 'Découvrir' : (lang == 'sw' ? 'Gundua' : 'Discover');

    return GestureDetector(
      onTap: id.isEmpty
          ? null
          : () {
              HapticFeedback.selectionClick();
              context.push('/market/product/$id');
            },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFFE5E7EB),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              _KenBurns(url: img)
            else
              const _HeroFallback(),

            // Dégradé de lisibilité
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.10), Colors.transparent, Colors.black.withOpacity(0.62)],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Puce MADE IN CONGO
            Positioned(
              top: 12,
              left: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.45)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(color: kDrcYellow, shape: BoxShape.circle),
                          child: SizedBox(width: 6, height: 6),
                        ),
                        SizedBox(width: 6),
                        Text('MADE IN DRC',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Badge NEW
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: kDrcRed,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: kDrcRed.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulseDot(),
                    const SizedBox(width: 6),
                    Text(newLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ),

            // Contenu bas
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (price.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.45)),
                          ),
                          child: Text(price, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.15),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_rounded, size: 14, color: kDrcInk),
                        const SizedBox(width: 8),
                        Text(cta, style: const TextStyle(color: kDrcInk, fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 13, color: kDrcInk),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filet tricolore
            const Positioned(left: 0, right: 0, bottom: 0, child: DrcTricolorStripe(height: 3)),
          ],
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
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kDrcNavy, kDrcBlueDeep, kDrcBlue]),
      ),
      child: Center(child: Icon(Icons.public_rounded, size: 64, color: Colors.white.withOpacity(0.22))),
    );
  }
}

class _KenBurns extends StatefulWidget {
  final String url;
  const _KenBurns({required this.url});

  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => const _HeroFallback(),
          errorWidget: (_, __, ___) => const _HeroFallback(),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 0.7, end: 1.25).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }
}
