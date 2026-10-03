// lib/presentation/opportunities/opportunity_details_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/external_link_service.dart';
import 'package:thix_id/services/opportunity_service.dart';

class _Opp {
  static const navy = Color(0xFF0A1F44);
  static const navy2 = Color(0xFF123B7A);
  static const gold = Color(0xFFE3B23C);
  static const bg = Color(0xFFF5F7FB);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6EBF2);
  static const txt = Color(0xFF0F172A);
  static const sub = Color(0xFF5B6B82);
  static const mut = Color(0xFF93A1B5);
  static const green = Color(0xFF059669);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);
  static const blue = Color(0xFF2563EB);
}

class OpportunityDetailsPage extends StatefulWidget {
  final String opportunityId;
  final bool applied;

  const OpportunityDetailsPage({
    super.key,
    required this.opportunityId,
    required this.applied,
  });

  @override
  State<OpportunityDetailsPage> createState() => _OpportunityDetailsPageState();
}

class _OpportunityDetailsPageState extends State<OpportunityDetailsPage> {
  late final Future<OpportunityItem?> _opportunityFuture;
  final _service = OpportunityService();

  @override
  void initState() {
    super.override,
    _opportunityFuture = _service.fetchOpportunity(widget.opportunityId);
  }

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  Color _catColor(String c) {
    final l = c.toLowerCase();
    if (l.contains('bourse') || l.contains('formation')) return _Opp.blue;
    if (l.contains('emploi')) return _Opp.green;
    if (l.contains('subvention')) return _Opp.amber;
    if (l.contains('concours')) return const Color(0xFFDB2777);
    return _Opp.navy2;
  }

  int _daysLeft(OpportunityItem o) => o.deadline.difference(DateTime.now()).inDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _Opp.bg,
      body: FutureBuilder<OpportunityItem?>(
        future: _opportunityFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _DetailSkeleton();
          }
          final opp = snap.data;
          if (opp == null) return _buildErrorState(context, l10n);

          final color = _catColor(opp.category);
          final daysLeft = _daysLeft(opp);
          final isClosed = daysLeft < 0;

          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHero(context, opp, color),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TitleBlock(opp: opp, color: color, l10n: l10n),
                          const SizedBox(height: 20),
                          _QuickFacts(opp: opp, daysLeft: daysLeft, l10n: l10n),
                          const SizedBox(height: 20),
                          _InfoRail(opp: opp, daysLeft: daysLeft, l10n: l10n),
                          const SizedBox(height: 24),
                          _DescriptionBlock(opp: opp, l10n: l10n),
                          const SizedBox(height: 24),
                          if (opp.eligibility.isNotEmpty)
                            _EligibilityBlock(opp: opp, color: color, l10n: l10n),
                          const SizedBox(height: 24),
                          _OrganizerCard(opp: opp, color: color, l10n: l10n),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _StickyApply(
                applied: widget.applied,
                isClosed: isClosed,
                onApply: () => _handleApply(context, opp.applyUrl, l10n),
                onShare: () => _handleShare(context, opp, l10n),
                l10n: l10n,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero(BuildContext context, OpportunityItem opp, Color color) {
    final top = MediaQuery.of(context).padding.top;
    final img = opp.imageAssetPath;
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: _Opp.navy,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _handleShare(context, opp, AppLocalizations.of(context)),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: const Icon(Icons.share_rounded, color: Colors.white, size: 17),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null && img.isNotEmpty)
              (img.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _heroFallback(opp, color),
                    )
                  : (img.startsWith('assets/')
                      ? Image.asset(img, fit: BoxFit.cover)
                      : _heroFallback(opp, color)))
            else
              _heroFallback(opp, color),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _Opp.navy.withOpacity(0.45),
                    _Opp.navy,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top + 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_Opp.navy.withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Text(opp.category.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback(OpportunityItem opp, Color color) {
    final letter = (opp.organizer.isNotEmpty
            ? opp.organizer.substring(0, 1)
            : 'T')
        .toUpperCase();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, _Opp.navy],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -20,
            child: Text(
              letter,
              style: TextStyle(
                  fontSize: 320,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.08),
                  height: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: _Opp.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.opportunities),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _Opp.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _Opp.line),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: _Opp.txt),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _Opp.navy.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 42, color: _Opp.navy2),
              ),
              const SizedBox(height: 18),
              Text(_tr(l10n, 'opp_detail_not_found', 'Opportunité introuvable'),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _Opp.txt)),
              const SizedBox(height: 6),
              Text(_tr(l10n, 'opp_detail_not_found_sub', 'Cette offre a peut-être été retirée.'),
                  style: const TextStyle(fontSize: 13, color: _Opp.sub),
                  textAlign: TextAlign.center),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleApply(
      BuildContext context, String? url, AppLocalizations l10n) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_tr(l10n, 'opp_apply_no_link', 'Lien de candidature indisponible')),
        backgroundColor: _Opp.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Opp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: _Opp.gold, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check_rounded, size: 15, color: _Opp.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  _tr(l10n, 'opp_apply_confirm_title', 'Postuler maintenant ?'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _Opp.txt)),
            ),
          ],
        ),
        content: Text(
            _tr(l10n, 'opp_apply_confirm_body',
                'Vous allez être redirigé vers le site officiel de l\'organisateur.'),
            style: const TextStyle(
                fontSize: 13, color: _Opp.sub, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr(l10n, 'opp_cancel', 'Annuler'),
                style: const TextStyle(
                    color: _Opp.sub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _Opp.gold,
                foregroundColor: _Opp.navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr(l10n, 'opp_apply_confirm_btn', 'Continuer'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await ExternalLinkService.open(url);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_tr(l10n, 'opp_apply_failed', 'Impossible d\'ouvrir le lien')),
        backgroundColor: _Opp.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _handleShare(
      BuildContext context, OpportunityItem opp, AppLocalizations l10n) async {
    HapticFeedback.selectionClick();
    if (opp.applyUrl != null && opp.applyUrl!.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: opp.applyUrl!));
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_tr(l10n, 'opp_share_ok', 'Lien copié dans le presse-papiers')),
      backgroundColor: _Opp.navy2,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _TitleBlock extends StatelessWidget {
  final OpportunityItem opp;
  final Color color;
  final AppLocalizations l10n;
  const _TitleBlock({required this.opp, required this.color, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opp.title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _Opp.txt,
                        height: 1.18,
                        letterSpacing: -0.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniLogo(opp, color, 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opp.organizer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _Opp.txt)),
                          Text(_oppSubtitle(opp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _Opp.sub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _oppSubtitle(OpportunityItem opp) {
    final parts = <String>[];
    if (opp.location.isNotEmpty) parts.add(opp.location);
    if (opp.category.isNotEmpty) parts.add(opp.category);
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  Widget _miniLogo(OpportunityItem opp, Color color, double size) {
    final img = opp.imageAssetPath;
    final letter = (opp.organizer.isNotEmpty
            ? opp.organizer.substring(0, 1)
            : 'T')
        .toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: (img != null && img.isNotEmpty && img.startsWith('http'))
            ? CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _letterFallback(letter, color, size),
              )
            : _letterFallback(letter, color, size),
      ),
    );
  }

  Widget _letterFallback(String letter, Color color, double size) {
    return Container(
      color: color.withOpacity(0.14),
      alignment: Alignment.center,
      child: Text(letter,
          style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w900,
              color: color)),
    );
  }
}

class _QuickFacts extends StatelessWidget {
  final OpportunityItem opp;
  final int daysLeft;
  final AppLocalizations l10n;
  const _QuickFacts(
      {required this.opp, required this.daysLeft, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final reward = opp.rewardLabel;
    final hasReward = reward.isNotEmpty && reward != '—';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FactTile(
                icon: Icons.event_rounded,
                label: l10n.t('opp_detail_deadline'),
                value: opp.deadlineLabel,
                color: daysLeft <= 7 ? _Opp.red : _Opp.blue,
                accent: daysLeft <= 0
                    ? l10n.t('opp_closed')
                    : '$daysLeft ${l10n.t('opp_days')}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FactTile(
                icon: Icons.location_on_rounded,
                label: l10n.t('opp_detail_location'),
                value: opp.location.isEmpty ? '—' : opp.location,
                color: const Color(0xFF0891B2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FactTile(
                icon: hasReward
                    ? Icons.volunteer_activism_rounded
                    : Icons.category_rounded,
                label: hasReward
                    ? l10n.t('opp_detail_reward')
                    : l10n.t('opp_detail_category'),
                value: hasReward ? reward : opp.category,
                color: hasReward ? _Opp.green : _Opp.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FactTile(
                icon: Icons.apartment_rounded,
                label: l10n.t('opp_detail_organizer'),
                value: opp.organizer,
                color: _Opp.navy2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? accent;
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _Opp.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Opp.line),
        boxShadow: [
          BoxShadow(
              color: _Opp.navy.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _Opp.sub,
                        letterSpacing: 0.2)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _Opp.txt,
                  height: 1.25)),
          if (accent != null) ...[
            const SizedBox(height: 3),
            Text(accent!,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ],
        ],
      ),
    );
  }
}

class _InfoRail extends StatelessWidget {
  final OpportunityItem opp;
  final int daysLeft;
  final AppLocalizations l10n;
  const _InfoRail(
      {required this.opp, required this.daysLeft, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final reward = opp.rewardLabel;
    final hasReward = reward.isNotEmpty && reward != '—';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Opp.navy, _Opp.navy2],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _Opp.navy.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          _countdownRing(daysLeft),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('opp_detail_deadline_title', fallback: 'Date limite'),
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.65),
                        letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Text(opp.deadlineLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (hasReward) ...[
            Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l10n.t('opp_detail_reward', fallback: 'Récompense'),
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.65),
                        letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Text(reward,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _Opp.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _countdownRing(int daysLeft) {
    final color = daysLeft <= 0
        ? _Opp.mut
        : (daysLeft <= 7 ? _Opp.red : _Opp.gold);
    final progress = (daysLeft.clamp(0, 30)) / 30.0;
    return SizedBox(
      width: 58,
      height: 58,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${daysLeft <= 0 ? 0 : daysLeft}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1)),
              Text('j',
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.6))),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white.withOpacity(0.18);
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _DescriptionBlock extends StatelessWidget {
  final OpportunityItem opp;
  final AppLocalizations l10n;
  const _DescriptionBlock({required this.opp, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (opp.description.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.article_rounded,
            label: l10n.t('opp_detail_about', fallback: 'À propos'),
            color: _Opp.navy2),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Opp.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Opp.line),
          ),
          child: Text(opp.description,
              style: const TextStyle(
                  fontSize: 14,
                  color: _Opp.txt,
                  height: 1.7,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _EligibilityBlock extends StatelessWidget {
  final OpportunityItem opp;
  final Color color;
  final AppLocalizations l10n;
  const _EligibilityBlock(
      {required this.opp, required this.color, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.how_to_reg_rounded,
            label: l10n.t('opp_detail_eligibility', fallback: 'Critères d\'éligibilité'),
            color: color),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Opp.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Opp.line),
          ),
          child: Column(
            children: [
              for (int i = 0; i < opp.eligibility.length; i++) ...[
                _EligibilityItem(text: opp.eligibility[i], color: color),
                if (i < opp.eligibility.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(height: 1, color: _Opp.line),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EligibilityItem extends StatelessWidget {
  final String text;
  final Color color;
  const _EligibilityItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.check_rounded, size: 13, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13.5,
                    color: _Opp.txt,
                    height: 1.45,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final OpportunityItem opp;
  final Color color;
  final AppLocalizations l10n;
  const _OrganizerCard(
      {required this.opp, required this.color, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Opp.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Opp.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.business_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('opp_detail_organized_by', fallback: 'Organisé par'),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _Opp.sub,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(opp.organizer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _Opp.txt)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _Opp.mut, size: 20),
        ],
      ),
    );
  }
}

class _StickyApply extends StatelessWidget {
  final bool applied;
  final bool isClosed;
  final VoidCallback onApply;
  final VoidCallback onShare;
  final AppLocalizations l10n;

  const _StickyApply({
    required this.applied,
    required this.isClosed,
    required this.onApply,
    required this.onShare,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final disabled = applied || isClosed;
    final label = isClosed
        ? l10n.t('opp_closed')
        : (applied
            ? l10n.t('opp_applied', fallback: 'Candidature envoyée')
            : l10n.t('opp_apply_now', fallback: 'Postuler maintenant'));
    final icon = isClosed
        ? Icons.block_rounded
        : (applied ? Icons.verified_rounded : Icons.open_in_new_rounded);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 14, 18, bottom + 14),
        decoration: BoxDecoration(
          color: _Opp.card,
          border: const Border(top: BorderSide(color: _Opp.line, width: 1)),
          boxShadow: [
            BoxShadow(
                color: _Opp.navy.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, -6)),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onShare,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _Opp.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _Opp.line),
                ),
                child: const Icon(Icons.share_rounded,
                    color: _Opp.navy2, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: disabled ? null : onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: disabled ? _Opp.mut.withOpacity(0.3) : _Opp.gold,
                    foregroundColor: disabled ? _Opp.mut : _Opp.navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionTitle({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 9),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _Opp.txt,
                letterSpacing: -0.2)),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _Opp.bg,
      body: Column(
        children: [
          Container(height: top + 320, color: _Opp.navy),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 24,
                    width: 280,
                    decoration: BoxDecoration(
                      color: _Opp.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: _Opp.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: _Opp.line,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: _Opp.line,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _Opp.line,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
