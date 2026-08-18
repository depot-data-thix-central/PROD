import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/theme.dart';

class FeaturedFormation {
  final String title;
  final String provider;
  final String level;
  final String duration;
  final String priceLabel;
  final IconData icon;

  const FeaturedFormation({
    required this.title,
    required this.provider,
    required this.level,
    required this.duration,
    required this.priceLabel,
    required this.icon,
  });
}

/// A premium horizontal carousel for the Home "À la une" section.
///
/// - Auto-rotates.
/// - Tap opens the full Formations page.
class FeaturedFormationsCarousel extends StatefulWidget {
  final List<FeaturedFormation> items;
  final Duration autoPlayInterval;

  const FeaturedFormationsCarousel({
    super.key,
    required this.items,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  @override
  State<FeaturedFormationsCarousel> createState() => _FeaturedFormationsCarouselState();
}

class _FeaturedFormationsCarouselState extends State<FeaturedFormationsCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant FeaturedFormationsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlayInterval != widget.autoPlayInterval || oldWidget.items.length != widget.items.length) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final cs = context.theme.colorScheme;
    final isDark = context.theme.brightness == Brightness.dark;
    final gold = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold);
    final border = gold.withValues(alpha: isDark ? 0.45 : 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.onSurface.withValues(alpha: 0.06),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.auto_awesome_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.80)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('À la une', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Formations premium recommandées', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70), height: 1.25)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.trainingHome),
              style: TextButton.styleFrom(foregroundColor: LightModeColors.accent, padding: EdgeInsets.zero),
              child: Text('Tout voir  ›', style: context.textStyles.labelLarge?.copyWith(color: LightModeColors.accent, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: () => context.push(AppRoutes.trainingHome),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10), blurRadius: 22, offset: const Offset(0, 12))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                SizedBox(
                  height: 210,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: items.isEmpty ? 1 : (items.length * 2000),
                    onPageChanged: (i) {
                      if (items.isEmpty) return;
                      setState(() => _index = i % items.length);
                    },
                    itemBuilder: (context, i) {
                      final item = items.isEmpty ? _demoFallback() : items[i % items.length];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                        child: FeaturedFormationCard(item: item),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: _CarouselDots(
                    count: items.isEmpty ? 1 : items.length,
                    activeIndex: items.isEmpty ? 0 : _index,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  FeaturedFormation _demoFallback() => const FeaturedFormation(
        title: 'Certification THIX — Cyber Trust Foundation',
        provider: 'THIX Academy',
        level: 'Officiel',
        duration: '4 semaines',
        priceLabel: 'Gratuit',
        icon: Icons.shield_rounded,
      );
}

class _CarouselDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  const _CarouselDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final gold = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold);
    final idle = context.theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.25 : 0.18);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: selected ? gold : idle,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class FeaturedFormationCard extends StatelessWidget {
  final FeaturedFormation item;
  const FeaturedFormationCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final gold = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold);
    final goldDeep = (isDark ? DarkModeColors.metalGoldDeep : LightModeColors.metalGoldDeep);
    final cs = context.theme.colorScheme;

    final bg = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        (isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.cyberDarkBlue).withValues(alpha: 0.98),
        (isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.cyberDarkBlue).withValues(alpha: 0.78),
        gold.withValues(alpha: 0.10),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final tight = c.maxHeight.isFinite && c.maxHeight < 190;
        final pad = tight ? AppSpacing.md : AppSpacing.lg;
        final iconBox = tight ? 40.0 : 44.0;
        final buttonPad = tight ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
        final titleStyle = (tight ? context.textStyles.titleMedium : context.textStyles.titleLarge)?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.15);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: bg,
            border: Border.all(color: gold.withValues(alpha: 0.45)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Icon(item.icon, size: tight ? 104 : 120, color: gold.withValues(alpha: 0.10)),
              ),
              Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: gold.withValues(alpha: 0.28)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(item.icon, color: gold, size: tight ? 20 : 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.level.toUpperCase(), style: context.textStyles.labelSmall?.copyWith(color: gold, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              const SizedBox(height: 2),
                              Text(item.provider, style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.78), height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Container(
                          padding: tight ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: gold.withValues(alpha: 0.22)),
                          ),
                          child: Text(item.priceLabel, style: context.textStyles.labelMedium?.copyWith(color: gold, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    SizedBox(height: tight ? AppSpacing.sm : AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: titleStyle, maxLines: tight ? 2 : 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(item.duration, style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85), height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: buttonPad,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          gradient: LinearGradient(colors: [LightModeColors.accent, goldDeep]),
                          boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF0A2F5C)),
                            const SizedBox(width: 8),
                            Text('Ouvrir', style: context.textStyles.labelLarge?.copyWith(color: const Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
