// lib/presentation/home/widgets/home_personalised.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';


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
          style: const TextStyle(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        const SizedBox(height: ThixPolicy.s12),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _MiniRoundAction(
                  icon: Icons.favorite_rounded,
                  label: 'Mariage',
                  accent: const Color(0xFFE25A6A),
                  onTap: () => context.push('/thix-weeding'),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _MiniRoundAction(
                  icon: Icons.shopping_cart_rounded,
                  label: l10n.t('home_mini_buy'),
                  onTap: () {},
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _MiniRoundAction(
                  icon: Icons.shield_rounded,
                  label: l10n.t('home_mini_secure'),
                  onTap: () {},
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _MiniRoundAction(
                  icon: Icons.local_atm_rounded,
                  label: l10n.t('home_mini_cash_out'),
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniRoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _MiniRoundAction({
    required this.icon,
    required this.label,
    this.accent = ThixPolicy.textMain,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWedding = label == 'Mariage';
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isWedding ? const Color(0xFFFFF0F2) : ThixPolicy.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: isWedding ? const Color(0xFFE25A6A).withValues(alpha: 0.4) : ThixPolicy.border,
                width: 0.8,
              ),
              boxShadow: ThixPolicy.shadowSoft(),
            ),
            child: Icon(icon, size: 20, color: isWedding ? const Color(0xFFE25A6A) : ThixPolicy.textMain),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isWedding ? const Color(0xFFE25A6A) : ThixPolicy.textSecondary,
              fontSize: 11,
              fontWeight: isWedding ? FontWeight.w800 : FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
