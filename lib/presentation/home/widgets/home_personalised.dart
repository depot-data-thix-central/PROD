// lib/presentation/home/widgets/home_personalised.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kCircleSize = 50.0;
const double _kIconSize = 22.0;
const double _kLabelFontSize = 10.5;
const int _kMaxLabelLength = 15;

// ============================================================================
// VARIANT ENUM (au lieu de bool isWedding fragile)
// ============================================================================
enum _ActionVariant {
  defaultStyle,
  wedding,
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomePersonalised extends StatelessWidget {
  const HomePersonalised({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('home_personalised_title'),
          style: ThixPolicy.titleStyle.copyWith(
            color: ThixPolicy.textMain,
            fontSize: 16,
            fontWeight: ThixPolicy.bold,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),
        RepaintBoundary(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s6),
                  child: _MiniRoundAction(
                    icon: Icons.favorite_rounded,
                    label: l10n.t('home_mini_wedding'),
                    variant: _ActionVariant.wedding,
                    onTap: () => _navigateWedding(context),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s6),
                  child: _MiniRoundAction(
                    icon: Icons.shopping_cart_rounded,
                    label: l10n.t('home_mini_buy'),
                    variant: _ActionVariant.defaultStyle,
                    onTap: () => _showComingSoon(context, l10n.t('home_mini_buy')),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s6),
                  child: _MiniRoundAction(
                    icon: Icons.shield_rounded,
                    label: l10n.t('home_mini_secure'),
                    variant: _ActionVariant.defaultStyle,
                    onTap: () => _showComingSoon(context, l10n.t('home_mini_secure')),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s6),
                  child: _MiniRoundAction(
                    icon: Icons.local_atm_rounded,
                    label: l10n.t('home_mini_cash_out'),
                    variant: _ActionVariant.defaultStyle,
                    onTap: () => _showComingSoon(context, l10n.t('home_mini_cash_out')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateWedding(BuildContext context) {
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    debugPrint('[Personalised] 💒 Wedding tap');
    context.push('/thix-wedding'); // Corrigé : weeding → wedding
  }

  void _showComingSoon(BuildContext context, String feature) {
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    debugPrint('[Personalised] ℹ️ Coming soon: $feature');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - ${AppLocalizations.of(context).t('coming_soon')}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================================
// MINI ROUND ACTION
// ============================================================================
class _MiniRoundAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final _ActionVariant variant;
  final VoidCallback onTap;

  const _MiniRoundAction({
    required this.icon,
    required this.label,
    required this.variant,
    required this.onTap,
  });

  @override
  State<_MiniRoundAction> createState() => _MiniRoundActionState();
}

class _MiniRoundActionState extends State<_MiniRoundAction> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!mounted || _pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    if (!mounted) return;
    widget.onTap();
  }

  String _sanitizeLabel(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '—';
    return trimmed.length > _kMaxLabelLength
        ? trimmed.substring(0, _kMaxLabelLength)
        : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isWedding = widget.variant == _ActionVariant.wedding;
    final accent = isWedding ? const Color(0xFFE25A6A) : ThixPolicy.primaryDeep;
    final safeLabel = _sanitizeLabel(widget.label);

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: safeLabel,
        child: GestureDetector(
          onTap: _handleTap,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _pressed ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Column(
                children: [
                  // Cercle solide (pas de BackdropFilter = 10x plus rapide)
                  Container(
                    width: _kCircleSize,
                    height: _kCircleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isWedding
                          ? accent.withOpacity(0.15)
                          : Colors.white,
                      border: Border.all(
                        color: isWedding
                            ? accent.withOpacity(0.4)
                            : ThixPolicy.border.withOpacity(0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isWedding
                              ? accent.withOpacity(0.15)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, size: _kIconSize, color: accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    safeLabel,
                    style: TextStyle(
                      color: isWedding ? accent : ThixPolicy.textMain,
                      fontSize: _kLabelFontSize,
                      fontWeight: isWedding ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
