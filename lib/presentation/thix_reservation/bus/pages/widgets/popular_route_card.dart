import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

class PopularRouteCard extends ConsumerStatefulWidget {
  final String from;
  final String to;
  final String dateLabel;
  final int price;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = widget.domainColor ?? ThixPolicy.domainReservation;
    final currencyState = ref.watch(currencyProvider);
    
    final display = currencyState.convert(
      widget.price,
      fromCurrency: widget.sourceCurrency,
    );
    final formattedPrice = CurrencyFormatter.format(
      display,
      currency: currencyState.currency.code,
      compact: true,
    );
    final title = '${widget.from} → ${widget.to}';

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
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(ThixPolicy.rMd),
                ),
                child: SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _Placeholder(accent: accent),
                          errorWidget: (_, __, ___) => _Placeholder(accent: accent),
                        )
                      : _Placeholder(accent: accent),
                ),
              ),
              if (widget.isPopular)
                Positioned(
                  top: ThixPolicy.s8,
                  left: ThixPolicy.s8,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s8,
                      vertical: ThixPolicy.s2,
                    ),
                    decoration: BoxDecoration(
                      color: ThixPolicy.warning,
                      borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                        SizedBox(width: ThixPolicy.s2),
                        Text(
                          l10n.t('network_filter_popular'),
                          style: ThixPolicy.microStyle.copyWith(
                            color: Colors.white,
                            fontWeight: ThixPolicy.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(ThixPolicy.s10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 10,
                      color: accent.withValues(alpha: 0.7),
                    ),
                    SizedBox(width: ThixPolicy.s4),
                    Expanded(
                      child: Text(
                        widget.dateLabel,
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
                ),
                SizedBox(height: ThixPolicy.s8),
                Text(
                  '${l10n.t('event_from_price')} $formattedPrice',
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

    if (widget.heroTag != null) {
      content = Hero(
        tag: widget.heroTag!,
        child: Material(color: Colors.transparent, child: content),
      );
    }

    return Semantics(
      button: true,
      label: '$title, ${widget.dateLabel}, ${l10n.t('event_from_price')} $formattedPrice',
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) => _scaleCtrl.reverse(),
        onTapCancel: () => _scaleCtrl.reverse(),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          listenable: _scaleAnim,
          builder: (ctx, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Color accent;
  
  const _Placeholder({required this.accent});
  
  @override
  Widget build(BuildContext context) => Container(
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
