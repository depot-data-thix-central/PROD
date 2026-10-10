import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

/// ============================================================================
/// PopularRouteCard
/// ============================================================================
///
/// Carte de route populaire affichée en scroll horizontal sur la home.
///
/// Features :
/// - Layout compact (168x~172px) optimisé pour le scroll horizontal
/// - Image distante avec cache (CachedNetworkImage) + fallback élégant
/// - Prix formaté selon la devise GLOBALE de l'utilisateur (via currencyProvider)
/// - Conversion automatique depuis la devise source (CDF par défaut)
/// - Animation scale + hero transition vers la page détail
/// - Accessibilité complète (Semantics, label concaténé)
/// - i18n intégrée (FR/EN/LN)
/// - Responsive (taille adaptée selon le parent)
/// - Badge "Populaire" optionnel
///
/// Architecture devise :
/// - `price` : montant stocké en devise SOURCE (par défaut CDF)
/// - `sourceCurrency` : devise du montant stocké (par défaut 'CDF')
/// - `currencyProvider` : devise d'AFFICHAGE choisie par l'utilisateur
///
/// ============================================================================
class PopularRouteCard extends ConsumerStatefulWidget {
  final String from;
  final String to;
  final String dateLabel;
  final int price;

  /// Devise SOURCE du prix stocké (par défaut 'CDF').
  /// Utilisée pour la conversion vers la devise d'affichage.
  final String sourceCurrency;

  final String? imageUrl;
  final bool isPopular;
  final VoidCallback onTap;
  final Color? domainColor;
  final Object? heroTag;

  const PopularRouteCard({
    super.key,
    required this.from,
    required this.to,
    required this.dateLabel,
    required this.price,
    this.sourceCurrency = 'CDF',
    this.imageUrl,
    this.isPopular = false,
    required this.onTap,
    this.domainColor,
    this.heroTag,
  });

  @override
  ConsumerState<PopularRouteCard> createState() => _PopularRouteCardState();
}

class _PopularRouteCardState extends ConsumerState<PopularRouteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleCtrl.forward();
  void _onTapUp(TapUpDetails _) => _scaleCtrl.reverse();
  void _onTapCancel() => _scaleCtrl.reverse();

  /// Calcule le prix à afficher en tenant compte de la devise globale.
  ({num amount, String currency}) _computeDisplayPrice() {
    final globalCurrency = ref.watch(currencyProvider).currency;
    final source = widget.sourceCurrency.toUpperCase();
    final target = globalCurrency.code.toUpperCase();

    if (source == target) {
      return (amount: widget.price, currency: target);
    }

    final state = ref.watch(currencyProvider);
    final converted = state.convert(widget.price, fromCurrency: source);

    return (amount: converted, currency: target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = widget.domainColor ?? ThixPolicy.domainReservation;

    final display = _computeDisplayPrice();
    final formattedPrice = CurrencyFormatter.format(
      display.amount,
      currency: display.currency,
      compact: true,
    );

    final title = "${widget.from} → ${widget.to}";
    
    // Construction manuelle du label sémantique car la clé spécifique n'existe pas
    final semanticLabel = '$title, ${widget.dateLabel}, ${l10n.t('event_from_price')} $formattedPrice';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: _buildCard(context, accent, title, formattedPrice, semanticLabel),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Color accent,
    String title,
    String formattedPrice,
    String semanticLabel,
  ) {
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

    Widget content = Container(
      width: 168,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImageSection(
            imageUrl: hasImage ? widget.imageUrl! : null,
            accent: accent,
            isPopular: widget.isPopular,
          ),
          Padding(
            padding: EdgeInsets.all(ThixPolicy.s10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.heroTag != null)
                  Hero(
                    tag: widget.heroTag!,
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        title,
                        style: ThixPolicy.labelStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          fontSize: 12,
                          color: ThixPolicy.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  Text(
                    title,
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 12,
                      color: ThixPolicy.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: ThixPolicy.s4),
                _DateChip(dateLabel: widget.dateLabel, accent: accent),
                SizedBox(height: ThixPolicy.s8),
                Text(
                  // Utilisation de la clé existante 'event_from_price' + prix
                  '${context.l10n.t('event_from_price')} $formattedPrice',
                  style: ThixPolicy.labelStyle.copyWith(
                    fontSize: 12,
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.success,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: content,
    );
  }
}

/// ============================================================================
/// _ImageSection — Image avec cache + placeholder élégant + badge populaire
/// ============================================================================
class _ImageSection extends StatelessWidget {
  final String? imageUrl;
  final Color accent;
  final bool isPopular;

  const _ImageSection({
    required this.imageUrl,
    required this.accent,
    required this.isPopular,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)),
          child: SizedBox(
            height: 90,
            width: double.infinity,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _Placeholder(accent: accent),
                    errorWidget: (_, __, ___) => _Placeholder(accent: accent),
                    fadeInDuration: const Duration(milliseconds: 250),
                    fadeOutDuration: const Duration(milliseconds: 150),
                  )
                : _Placeholder(accent: accent),
          ),
        ),
        if (isPopular)
          Positioned(
            top: ThixPolicy.s8,
            left: ThixPolicy.s8,
            child: _PopularBadge(),
          ),
      ],
    );
  }
}

/// ============================================================================
/// _Placeholder — Fallback élégant avec gradient et icône
/// ============================================================================
class _Placeholder extends StatelessWidget {
  final Color accent;
  const _Placeholder({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Icon(
        Icons.directions_bus_rounded,
        color: accent.withValues(alpha: 0.6),
        size: 32,
      ),
    );
  }
}

/// ============================================================================
/// _PopularBadge — Badge "Populaire" optionnel
/// ============================================================================
class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ThixPolicy.s8,
        vertical: ThixPolicy.s2,
      ),
      decoration: BoxDecoration(
        color: ThixPolicy.warning,
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.warning.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 10, color: Colors.white),
          SizedBox(width: ThixPolicy.s2),
          Text(
            // Utilisation de la clé 'network_filter_popular' qui correspond à "Populaire" / "Popular"
            context.l10n.t('network_filter_popular'),
            style: ThixPolicy.microStyle.copyWith(
              color: Colors.white,
              fontWeight: ThixPolicy.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _DateChip — Indicateur de date/icône calendrier
/// ============================================================================
class _DateChip extends StatelessWidget {
  final String dateLabel;
  final Color accent;

  const _DateChip({required this.dateLabel, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_rounded,
          size: 10,
          color: accent.withValues(alpha: 0.7),
        ),
        SizedBox(width: ThixPolicy.s4),
        Expanded(
          child: Text(
            dateLabel,
            style: ThixPolicy.microStyle.copyWith(
              fontSize: 10,
              color: ThixPolicy.textSecondary,
              fontWeight: ThixPolicy.medium,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// AnimatedBuilder — Polyfill pour compatibilité (si pas dans SDK)
/// ============================================================================
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
