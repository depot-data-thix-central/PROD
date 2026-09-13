// lib/presentation/opportunities/opportunities_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';
// 🛡️ Sécurité
import 'package:thix_id/core/security/thix_input_guard.dart';

import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';

// ============================================================================
// PAGE PRINCIPALE — OPPORTUNITÉS HUB (ENTERPRISE PREMIUM)
// ============================================================================
class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage> {
  final OpportunityService _service = OpportunityService();
  late Future<List<OpportunityItem>> _opportunitiesFuture;

  final TextEditingController _searchCtrl = TextEditingController();
  int _selectedCategoryIndex = 0;
  int _sortMode = 0; // 0 = échéance proche, 1 = récentes, 2 = A→Z

  final List<String> _categories = const [
    'Toutes',
    'Bourses',
    'Emplois',
    'Subventions',
    'Concours',
  ];

  @override
  void initState() {
    super.initState();
    _opportunitiesFuture = _service.listOpportunities();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── COULEURS PAR CATÉGORIE ───
  Color _catColor(String c) {
    final l = c.toLowerCase();
    if (l.contains('bourse')) return const Color(0xFF6366F1);
    if (l.contains('emploi')) return const Color(0xFF10B981);
    if (l.contains('subvention')) return const Color(0xFFF59E0B);
    if (l.contains('concours')) return const Color(0xFFEC4899);
    return ThixPolicy.primaryDeep;
  }

  // ─── FILTRAGE + RECHERCHE + TRI (contenu sanitizé) ───
  List<OpportunityItem> _applyFilters(List<OpportunityItem> all) {
    var list = all;
    final q = ThixInputGuard.text(_searchCtrl.text, maxLength: 60, fallback: '');
    if (q.isNotEmpty) {
      final ql = q.toLowerCase();
      list = list.where((o) {
        return ThixInputGuard.text(o.title, maxLength: 200).toLowerCase().contains(ql) ||
            ThixInputGuard.text(o.organizer, maxLength: 200).toLowerCase().contains(ql) ||
            o.category.toLowerCase().contains(ql);
      }).toList();
    }
    if (_selectedCategoryIndex > 0) {
      final target = _categories[_selectedCategoryIndex].toLowerCase();
      list = list.where((o) => o.category.toLowerCase().contains(target)).toList();
    }
    switch (_sortMode) {
      case 1:
        list = [...list]..sort((a, b) => b.deadline.compareTo(a.deadline));
        break;
      case 2:
        list = [...list]
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default:
        list = [...list]..sort((a, b) => a.deadline.compareTo(b.deadline));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final bool isAdmin = supabaseUser?.appMetadata?['role'] == 'admin' ||
        supabaseUser?.userMetadata?['is_admin'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/opportunities/admin');
              },
              backgroundColor: ThixPolicy.inkDeep,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
              label: const Text('Espace Admin',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            )
          : null,
      body: RefreshIndicator(
        color: ThixPolicy.primaryDeep,
        onRefresh: () async {
          setState(() => _opportunitiesFuture = _service.listOpportunities());
          await _opportunitiesFuture;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildHeroHeader(),
            // ── Barre recherche + filtres (chevauchement premium) ──
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -26),
                child: _buildControlPanel(),
              ),
            ),
            // ── Bandeau de confiance sécurité ──
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: _buildTrustStrip(),
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<OpportunityItem>>(
                future: _opportunitiesFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return _buildSkeleton();
                  }
                  if (snap.hasError) {
                    return _buildErrorState();
                  }
                  final allList = snap.data ?? const <OpportunityItem>[];
                  if (allList.isEmpty) return _buildEmptyState();

                  final list = _applyFilters(allList);
                  final featured = allList
                      .where((o) =>
                          o.deadlineLabel.contains('Urgent') ||
                          o.category.toLowerCase().contains('subvention'))
                      .toList();
                  final carouselItems =
                      featured.isNotEmpty ? featured : allList.take(3).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (carouselItems.isNotEmpty && _selectedCategoryIndex == 0 && _searchCtrl.text.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(Icons.local_fire_department_rounded,
                                  size: 16, color: ThixPolicy.danger),
                              SizedBox(width: 6),
                              Text('URGENT & À LA UNE',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: ThixPolicy.danger,
                                      letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        FeaturedCountdownCarousel(
                          opportunities: carouselItems,
                          onOpen: (o) => context.push('/opportunities/${o.id}'),
                        ),
                        const SizedBox(height: 28),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOUTES LES OFFRES',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: ThixPolicy.textSecondary,
                                    letterSpacing: 1.2)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThixPolicy.primaryDeep.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${list.length} disponibles',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: ThixPolicy.primaryDeep)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: list.isEmpty
                            ? _buildNoResult()
                            : Column(
                                children: list
                                    .map((o) => _EnterpriseCard(
                                          item: o,
                                          accent: _catColor(o.category),
                                          onOpen: () => context
                                              .push('/opportunities/${o.id}'),
                                        ))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ HERO HEADER (dark enterprise) ═══════════════
  Widget _buildHeroHeader() {
    return SliverAppBar(
      expandedHeight: 218,
      pinned: true,
      backgroundColor: ThixPolicy.inkDeep,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
        onPressed: () => context.go(AppRoutes.home),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B1F3A), Color(0xFF123055), Color(0xFF0B1F3A)],
            ),
          ),
          child: Stack(
            children: [
              // Glows décoratifs
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ThixPolicy.gold.withOpacity(0.10),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ThixPolicy.primaryDeep.withOpacity(0.18),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThixPolicy.gold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: ThixPolicy.gold.withOpacity(0.4)),
                            ),
                            child: const Icon(Icons.bolt_rounded,
                                color: ThixPolicy.gold, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Opportunités Hub',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    letterSpacing: -0.5)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    size: 12, color: Color(0xFF4ADE80)),
                                SizedBox(width: 4),
                                Text('VÉRIFIÉ',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF4ADE80),
                                        letterSpacing: 1)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                          'Bourses, emplois, subventions & concours — sélection officielle THIX',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white60, height: 1.4)),
                      const Spacer(),
                      // ── Stats enterprise ──
                      FutureBuilder<List<OpportunityItem>>(
                        future: _opportunitiesFuture,
                        builder: (context, snap) {
                          final all = snap.data ?? const <OpportunityItem>[];
                          final closing7 = all
                              .where((o) =>
                                  o.deadline.difference(DateTime.now()).inDays <=
                                      7 &&
                                  o.deadline.isAfter(DateTime.now()))
                              .length;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 34),
                            child: Row(
                              children: [
                                _heroStat('${all.length}', 'Offres actives'),
                                _heroDivider(),
                                _heroStat('$closing7', 'Échéance < 7 j'),
                                _heroDivider(),
                                _heroStat(
                                    '${all.where((o) => o.deadlineLabel.contains('Urgent')).length}',
                                    'Urgentes'),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: ThixPolicy.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10, letterSpacing: 0.4)),
        ],
      ),
    );
  }

  Widget _heroDivider() =>
      Container(width: 1, height: 28, color: Colors.white12);

  // ═══════════════ PANNEAU RECHERCHE + CATÉGORIES + TRI ═══════════════
  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontSize: 13, color: ThixPolicy.textMain),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un programme, une bourse…',
                        hintStyle: TextStyle(
                            fontSize: 13, color: ThixPolicy.textMuted),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: ThixPolicy.textSecondary),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Menu de tri
                PopupMenuButton<int>(
                  tooltip: 'Trier',
                  onSelected: (v) => setState(() => _sortMode = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: Text('Échéance la plus proche')),
                    PopupMenuItem(value: 1, child: Text('Plus récentes')),
                    PopupMenuItem(value: 2, child: Text('Ordre alphabétique')),
                  ],
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ThixPolicy.inkDeep,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sort_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategoryIndex == index;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategoryIndex = index);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? ThixPolicy.inkDeep : const Color(0xFFF6F8FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? ThixPolicy.inkDeep
                                : Colors.grey.shade200),
                      ),
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : ThixPolicy.textSecondary),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ BANDEAU CONFIANCE / SÉCURITÉ ═══════════════
  Widget _buildTrustStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4ADE80).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_moon_rounded, size: 16, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offres vérifiées par THIX • Liens sécurisés (HTTPS uniquement) • Contenu filtré anti-injection',
                style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ ÉTATS ═══════════════
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _Shimmer(width: 70, height: 18, radius: 6),
                      const Spacer(),
                      const _Shimmer(width: 90, height: 18, radius: 6),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _Shimmer(width: double.infinity, height: 16, radius: 6),
                  const SizedBox(height: 8),
                  const _Shimmer(width: 180, height: 16, radius: 6),
                  const SizedBox(height: 14),
                  const _Shimmer(width: double.infinity, height: 1, radius: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      _Shimmer(width: 110, height: 16, radius: 6),
                      Spacer(),
                      _Shimmer(width: 130, height: 24, radius: 8),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 30),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: ThixPolicy.textSecondary),
            const SizedBox(height: 12),
            const Text('Connexion interrompue',
                style: TextStyle(
                    color: ThixPolicy.inkDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Vérifiez votre réseau puis réessayez.',
                style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _opportunitiesFuture = _service.listOpportunities()),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.inkDeep,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 30),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 14),
                ],
              ),
              child: const Icon(Icons.workspaces_outline, // <- corrigé ici
                  size: 34, color: ThixPolicy.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('Aucune opportunité active',
                style: TextStyle(
                    color: ThixPolicy.inkDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Revenez très bientôt pour de nouvelles offres.',
                style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }


  Widget _buildNoResult() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.filter_alt_off_rounded,
              size: 28, color: ThixPolicy.textSecondary),
          const SizedBox(height: 8),
          const Text('Aucun résultat pour ces filtres',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _selectedCategoryIndex = 0);
            },
            child: const Text('Réinitialiser les filtres'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE ENTREPRISE (accent couleur + badge vérifié + countdown)
// ============================================================================
class _EnterpriseCard extends StatelessWidget {
  final OpportunityItem item;
  final Color accent;
  final VoidCallback onOpen;

  const _EnterpriseCard({
    required this.item,
    required this.accent,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final safeTitle = ThixInputGuard.text(item.title, maxLength: 120);
    final safeOrg = ThixInputGuard.text(item.organizer, maxLength: 80);
    final safeReward = ThixInputGuard.text(item.rewardLabel, maxLength: 60);
    final safeCat = ThixInputGuard.text(item.category, maxLength: 30);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barre d'accent catégorie
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(safeCat.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9,
                                    color: accent,
                                    fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              size: 13, color: Color(0xFF16A34A)),
                          const Spacer(),
                          CountdownTimerWidget(
                              targetDate: ThixInputGuard.safeDate(item.deadline)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(safeTitle,
                          style: const TextStyle(
                              fontSize: 15,
                              color: ThixPolicy.inkDeep,
                              fontWeight: FontWeight.w900,
                              height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.business_rounded,
                              size: 13, color: ThixPolicy.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(safeOrg,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: ThixPolicy.textSecondary,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard_rounded,
                              size: 14, color: ThixPolicy.success),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(safeReward,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: ThixPolicy.success,
                                    fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: ThixPolicy.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPTE À REBOURS TEMPS RÉEL (premium)
// ============================================================================
class CountdownTimerWidget extends StatefulWidget {
  final DateTime targetDate;
  const CountdownTimerWidget({super.key, required this.targetDate});

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final diff = widget.targetDate.difference(DateTime.now());
    if (mounted) {
      setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('CLÔTURÉ',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 0.5)),
      );
    }
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;
    final timeStr =
        '${days}j ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThixPolicy.danger.withOpacity(0.12),
            ThixPolicy.danger.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: ThixPolicy.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(timeStr,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: ThixPolicy.danger,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

// ============================================================================
// CARROUSEL À LA UNE (bordure dégradée or)
// ============================================================================
class FeaturedCountdownCarousel extends StatefulWidget {
  final List<OpportunityItem> opportunities;
  final ValueChanged<OpportunityItem> onOpen;

  const FeaturedCountdownCarousel({
    super.key,
    required this.opportunities,
    required this.onOpen,
  });

  @override
  State<FeaturedCountdownCarousel> createState() =>
      _FeaturedCountdownCarouselState();
}

class _FeaturedCountdownCarouselState extends State<FeaturedCountdownCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.opportunities.isEmpty) return;
      final next = (_index + 1) % widget.opportunities.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opportunities.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 250,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.opportunities.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final o = widget.opportunities[i];
                return Padding(
                  padding: EdgeInsets.only(
                      right: i == widget.opportunities.length - 1 ? 20 : 12,
                      left: i == 0 ? 20 : 0),
                  child: _FeaturedCard(
                      opportunity: o, onTap: () => widget.onOpen(o)),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.opportunities.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 4,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? ThixPolicy.gold : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final OpportunityItem opportunity;
  final VoidCallback onTap;

  const _FeaturedCard({required this.opportunity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final safeUrl = ThixInputGuard.url(opportunity.imageAssetPath);
    final safeTitle = ThixInputGuard.text(opportunity.title, maxLength: 110);
    final safeOrg = ThixInputGuard.text(opportunity.organizer, maxLength: 70);
    final safeCat = ThixInputGuard.text(opportunity.category, maxLength: 25);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFF8A6D1A), Color(0xFFD4AF37)],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            color: ThixPolicy.inkDeep,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (safeUrl != null)
                CachedNetworkImage(
                  imageUrl: safeUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: ThixPolicy.inkDeep),
                )
              else
                Container(color: ThixPolicy.inkDeep),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      ThixPolicy.inkDeep.withOpacity(0.97),
                      ThixPolicy.inkDeep.withOpacity(0.45),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('EN VEDETTE',
                      style: TextStyle(
                          fontSize: 9,
                          color: ThixPolicy.inkDeep,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(safeCat.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                        CountdownTimerWidget(
                            targetDate:
                                ThixInputGuard.safeDate(opportunity.deadline)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(safeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.2)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.corporate_fare_rounded,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(safeOrg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600)),
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
    );
  }
}

// ============================================================================
// SKELETON SHIMMER
// ============================================================================
class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _Shimmer({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final v = _ctrl.value;
        return Container(
          width: widget.width == double.infinity ? null : widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * v, 0),
              end: Alignment(1 - 2 * v, 0),
              colors: const [
                Color(0xFFEEF2F7),
                Color(0xFFE2E8F0),
                Color(0xFFEEF2F7),
              ],
            ),
          ),
        );
      },
    );
  }
}
