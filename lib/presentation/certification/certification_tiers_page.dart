// lib/presentation/certification/certification_tiers_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/certification_checkout_page.dart';
import 'package:thix_id/presentation/certification/providers/certification_provider.dart';
import 'package:thix_id/services/bcc_exchange_rate_service.dart';
import 'package:thix_id/services/certification_service.dart';

class CertificationTiersPage extends ConsumerStatefulWidget {
  const CertificationTiersPage({super.key});

  @override
  ConsumerState<CertificationTiersPage> createState() =>
      _CertificationTiersPageState();
}

class _CertificationTiersPageState
    extends ConsumerState<CertificationTiersPage> {
      
  Future<void> _requestTier(CertificationTier tier) async {
    if (tier.isInviteOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le niveau Officiel / Institutions est accessible uniquement sur invitation THIX.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // On attend le retour de la page de paiement
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CertificationCheckoutPage(tier: tier),
      ),
    );

    // CORRECTION : On invalide SANS condition.
    // Ainsi, si la transaction a échoué ou a été annulée, l'UI quitte l'état "En cours".
    ref.invalidate(myCertificationProvider);
  }

  @override
  Widget build(BuildContext context) {
    final certAsync = ref.watch(myCertificationProvider);
    final rateAsync = ref.watch(usdCdfRateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA), // Fond très clair et moderne
      body: certAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (info) => RefreshIndicator(
          color: const Color(0xFFD4A017), // Or THIX
          backgroundColor: const Color(0xFF0A1628), // Bleu marine THIX
          onRefresh: () async {
            ref.invalidate(myCertificationProvider);
            ref.invalidate(usdCdfRateProvider);
            // Petit délai pour l'animation
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _Header(info: info)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    rateAsync.when(
                      data: (q) => _RateBanner(quote: q),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 18),
                    _CertificationBoard(
                      current: info,
                      rate: rateAsync.valueOrNull,
                      onRequest: _requestTier,
                    ),
                    const SizedBox(height: 24),
                    const _FooterNote(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HEADER (Bannière Bleu Marine Profond & Or)
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final CertificationInfo info;
  const _Header({required this.info});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    final isFreeAccount = info.status == CertificationStatus.none;
    final displayTierName = isFreeAccount ? 'Compte Gratuit' : info.tier.labelFr;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, top + 4, 16, 24),
      decoration: const BoxDecoration(
        // Utilisation d'un dégradé bleu marine profond plus riche
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF06101D),
            Color(0xFF0A1628),
            Color(0xFF132A4A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0A1628),
            blurRadius: 15,
            offset: Offset(0, 4),
            spreadRadius: -5,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A017).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFD4A017).withOpacity(0.4)), // Accents Or
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint, color: Color(0xFFE8B84A), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'THIX ID',
                      style: TextStyle(
                        color: Color(0xFFE8B84A),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'CERTIFICATION THIX',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Abonnement mensuel · Secure Identity. Trusted Future.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Effet Glassmorphism
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  _MiniSeal(
                    color: isFreeAccount ? Colors.blueGrey : info.tier.badgeColor,
                    icon: isFreeAccount ? Icons.person_outline : info.tier.icon,
                    size: 46,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Votre niveau actuel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayTierName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: info.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final CertificationStatus status;
  const _StatusPill({required this.status});

  Color get _c => switch (status) {
        CertificationStatus.approved ||
        CertificationStatus.generated =>
          const Color(0xFF22C55E),
        CertificationStatus.pending => const Color(0xFFF59E0B),
        CertificationStatus.rejected => const Color(0xFFEF4444),
        CertificationStatus.none => Colors.white54,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _c.withOpacity(0.3)),
      ),
      child: Text(
        status.labelFr,
        style: TextStyle(
          color: _c,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BANDEAU TAUX
// ═══════════════════════════════════════════════════════════════

class _RateBanner extends StatelessWidget {
  final ExchangeRateQuote quote;
  const _RateBanner({required this.quote});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(quote.asOf.toLocal());
    final rateStr = NumberFormat('#,##0.##', 'fr_FR').format(quote.usdToCdf);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1628).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              quote.isOfficialBcc
                  ? Icons.account_balance_rounded
                  : Icons.currency_exchange_rounded,
              size: 16,
              color: const Color(0xFF0A1628), // Navy Blue
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '1 USD = $rateStr CDF · ${quote.isOfficialBcc ? 'BCC' : quote.source} · $date',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOARD — 4 niveaux
// ═══════════════════════════════════════════════════════════════

class _CertificationBoard extends StatelessWidget {
  final CertificationInfo current;
  final ExchangeRateQuote? rate;
  final Future<void> Function(CertificationTier) onRequest;

  const _CertificationBoard({
    required this.current,
    required this.rate,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TierRow(
          tier: CertificationTier.standard,
          current: current,
          rate: rate,
          onRequest: onRequest,
        ),
        const SizedBox(height: 16),
        _TierRow(
          tier: CertificationTier.premium,
          current: current,
          rate: rate,
          onRequest: onRequest,
          showGeneratedBadge: current.tier == CertificationTier.premium &&
              (current.status == CertificationStatus.generated ||
                  current.status == CertificationStatus.approved),
          extraLines: const [
            'Accès à la monétisation des contenus et services.',
          ],
        ),
        const SizedBox(height: 16),
        _TierRow(
          tier: CertificationTier.enterprise,
          current: current,
          rate: rate,
          onRequest: onRequest,
        ),
        const SizedBox(height: 16),
        _TierRow(
          tier: CertificationTier.official,
          current: current,
          rate: rate,
          onRequest: onRequest,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LIGNE D'UN NIVEAU — Cartes plus modernes avec des ombres douces
// ═══════════════════════════════════════════════════════════════

class _TierRow extends StatelessWidget {
  final CertificationTier tier;
  final CertificationInfo current;
  final ExchangeRateQuote? rate;
  final Future<void> Function(CertificationTier) onRequest;
  final bool showGeneratedBadge;
  final List<String> extraLines;

  const _TierRow({
    required this.tier,
    required this.current,
    required this.rate,
    required this.onRequest,
    this.showGeneratedBadge = false,
    this.extraLines = const [],
  });

  bool get _isCurrent => current.tier == tier;
  bool get _isLockedBelow => tier.rank < current.tier.rank;

  bool get _canRequest {
    if (tier.isInviteOnly) return false;
    if (current.status == CertificationStatus.pending &&
        current.tier.rank >= tier.rank) {
      return false;
    }
    if (_isCurrent && current.isCertified) return false;
    if (_isLockedBelow) return false;
    return true;
  }

  String get _title => switch (tier) {
        CertificationTier.free => 'COMPTE GRATUIT',
        CertificationTier.standard => 'COMPTE STANDARD',
        CertificationTier.premium => 'COMPTE PREMIUM',
        CertificationTier.enterprise => 'COMPTE ENTREPRISE',
        CertificationTier.official =>
          'RÉSERVÉ AUX OFFICIELS & INSTITUTIONS',
      };

  String get _body => switch (tier) {
        CertificationTier.free =>
          'Accès de base gratuit. Publication limitée, idéal pour découvrir THIX ID.',
        CertificationTier.standard =>
          'Pour les utilisateurs individuels. Accès aux fonctionnalités de base et à la certification d\'identité.',
        CertificationTier.premium =>
          'Pour ceux qui veulent plus. Fonctionnalités avancées, certification prioritaire et expérience améliorée.',
        CertificationTier.enterprise =>
          'Pour les organisations et entreprises. Gestion d\'équipe, contrôle avancé et solutions sur mesure.',
        CertificationTier.official =>
          'Pour les entités officielles et les institutions de confiance. Niveau d\'accès le plus élevé.',
      };

  IconData get _titleIcon => switch (tier) {
        CertificationTier.free => Icons.person_outline_rounded,
        CertificationTier.standard => Icons.person_rounded,
        CertificationTier.premium => Icons.workspace_premium_rounded,
        CertificationTier.enterprise => Icons.business_center_rounded,
        CertificationTier.official => Icons.shield_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = tier.badgeColor;
    final active = _isCurrent || current.tier.rank >= tier.rank;
    final isPremium = tier == CertificationTier.premium;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          // Met en valeur le Premium (Or) ou le compte actuel
          color: _isCurrent 
              ? color.withOpacity(0.8) 
              : isPremium 
                  ? color.withOpacity(0.3) 
                  : const Color(0xFFE2E8F0),
          width: _isCurrent ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? color : const Color(0xFF0A1628)).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _canRequest ? () => onRequest(tier) : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SealBadge(color: color, active: active),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_titleIcon, color: color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _title,
                              style: TextStyle(
                                color: color,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showGeneratedBadge || _isCurrent) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (showGeneratedBadge)
                              const _Chip(
                                  label: 'GÉNÉRÉ', color: Color(0xFFD4A017)),
                            if (_isCurrent) _Chip(label: 'ACTUEL', color: color),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _body,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ...extraLines.map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.stars_rounded,
                                    size: 16, color: color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l,
                                    style: TextStyle(
                                      color: color.withOpacity(0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child:
                                _PriceLine(tier: tier, rate: rate, color: color),
                          ),
                          const SizedBox(width: 10),
                          _ActionBtn(
                            tier: tier,
                            canRequest: _canRequest,
                            isCurrent: _isCurrent,
                            isCertified: current.isCertified && _isCurrent,
                            isPending: current.status ==
                                    CertificationStatus.pending &&
                                !_isLockedBelow,
                            color: color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final CertificationTier tier;
  final ExchangeRateQuote? rate;
  final Color color;

  const _PriceLine({
    required this.tier,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (tier.isInviteOnly) {
      return Text(
        'Sur invitation',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    final usd = tier.priceUsd ?? 0;
    final cdf = rate != null ? rate!.formatCdf(usd) : '… CDF';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${usd.toStringAsFixed(0)} USD / mois',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '≈ $cdf / mois',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final CertificationTier tier;
  final bool canRequest;
  final bool isCurrent;
  final bool isCertified;
  final bool isPending;
  final Color color;

  const _ActionBtn({
    required this.tier,
    required this.canRequest,
    required this.isCurrent,
    required this.isCertified,
    required this.isPending,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    bool hasShadow = false;

    if (tier.isInviteOnly) {
      label = 'Invitation';
      bg = const Color(0xFFDC2626).withOpacity(0.08);
      fg = const Color(0xFFDC2626);
    } else if (isCertified) {
      label = 'Actif';
      bg = const Color(0xFF22C55E).withOpacity(0.12);
      fg = const Color(0xFF16A34A);
    } else if (isPending) {
      label = 'En cours';
      bg = const Color(0xFFF59E0B).withOpacity(0.12);
      fg = const Color(0xFFD97706);
    } else if (canRequest) {
      label = 'S\'abonner';
      bg = color;
      fg = Colors.white;
      hasShadow = true;
    } else {
      label = 'Inclus';
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF94A3B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SCEAU — Forme scallopée (rosette de certification)
// ═══════════════════════════════════════════════════════════════

class _ScallopSealPainter extends CustomPainter {
  final Color color;
  final int points;

  _ScallopSealPainter({required this.color, this.points = 13});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.86;

    final path = Path();
    final totalPoints = points * 2;
    for (int i = 0; i < totalPoints; i++) {
      final angle = (math.pi * 2 / totalPoints) * i - math.pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          color,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScallopSealPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.points != points;
}

class _SealBadge extends StatelessWidget {
  final Color color;
  final bool active;
  const _SealBadge({required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Opacity(
        opacity: active ? 1 : 0.35, // Contraste amélioré si inactif
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            CustomPaint(
              size: const Size(62, 62),
              painter: _ScallopSealPainter(color: color),
            ),
            Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 26,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSeal extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  const _MiniSeal({
    required this.color,
    required this.icon,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ScallopSealPainter(color: color, points: 10),
          ),
          Icon(icon, color: Colors.white, size: size * 0.45),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FOOTER (Plus élégant)
// ═══════════════════════════════════════════════════════════════

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.04), // Très léger bleu marine
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0A1628).withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: const Color(0xFF0A1628).withOpacity(0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Abonnement mensuel. '
              'Standard 3\$/mois et Premium 7\$/mois : activés après paiement. '
              'Entreprise 30\$/mois : validation admin. '
              'Officiel : sur invitation THIX. '
              'Premium inclut l\'accès à la monétisation.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
