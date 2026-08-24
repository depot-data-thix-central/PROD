// lib/presentation/home/widgets/home_premium_card.dart
import 'dart:ui'; // ✅ NÉCESSAIRE POUR LE GLASSMORPHISM
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/certification_tiers_page.dart';
import 'package:thix_id/presentation/certification/providers/certification_provider.dart';
import 'package:thix_id/services/certification_service.dart';

class HomePremiumCard extends ConsumerWidget {
  const HomePremiumCard({super.key});

  void _openCertification(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CertificationTiersPage(),
      ),
    );
  }

  static const String _tierLadder = 'Gratuit · Standard · Premium · Entreprise · Officiel';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certAsync = ref.watch(myCertificationProvider);

    return certAsync.when(
      loading: () => _CardShell(
        onTap: () => _openCertification(context),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primaryDeep),
            ),
            SizedBox(width: 12),
            Text(
              'Chargement certification…',
              style: TextStyle(
                color: ThixPolicy.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => _CardShell(
        onTap: () => _openCertification(context),
        child: const _Content(
          title: 'Certification THIX',
          subtitle: _tierLadder,
          color: ThixPolicy.primaryDeep,
          icon: Icons.verified_user_rounded,
        ),
      ),
      data: (info) => _CardShell(
        onTap: () => _openCertification(context),
        accent: info.tier.badgeColor,
        child: _Content(
          title: info.isCertified
              ? info.tier.labelFr
              : info.status == CertificationStatus.pending
                  ? 'Certification en cours'
                  : 'Certification THIX',
          subtitle: info.isCertified ? _statusLine(info) : _tierLadder,
          color: info.tier.badgeColor,
          icon: info.isCertified ? info.tier.icon : Icons.verified_user_rounded,
        ),
      ),
    );
  }

  String _statusLine(CertificationInfo info) {
    final s = info.status.labelFr;
    return switch (info.tier) {
      CertificationTier.official => 'Niveau institutions · $s',
      CertificationTier.enterprise => 'Compte organisation · $s',
      CertificationTier.premium => 'Fonctionnalités avancées · $s',
      CertificationTier.standard => 'Identité & accès de base · $s',
      CertificationTier.free => 'Compte gratuit · $s',
    };
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? accent;

  const _CardShell({
    required this.child,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // Bordure subtile reprenant la couleur de la certification (ou blanche par défaut)
    final borderColor = accent?.withOpacity(0.4) ?? Colors.white.withOpacity(0.9);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Ombre très douce
            blurRadius: 12, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Effet Glassmorphism
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65), // Verre dépoli
                  border: Border.all(color: borderColor, width: 1.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s20,
                  vertical: ThixPolicy.s16,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _Content({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Cercle d'icône avec léger fond blanc/verre
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))
            ]
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: ThixPolicy.s12),
        
        // Textes
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ThixPolicy.textMain,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ThixPolicy.textSecondary.withOpacity(0.8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Bouton Corporate (PrimaryDeep)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ThixPolicy.s16,
            vertical: ThixPolicy.s10,
          ),
          decoration: BoxDecoration(
            color: ThixPolicy.primaryDeep,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))
            ]
          ),
          child: const Text(
            'Voir',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
