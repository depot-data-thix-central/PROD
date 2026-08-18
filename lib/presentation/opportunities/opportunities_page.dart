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

import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';

class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage> {
  final OpportunityService _service = OpportunityService();
  late Future<List<OpportunityItem>> _opportunitiesFuture;
  
  // Catégories redéfinies (3-4 principales + Toutes)
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['Toutes', 'Bourses', 'Emplois', 'Subventions', 'Concours'];

  @override
  void initState() {
    super.initState();
    _opportunitiesFuture = _service.listOpportunities();
  }

  @override
  Widget build(BuildContext context) {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final bool isAdmin = supabaseUser?.appMetadata?['role'] == 'admin' || supabaseUser?.userMetadata?['is_admin'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fond ultra-propre style dashboard moderne
      
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
              label: const Text('Espace Admin', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            )
          : null,
          
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(context),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 20),
                _buildCategoryTabs(),
                const SizedBox(height: 24),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: FutureBuilder<List<OpportunityItem>>(
              future: _opportunitiesFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: ThixPolicy.primaryDeep, strokeWidth: 3)),
                  );
                }

                final allList = snap.data ?? const <OpportunityItem>[];
                if (allList.isEmpty) {
                  return _buildEmptyState();
                }

                // Filtrage par catégorie sélectionnée
                List<OpportunityItem> list = allList;
                if (_selectedCategoryIndex > 0) {
                  final targetCat = _categories[_selectedCategoryIndex].toLowerCase();
                  list = allList.where((o) => o.category.toLowerCase().contains(targetCat)).toList();
                }

                // Carrousel "À la une" : On filtre uniquement les offres en mode "countdown" (Urgent choisi par l'admin)
                // S'il n'y en a pas, on prend les 3 premières par défaut.
                final featuredList = allList.where((o) => o.deadlineLabel.contains('Urgent') || o.category.toLowerCase().contains('subvention')).toList();
                final carouselItems = featuredList.isNotEmpty ? featuredList : allList.take(3).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (carouselItems.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text('URGENT & À LA UNE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: ThixPolicy.danger, letterSpacing: 1.2)),
                      ),
                      const SizedBox(height: 12),
                      FeaturedCountdownCarousel(
                        opportunities: carouselItems,
                        onOpen: (o) => context.push('/opportunities/${o.id}'),
                      ),
                      const SizedBox(height: 32),
                    ],
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOUTES LES OFFRES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: ThixPolicy.textSecondary, letterSpacing: 1.2)),
                          Text('${list.length} disponibles', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.primaryDeep)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: list.isEmpty 
                          ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Aucune offre dans cette catégorie.', style: TextStyle(color: ThixPolicy.textSecondary))))
                          : Column(
                              children: list.map((o) => _NewEnterpriseCard(
                                item: o,
                                onOpen: () => context.push('/opportunities/${o.id}'),
                              )).toList(),
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
    );
  }

  // ============================================================
  // COMPOSANTS DESIGN MODERNES
  // ============================================================

  Widget _buildModernAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.inkDeep, size: 18),
        onPressed: () => context.go(AppRoutes.home),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.bolt_rounded, color: ThixPolicy.primaryDeep, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Opportunités Hub', style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: const TextField(
          style: TextStyle(fontSize: 13, color: ThixPolicy.textMain),
          decoration: InputDecoration(
            hintText: 'Rechercher un programme, une bourse...',
            hintStyle: TextStyle(fontSize: 13, color: ThixPolicy.textMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? ThixPolicy.inkDeep : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? ThixPolicy.inkDeep : Colors.grey.shade200),
                boxShadow: isSelected ? [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))] : [],
              ),
              child: Text(
                _categories[index],
                style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : ThixPolicy.textSecondary),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
              child: const Icon(Icons.inbox_rounded, size: 36, color: ThixPolicy.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('Aucune opportunité active', style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Revenez très bientôt pour de nouvelles offres.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET COMPTE À REBOURS EN TEMPS RÉEL (ROUGE JJ : HH : MM : SS)
// ============================================================
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
    final now = DateTime.now();
    final diff = widget.targetDate.difference(now);
    if (mounted) {
      setState(() {
        _timeLeft = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;

    String timeStr = '${days}j : ${hours.toString().padLeft(2, '0')}h : ${minutes.toString().padLeft(2, '0')}m : ${seconds.toString().padLeft(2, '0')}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, size: 14, color: ThixPolicy.danger),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: ThixPolicy.danger, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE OFFRE CLASSIQUE (REORGANISÉE & ULTRA-PROPRE)
// ============================================================
class _NewEnterpriseCard extends StatelessWidget {
  final OpportunityItem item;
  final VoidCallback onOpen;

  const _NewEnterpriseCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final img = item.imageAssetPath;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (img != null && img.trim().isNotEmpty)
              SizedBox(
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    img.startsWith('http') ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                        child: Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (img == null || img.trim().isEmpty)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(6)),
                          child: Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 9, color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  if (img == null || img.trim().isEmpty) const SizedBox(height: 8),

                  Text(item.title, style: const TextStyle(fontSize: 15, color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 14, color: ThixPolicy.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item.organizer, style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.rewardLabel,
                          style: const TextStyle(fontSize: 13, color: ThixPolicy.success, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Affichage du compte à rebours rouge en temps réel ou de la date limite
                      CountdownTimerWidget(targetDate: item.deadline),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARROUSEL "À LA UNE" (ÉDITORIAL COMPTE À REBOURS)
// ============================================================
class FeaturedCountdownCarousel extends StatefulWidget {
  final List<OpportunityItem> opportunities;
  final ValueChanged<OpportunityItem> onOpen;

  const FeaturedCountdownCarousel({super.key, required this.opportunities, required this.onOpen});

  @override
  State<FeaturedCountdownCarousel> createState() => _FeaturedCountdownCarouselState();
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
      _controller.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
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
      height: 260,
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
                  padding: EdgeInsets.only(right: i == widget.opportunities.length - 1 ? 0 : 12, left: i == 0 ? 20 : 0),
                  child: _FeaturedCard(opportunity: o, onTap: () => widget.onOpen(o)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.opportunities.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 4,
                width: active ? 18 : 6,
                decoration: BoxDecoration(color: active ? ThixPolicy.inkDeep : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
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
    final img = opportunity.imageAssetPath;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null && img.trim().isNotEmpty)
              img.startsWith('http') ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover)
            else
              Container(color: ThixPolicy.inkDeep),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [ThixPolicy.inkDeep.withOpacity(0.95), ThixPolicy.inkDeep.withOpacity(0.3), Colors.transparent],
                  stops: const [0, 0.6, 1],
                ),
              ),
            ),
            
            Positioned(
              top: 14, left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(6)),
                child: const Text('EN VEDETTE', style: TextStyle(fontSize: 9, color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
              ),
            ),
            
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(opportunity.category.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      // Compte à rebours intégré directement sur le carrousel
                      CountdownTimerWidget(targetDate: opportunity.deadline),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(opportunity.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.corporate_fare_rounded, size: 14, color: ThixPolicy.tint),
                      const SizedBox(width: 4),
                      Expanded(child: Text(opportunity.organizer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: ThixPolicy.tint, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
