// lib/presentation/home/widgets/home_personalised.dart
//
// ✅ Le bouton Wedding a été DÉPLACÉ vers la constellation (THIX WED).
//    La personnalisation conserve 3 actions : acheter, sécuriser, retirer.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'home_theme.dart';

const double _kCircleSize = 54.0;
const double _kIconSize = 22.0;
const double _kLabelFontSize = 10.5;
const int _kMaxLabelLength = 15;

class HomePersonalised extends StatelessWidget {
  const HomePersonalised({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            l10n.t('home_personalised_title'),
            style: ThixPolicy.titleStyle.copyWith(
              color: HomeTheme.ink,
              fontSize: 16,
              fontWeight: ThixPolicy.bold,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: HomeTheme.softShadow(0.07),
            ),
            child: Row(
              children: [
                _cell(_MiniRoundAction(
                    icon: Icons.shopping_cart_rounded,
                    label: l10n.t('home_mini_buy'),
                    onTap: () => _showComingSoon(context, l10n.t('home_mini_buy')))),
                _cell(_MiniRoundAction(
                    icon: Icons.shield_rounded,
                    label: l10n.t('home_mini_secure'),
                    onTap: () => _showComingSoon(context, l10n.t('home_mini_secure')))),
                _cell(_MiniRoundAction(
                    icon: Icons.local_atm_rounded,
                    label: l10n.t('home_mini_cash_out'),
                    onTap: () => _showComingSoon(context, l10n.t('home_mini_cash_out')))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(Widget child) => Expanded(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child));

  void _showComingSoon(BuildContext context, String feature) {
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature - ${AppLocalizations.of(context).t('coming_soon')}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HomeTheme.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _MiniRoundAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniRoundAction({required this.icon, required this.label, required this.onTap});

  @override
  State<_MiniRoundAction> createState() => _MiniRoundActionState();
}

class _MiniRoundActionState extends State<_MiniRoundAction> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!mounted || _pressed == v) return;
    setState(() => _pressed = v);
  }

  String _sanitizeLabel(String input) {
    final t = input.trim();
    if (t.isEmpty) return '—';
    return t.length > _kMaxLabelLength ? t.substring(0, _kMaxLabelLength) : t;
  }

  @override
  Widget build(BuildContext context) {
    final safeLabel = _sanitizeLabel(widget.label);

    return Semantics(
      button: true,
      label: safeLabel,
      child: GestureDetector(
        onTap: () {
          if (mounted) widget.onTap();
        },
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            children: [
              Container(
                width: _kCircleSize,
                height: _kCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HomeTheme.skySoft,
                  border: Border.all(
                      color: HomeTheme.skyDeep.withOpacity(0.25), width: 1.2),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: _kIconSize, color: HomeTheme.skyDeep),
              ),
              const SizedBox(height: 8),
              Text(
                safeLabel,
                style: const TextStyle(
                  color: HomeTheme.ink,
                  fontSize: _kLabelFontSize,
                  fontWeight: FontWeight.w700,
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
    );
  }
}
