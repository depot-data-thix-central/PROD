// lib/presentation/home/widgets/home_premium_card.dart
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
    // Si tu as la route nommée :
    // context.pushNamed('certification');
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
              child: CircularProgressIndicator(strokeWidth: 2),
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
        child: _Content(
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
    final borderColor = accent?.withOpacity(0.35) ?? ThixPolicy.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF2FF), Colors.white],
            ),
            border: Border.all(color: borderColor, width: 0.9),
            borderRadius: BorderRadius.circular(ThixPolicy.rXl),
            boxShadow: ThixPolicy.shadowCard(),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ThixPolicy.s20,
            vertical: ThixPolicy.s16,
          ),
          child: child,
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: ThixPolicy.s12),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ThixPolicy.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ThixPolicy.s12,
            vertical: ThixPolicy.s8,
          ),
          decoration: BoxDecoration(
            color: ThixPolicy.textMain,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Voir',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
