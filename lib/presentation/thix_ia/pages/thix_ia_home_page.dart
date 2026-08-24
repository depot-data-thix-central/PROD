// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';
import '../providers/thix_ia_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFIL SUPABASE
// ─────────────────────────────────────────────────────────────────────────────
final thixIaCurrentProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select(
          'id, thix_id, display_name, full_name, avatar_url, photo_url, '
          'occupation, profession, city, country, role_title',
        )
        .eq('id', user.id)
        .maybeSingle();
    if (row != null) return row;
  } catch (_) {}
  return {
    'id': user.id,
    'display_name':
        user.userMetadata?['display_name'] ??
        user.email?.split('@').first ??
        'Utilisateur',
    'avatar_url': user.userMetadata?['avatar_url'],
  };
});

class ThixIaHomePage extends ConsumerStatefulWidget {
  const ThixIaHomePage({super.key});

  @override
  ConsumerState<ThixIaHomePage> createState() => _ThixIaHomePageState();
}

class _ThixIaHomePageState extends ConsumerState<ThixIaHomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(projectsProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final profileAsync = ref.watch(thixIaCurrentProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Stack(
        children: [
          // Halo glass profond
          Positioned(
            top: -80,
            right: -60,
            child: _halo(220, ThixPolicy.primary.withOpacity(0.18)),
          ),
          Positioned(
            top: 180,
            left: -100,
            child: _halo(280, const Color(0xFF7C3AED).withOpacity(0.10)),
          ),
          Positioned(
            bottom: 120,
            right: -40,
            child: _halo(160, ThixPolicy.gold.withOpacity(0.08)),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: ThixPolicy.primary,
              onRefresh: () async {
                ref.invalidate(thixIaCurrentProfileProvider);
                await ref.read(projectsProvider.notifier).refresh();
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _TopBar(profileAsync: profileAsync)),
                  SliverToBoxAdapter(child: _UserHeader(profileAsync: profileAsync)),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(child: _HeroBanner(
                    onAnalyze: () => context.push(ThixIARoutes.createProject),
                  )),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(
                    child: _SectionTitle('Que souhaitez-vous faire aujourd\'hui ?'),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: _MainActions(
                      onCreate: () => context.push(ThixIARoutes.createProject),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(
                      'Les Moteurs THIX IA',
                      seeAll: true,
                      onSeeAll: () => context.push(ThixIARoutes.projects),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  const SliverToBoxAdapter(child: _MotorsRow()),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(
                      'Mes dernières analyses',
                      seeAll: true,
                      onSeeAll: () => context.push(ThixIARoutes.projects),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: _RecentAnalyses(
                      projectsAsync: projectsAsync,
                      onOpen: (code) =>
                          context.push(ThixIARoutes.projectDetailPath(code)),
                      onCreate: () => context.push(ThixIARoutes.createProject),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  const SliverToBoxAdapter(child: _SectionTitle('Aperçu rapide')),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _QuickStats(projectsAsync: projectsAsync)),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _halo(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  const _TopBar({required this.profileAsync});
  final AsyncValue<Map<String, dynamic>?> profileAsync;

  @override
  Widget build(BuildContext context) {
    final p = profileAsync.valueOrNull;
    final city = (p?['city'] as String?)?.trim();
    final country = (p?['country'] as String?)?.trim();
    final loc = [
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // Localisation
          Expanded(
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, size: 16, color: ThixPolicy.textMain),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    loc.isNotEmpty ? loc : '—',
                    style: ThixPolicy.labelStyle.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ThixPolicy.textSecondary),
              ],
            ),
          ),
          // Logo centre
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: ThixPolicy.primary),
                  const SizedBox(width: 4),
                  Text(
                    'THIX IA',
                    style: ThixPolicy.h3Style.copyWith(
                      color: ThixPolicy.primaryDeep,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              Text(
                'Business Intelligence Africa',
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          // Droite
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _glassChip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 14, color: ThixPolicy.textMain),
                      const SizedBox(width: 4),
                      Text('FR', style: ThixPolicy.labelStyle.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
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
}

// ═══════════════════════════════════════════════════════════════════════════
// USER HEADER (Supabase profiles)
// ═══════════════════════════════════════════════════════════════════════════
class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.profileAsync});
  final AsyncValue<Map<String, dynamic>?> profileAsync;

  @override
  Widget build(BuildContext context) {
    return profileAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(radius: 30, backgroundColor: Color(0xFFE2E8F0)),
            SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 100, height: 12, child: ColoredBox(color: Color(0xFFE2E8F0))),
                SizedBox(height: 8),
                SizedBox(width: 140, height: 18, child: ColoredBox(color: Color(0xFFE2E8F0))),
              ],
            ),
          ],
        ),
      ),
      error: (_, __) => _content('Utilisateur', null, null),
      data: (p) {
        final name = _pick(p, ['display_name', 'full_name']) ?? 'Utilisateur';
        final photo = _pick(p, ['avatar_url', 'photo_url']);
        final role = _pick(p, ['role_title', 'occupation', 'profession']);
        return _content(name, photo, role);
      },
    );
  }

  String? _pick(Map<String, dynamic>? p, List<String> keys) {
    if (p == null) return null;
    for (final k in keys) {
      final v = (p[k] as String?)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Widget _content(String name, String? photo, String? role) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Bonjour' : h < 18 ? 'Bon après-midi' : 'Bonsoir';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: ThixPolicy.primary.withOpacity(0.12),
                backgroundImage:
                    (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                child: (photo == null || photo.isEmpty)
                    ? Text(
                        name[0].toUpperCase(),
                        style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.primary),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: ThixPolicy.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet,', style: ThixPolicy.bodySmallStyle),
                Text(
                  name,
                  style: ThixPolicy.h2Style.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (role != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.gold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 13, color: ThixPolicy.premiumAccent),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            role,
                            style: ThixPolicy.microStyle.copyWith(
                              color: ThixPolicy.premiumAccent,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO BANNER (design maquette)
// ═══════════════════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B1F4A), Color(0xFF123B7A), Color(0xFF1A4A9C)],
            ),
          ),
          child: Stack(
            children: [
              // Points réseau Afrique (décoratif pur UI)
              Positioned(
                right: -20,
                top: 10,
                bottom: 10,
                width: 180,
                child: CustomPaint(painter: _AfricaNetworkPainter()),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transformez\nvos idées en succès.',
                      style: ThixPolicy.h1Style.copyWith(
                        color: Colors.white,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'THIX IA analyse, construit et sécurise\nvos projets pour des décisions\néclairées en Afrique.',
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      child: InkWell(
                        onTap: onAnalyze,
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 16, color: ThixPolicy.primaryDeep),
                              const SizedBox(width: 8),
                              Text(
                                'Analyser mon idée',
                                style: ThixPolicy.labelStyle.copyWith(
                                  color: ThixPolicy.primaryDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AfricaNetworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = Colors.white.withOpacity(0.25);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;
    final pts = <Offset>[
      Offset(size.width * 0.35, size.height * 0.15),
      Offset(size.width * 0.55, size.height * 0.22),
      Offset(size.width * 0.42, size.height * 0.38),
      Offset(size.width * 0.68, size.height * 0.32),
      Offset(size.width * 0.50, size.height * 0.55),
      Offset(size.width * 0.72, size.height * 0.48),
      Offset(size.width * 0.38, size.height * 0.70),
      Offset(size.width * 0.60, size.height * 0.75),
      Offset(size.width * 0.78, size.height * 0.62),
    ];
    for (var i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], line);
    }
    for (final p in pts) {
      canvas.drawCircle(p, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION TITLE
// ═══════════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.seeAll = false, this.onSeeAll});
  final String title;
  final bool seeAll;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (seeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    'Voir tous',
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      color: ThixPolicy.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: ThixPolicy.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTIONS PRINCIPALES
// ═══════════════════════════════════════════════════════════════════════════
class _MainActions extends StatelessWidget {
  const _MainActions({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActionItem('Analyser\nmon idée', 'Étude complète\nde faisabilité',
          Icons.lightbulb_rounded, const Color(0xFF2D6CDF), onCreate),
      _ActionItem('Étudier\nun marché', 'Données, tendances\net opportunités',
          Icons.bar_chart_rounded, const Color(0xFF16A34A), onCreate),
      _ActionItem('Créer un\nBusiness Plan', 'Plan stratégique\ncomplet',
          Icons.description_rounded, const Color(0xFF7C3AED), onCreate),
      _ActionItem('Vérifier\nréglementation', 'Lois, licences,\nautorisations',
          Icons.balance_rounded, const Color(0xFFF59E0B), onCreate),
    ];

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _GlassActionCard(item: items[i]),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem(this.title, this.sub, this.icon, this.color, this.onTap);
  final String title, sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _GlassActionCard extends StatelessWidget {
  const _GlassActionCard({required this.item});
  final _ActionItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: _glassContainer(
        width: 142,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const Spacer(),
            Text(item.title, style: ThixPolicy.labelStyle.copyWith(height: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(item.sub, style: ThixPolicy.microStyle.copyWith(height: 1.15, color: ThixPolicy.textSecondary)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.arrow_forward_rounded, size: 14, color: ThixPolicy.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MOTEURS
// ═══════════════════════════════════════════════════════════════════════════
class _MotorsRow extends StatelessWidget {
  const _MotorsRow();

  @override
  Widget build(BuildContext context) {
    final motors = [
      ('Research', 'Données & Sources', Icons.search_rounded, ThixPolicy.primary),
      ('Market', 'Intelligence Marché', Icons.trending_up_rounded, const Color(0xFF16A34A)),
      ('Business', 'Stratégie & Plan', Icons.work_rounded, const Color(0xFF4F46E5)),
      ('Finance', 'Modélisation', Icons.attach_money_rounded, const Color(0xFFF59E0B)),
      ('Legal', 'Droit & Règle', Icons.balance_rounded, const Color(0xFFEF4444)),
      ('Design', 'Maquette & UI', Icons.edit_rounded, const Color(0xFF0D9488)),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: motors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final m = motors[i];
          return Column(
            children: [
              _glassContainer(
                padding: const EdgeInsets.all(14),
                child: Icon(m.$3, color: m.$4, size: 22),
              ),
              const SizedBox(height: 8),
              Text(m.$1, style: ThixPolicy.labelStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(m.$2, style: ThixPolicy.microStyle.copyWith(fontSize: 9)),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DERNIÈRES ANALYSES (projets Supabase)
// ═══════════════════════════════════════════════════════════════════════════
class _RecentAnalyses extends StatelessWidget {
  const _RecentAnalyses({
    required this.projectsAsync,
    required this.onOpen,
    required this.onCreate,
  });
  final AsyncValue projectsAsync;
  final void Function(String code) onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('Erreur : $e', style: ThixPolicy.bodySmallStyle),
      ),
      data: (projects) {
        final list = (projects is List<ThixProject>) ? projects : <ThixProject>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _glassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Aucune analyse pour le moment.',
                      style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
                  const SizedBox(height: 10),
                  TextButton(onPressed: onCreate, child: const Text('Lancer ma première analyse')),
                ],
              ),
            ),
          );
        }

        final recent = list.take(3).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: recent.map((p) {
              final pct = (p.progress * 100).clamp(0, 100).toInt();
              final statusLabel = _statusLabel(p);
              final badge = _docBadge(p);
              final iconColor = _statusColor(p);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onOpen(p.projectCode),
                  child: _glassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_statusIcon(p), color: iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.summary?.isNotEmpty == true
                                    ? p.summary!
                                    : '${p.sector} • ${p.country}',
                                style: ThixPolicy.microStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (p.status == 'active' || p.status == 'analyzing') ...[
                              Text('$pct%',
                                  style: ThixPolicy.labelStyle.copyWith(
                                    color: ThixPolicy.success,
                                    fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 48,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: pct / 100,
                                    backgroundColor: ThixPolicy.surfaceStrong,
                                    valueColor: AlwaysStoppedAnimation(ThixPolicy.success),
                                  ),
                                ),
                              ),
                            ] else
                              Text(
                                statusLabel,
                                style: ThixPolicy.microStyle.copyWith(
                                  color: iconColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badge.$2.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge.$1,
                            style: ThixPolicy.microStyle.copyWith(
                              color: badge.$2,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.more_vert_rounded, size: 18, color: ThixPolicy.textMuted),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _statusLabel(ThixProject p) {
    switch (p.status) {
      case 'archived':
        return 'Archivé';
      case 'paused':
        return 'En pause';
      case 'draft':
        return 'Brouillon';
      default:
        final pct = (p.progress * 100).toInt();
        return pct >= 100 ? 'Terminé' : 'En cours';
    }
  }

  Color _statusColor(ThixProject p) {
    if (p.progress >= 1.0) return const Color(0xFF16A34A);
    if (p.status == 'analyzing' || p.status == 'active') return ThixPolicy.primary;
    if (p.status == 'draft') return const Color(0xFFF59E0B);
    return ThixPolicy.textMuted;
  }

  IconData _statusIcon(ThixProject p) {
    final s = p.sector.toLowerCase();
    if (s.contains('fin') || s.contains('market')) return Icons.bar_chart_rounded;
    if (s.contains('health') || s.contains('santé')) return Icons.description_rounded;
    if (s.contains('legal') || s.contains('droit')) return Icons.balance_rounded;
    return Icons.insert_chart_rounded;
  }

  (String, Color) _docBadge(ThixProject p) {
    if (p.documentsCount > 0) return ('DOCX', const Color(0xFF2563EB));
    return ('PDF', const Color(0xFFEF4444));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATS RÉELLES SUPABASE
// ═══════════════════════════════════════════════════════════════════════════
class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.projectsAsync});
  final AsyncValue projectsAsync;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        final list = (projects is List<ThixProject>) ? projects : <ThixProject>[];
        final total = list.length;
        final active = list.where((p) => p.isActive || p.status == 'draft').length;
        final analyses = list.fold<int>(0, (s, p) => s + p.analysesCount);
        final countries = list.map((p) => p.country).where((c) => c.trim().isNotEmpty).toSet();
        final avgProgress = list.isEmpty
            ? 0
            : (list.fold<double>(0, (s, p) => s + p.progress) / list.length * 100).round();

        final stats = [
          _Stat(analyses.toString(), 'Analyses réalisées',
              analyses == 0 ? 'Aucune encore' : 'Sur vos projets',
              Icons.insights_rounded, const Color(0xFF7C3AED)),
          _Stat(active.toString(), 'Projets en cours', '$total au total',
              Icons.track_changes_rounded, const Color(0xFF16A34A)),
          _Stat(countries.length.toString(), 'Pays analysés',
              countries.isEmpty ? '—' : countries.take(4).join(', '),
              Icons.public_rounded, const Color(0xFFF59E0B)),
          _Stat('$avgProgress%', 'Progression moy.',
              list.isEmpty ? '—' : 'Tous projets',
              Icons.verified_rounded, const Color(0xFF2563EB)),
        ];

        return SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final s = stats[i];
              return _glassContainer(
                width: 200,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, color: s.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(s.value, style: ThixPolicy.h2Style.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s.title,
                                  style: ThixPolicy.microStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: ThixPolicy.textMain,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            s.sub,
                            style: ThixPolicy.microStyle.copyWith(color: s.color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Stat {
  const _Stat(this.value, this.title, this.sub, this.icon, this.color);
  final String value, title, sub;
  final IconData icon;
  final Color color;
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS HELPERS
// ═══════════════════════════════════════════════════════════════════════════
Widget _glassContainer({
  double? width,
  required EdgeInsets padding,
  required Widget child,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F44).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

Widget _glassChip({required Widget child}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ThixPolicy.border),
    ),
    child: child,
  );
}
