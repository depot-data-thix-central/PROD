// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — WIDGET : COMPTEUR ANIMÉ
//  Fichier  : lib/presentation/thix_portfolio/widgets/animated_counter.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  Compteur 0 → [value] avec easing, format compact optionnel
//  (1 200 → « 1,2 K », 8 500 → « 8,5 K », 1 200 000 → « 1,2 M »).
//
//  • 100 % version-safe : TweenAnimationBuilder, aucune API dépréciée.
//  • Déclenché au build (les slivers étant construits paresseusement,
//    l'effet « compte quand ça apparaît » est naturel dans un scroll).
//  • Préfixe / suffixe libres (« + », « % », « ans »…).
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.label,
    this.compact = true,
    this.duration = const Duration(milliseconds: 1400),
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '',
    this.valueStyle,
    this.labelStyle,
    this.icon,
  });

  /// Valeur cible (int ou double).
  final num value;

  /// Libellé sous le chiffre (ex : « visites »).
  final String? label;

  /// Format compact K / M.
  final bool compact;

  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;
  final IconData? icon;

  /// 1200 → « 1,2 K » · 8500 → « 8,5 K » · 1200000 → « 1,2 M »
  static String formatCompact(num v) {
    final d = v.toDouble();
    String clean(String s) => s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
    if (d >= 1e6) return clean('${(d / 1e6).toStringAsFixed(1)} M');
    if (d >= 1e3) return clean('${(d / 1e3).toStringAsFixed(1)} K');
    return '${d.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, v, _) {
        final text = compact ? formatCompact(v) : '${v.round()}';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
            Text(
              '$prefix$text$suffix',
              style: valueStyle ??
                  theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (label != null)
              Text(
                label!,
                textAlign: TextAlign.center,
                style: labelStyle ?? theme.textTheme.bodySmall,
              ),
          ],
        );
      },
    );
  }
}
