// lib/presentation/home/widgets/home_personalised.dart
import 'dart:ui'; // ✅ NÉCESSAIRE POUR LE GLASSMORPHISM
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
          style: const TextStyle(
            color: ThixPolicy.textMain, 
            fontSize: 16, 
            fontWeight: FontWeight.w900, 
            letterSpacing: -0.2
          ),
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
                  accent: const Color(0xFFE25A6A), // Couleur spécifique conservée
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

class _MiniRoundAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _MiniRoundAction({
    required this.icon,
    required this.label,
    this.accent = ThixPolicy.primaryDeep, // Couleur corporate par défaut
    required this.onTap,
  });

  @override
  State<_MiniRoundAction> createState() => _MiniRoundActionState();
}

class _MiniRoundActionState extends State<_MiniRoundAction> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isWedding = widget.label == 'Mariage';
    
    return GestureDetector(
      onTap: widget.onTap,
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
              // 🌟 EFFET GLASSMORPHISM
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isWedding 
                          ? widget.accent.withOpacity(0.15) 
                          : Colors.black.withOpacity(0.04), // Ombre très douce
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isWedding 
                            ? widget.accent.withOpacity(0.15) 
                            : Colors.white.withOpacity(0.65), // Verre dépoli
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isWedding 
                              ? widget.accent.withOpacity(0.4) 
                              : Colors.white.withOpacity(0.9), // Bordure lumineuse
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        widget.icon, 
                        size: 22, 
                        color: isWedding ? widget.accent : ThixPolicy.primaryDeep
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: isWedding ? widget.accent : ThixPolicy.textMain,
                  fontSize: 10.5,
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
    );
  }
}
