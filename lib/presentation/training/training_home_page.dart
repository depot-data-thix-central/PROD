import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/training_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/training_service.dart';
import 'package:thix_id/theme.dart';

class TrainingHomePage extends StatefulWidget {
  const TrainingHomePage({super.key});

  @override
  State<TrainingHomePage> createState() => _TrainingHomePageState();
}

class _TrainingHomePageState extends State<TrainingHomePage> {
  final _svc = TrainingService();
  final _search = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<TrainingItem> _all = const [];

  // Filtres d'état fonctionnels
  bool? _freeOnly;
  String? _level;
  String? _delivery;
  bool? _certIncluded;
  String? _language;

  // Palette de couleurs exacte de la maquette THIX FORMATION
  static const _brandPurple = Color(0xFF6366F1);
  static const _bgLight = Color(0xFFF8FAFC);
  static const _textDark = Color(0xFF1E293B);
  static const _textGrey = Color(0xFF64748B);
  static const _emerald = Color(0xFF10B981); // Ajouté pour remplacer Colors.emerald

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
    _load();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listPublishedTrainings();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      debugPrint('TrainingHomePage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TrainingItem> _applyFilters(List<TrainingItem> list) {
    final q = _search.text.trim().toLowerCase();
    return list.where((t) {
      if (q.isNotEmpty) {
        final hay = [t.title, t.tagline ?? '', t.category, t.instructorName ?? ''].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_freeOnly == true && !t.isFree) return false;
      if (_level != null && t.level.toLowerCase() != _level!.toLowerCase()) return false;
      if (_delivery != null && t.deliveryMode.toLowerCase() != _delivery!.toLowerCase()) return false;
      if (_certIncluded == true && !t.certificationIncluded) return false;
      if (_language != null && t.language.toLowerCase() != _language!.toLowerCase()) return false;
      return true;
    }).toList(growable: false);
  }

  void _openTraining(BuildContext context, TrainingItem t) =>
      context.push('${AppRoutes.trainingDetailsBasePath}/${Uri.encodeComponent(t.id)}');

  List<TrainingItem> _aiRecommend(List<TrainingItem> list) {
    final scored = list.map((t) {
      var s = 0.0;
      if (t.isFeatured) s += 3;
      if (t.certificationIncluded) s += 2;
      if (t.category.toLowerCase().contains('cyber')) s += 1.5;
      s += t.rating;
      return (t: t, s: s);
    }).toList(growable: false)
      ..sort((a, b) => b.s.compareTo(a.s));
    return scored.take(10).map((e) => e.t).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isAuthed = auth.currentUser != null;

    final filtered = _applyFilters(_all);
    final featured = filtered.where((e) => e.isFeatured).toList(growable: false);
    final trending = filtered.where((e) => e.rating >= 4.7).toList(growable: false);
    final certifications = filtered.where((e) => e.certificationIncluded).toList(growable: false);

    return Scaffold(
      backgroundColor: _bgLight,
      // --- HEADER DE LA MAQUETTE ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: _textDark),
          onPressed: () {}, // Menu latéral ou tiroir
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school_rounded, color: _brandPurple, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'THIX FORMATION',
                  style: TextStyle(color: _textDark, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5),
                ),
                SizedBox(height: 2),
                Text(
                  'Apprenez aujourd\'hui, réussissez demain.',
                  style: TextStyle(color: _textGrey, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: _textDark),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 14.0, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/images/profile_placeholder.jpg'), // Connecté au profil utilisateur
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator(color: _brandPurple))
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: _textGrey)))
                  : RefreshIndicator(
                      color: _brandPurple,
                      onRefresh: _load,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 92),
                        children: [
                          // 1. CAROUSEL/HERO BANNER DE LA MAQUETTE
                          _buildHeroBanner(featured.isEmpty ? null : () => _openTraining(context, featured.first)),
                          const SizedBox(height: 20),

                          // 2. BARRE DE RECHERCHE CONNECTÉE
                          _buildSearchBar(),
                          const SizedBox(height: 20),

                          // 3. GRIDE DE RACCOURCIS / CATÉGORIES DE LA MAQUETTE
                          _buildQuickActionsGrid(),
                          const SizedBox(height: 24),

                          // 4. SECTIONS DES FILTRES INTERACTIFS (CHIPS)
                          _buildSectionHeader(title: 'Catégories populaires', onSeeAll: () {}),
                          const SizedBox(height: 10),
                          _buildPopularCategoriesRow(),
                          const SizedBox(height: 24),

                          // 5. FORMATIONS RECOMMANDÉES (IA MATCHING CONNECTÉ)
                          _buildSectionHeader(title: 'Formations recommandées', onSeeAll: () {}),
                          const SizedBox(height: 12),
                          _buildHorizontalGridList(items: _aiRecommend(filtered)),
                          const SizedBox(height: 24),

                          // 6. BANNIÈRE PUBLICITAIRE / PROMO CERTIFICATS
                          _buildCertificatePromoCard(),
                          const SizedBox(height: 24),

                          // 7. DOUBLE CARTE : REPRENDRE & OBJECTIFS MENSUELS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildContinueLearningCard(isAuthed)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMonthlyObjectiveCard()),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 8. AUTRES RENDERERS FACULTATIFS (EX: POPULAIRES / CERTIFICATIONS)
                          _buildSectionHeader(title: 'Certifications de spécialité', onSeeAll: () {}),
                          const SizedBox(height: 12),
                          _buildHorizontalGridList(items: certifications),
                          
                          const SizedBox(height: 20),
                          _buildQuickFooterActions(),
                        ],
                      ),
                    ),
          
          // --- BARRE DE NAVIGATION INFÉRIEURE AVEC BOUTON SURÉLEVÉ ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCustomBottomNavBar(context),
          ),
        ],
      ),
    );
  }

  // --- BUILDERS DE COMPOSANTS GRAPHIQUES FIDÈLES ---

  Widget _buildHeroBanner(VoidCallback? onExplore) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xE0E0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            top: -10,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/images/hero_learning_illustration.png', // Remplace ou garde l'illustration de la femme sur son pc
                fit: BoxFit.contain,
                width: 180,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _brandPurple, borderRadius: BorderRadius.circular(4)),
                  child: const Text('★ À LA UNE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Développez vos\ncompétences, changez\nvotre avenir.',
                  style: TextStyle(color: _textDark, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Des milliers de cours, certificats\net formations pour booster votre carrière.',
                  style: TextStyle(color: _textGrey, fontSize: 10, height: 1.3),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: onExplore ?? () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: _brandPurple, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Explorer les formations ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 8),
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: _search,
        style: const TextStyle(color: _textDark, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Rechercher un cours, une compétence...',
          hintStyle: TextStyle(color: _textGrey, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: _brandPurple, size: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {'icon': Icons.grid_view_rounded, 'label': 'Toutes les\nformations', 'color': const Color(0xFFEEF2FF), 'iconColor': _brandPurple},
      {'icon': Icons.school_rounded, 'label': 'Certifications', 'color': const Color(0xFFEFF6FF), 'iconColor': Colors.blue},
      {'icon': Icons.local_fire_department_rounded, 'label': 'Populaires', 'color': const Color(0xFFFFF7ED), 'iconColor': Colors.orange},
      {'icon': Icons.bookmark_rounded, 'label': 'Mes favoris', 'color': const Color(0xFFFDF2F8), 'iconColor': Colors.pink},
      {'icon': Icons.access_time_filled_rounded, 'label': 'Reprendre', 'color': const Color(0xFFECFDF5), 'iconColor': _emerald},
      {'icon': Icons.more_horiz_rounded, 'label': 'Plus', 'color': const Color(0xFFF8FAFC), 'iconColor': _textGrey},
    ];

    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                if (actions[i]['label'] == 'Certifications') {
                  setState(() => _certIncluded = (_certIncluded == true) ? null : true);
                }
              },
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: actions[i]['color'] as Color, borderRadius: BorderRadius.circular(12)),
                    child: Icon(actions[i]['icon'] as IconData, color: actions[i]['iconColor'] as Color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    actions[i]['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _textDark, fontSize: 9.5, fontWeight: FontWeight.bold, height: 1.2),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularCategoriesRow() {
    final List<Map<String, dynamic>> cats = [
      {'name': 'Développement Web', 'icon': Icons.code_rounded, 'color': const Color(0xFFEFF6FF), 'text': Colors.blue},
      {'name': 'Marketing Digital', 'icon': Icons.campaign_rounded, 'color': const Color(0xFFECFDF5), 'text': _emerald},
      {'name': 'Design Graphique', 'icon': Icons.palette_rounded, 'color': const Color(0xFFF5F3FF), 'text': _brandPurple},
      {'name': 'Business & Entrepreneuriat', 'icon': Icons.business_center_rounded, 'color': const Color(0xFFFFF7ED), 'text': Colors.orange},
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cats.length,
        itemBuilder: (context, i) {
          final isSelected = _search.text == cats[i]['name'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _search.text = isSelected ? '' : cats[i]['name'] as String);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _brandPurple : cats[i]['color'] as Color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? _brandPurple : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(cats[i]['icon'] as IconData, size: 16, color: isSelected ? Colors.white : cats[i]['text'] as Color),
                    const SizedBox(width: 6),
                    Text(
                      cats[i]['name'] as String,
                      style: TextStyle(color: isSelected ? Colors.white : _textDark, fontSize: 11, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalGridList({required List<TrainingItem> items}) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text("Aucune formation trouvée", style: TextStyle(color: _textGrey, fontSize: 12))),
      );
    }

    return SizedBox(
      height: 228,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final priceDisplay = item.isFree ? 'Gratuit' : '${item.priceAmount ?? '25.000'} ${item.currency ?? 'FC'}';
          
          return Container(
            width: 165,
            margin: const EdgeInsets.only(right: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: InkWell(
              onTap: () => _openTraining(context, item),
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image / Cover Placeholder avec Tag "NOUVEAU"
                  Stack(
                    children: [
                      Container(
                        height: 94,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          image: DecorationImage(
                            image: NetworkImage('https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=200&auto=format&fit=crop'), // Remplaçable dynamiquement
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (item.isFeatured)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                            child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: Colors.white.withOpacity(0.85),
                          child: const Icon(Icons.favorite_border_rounded, size: 14, color: _textDark),
                        ),
                      )
                    ],
                  ),
                  // Détails textuels du cours
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textDark, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.25)),
                        const SizedBox(height: 4),
                        Text('${item.level} • 18h 30m', style: const TextStyle(color: _textGrey, fontSize: 9, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                            const SizedBox(width: 2),
                            Text(item.rating.toStringAsFixed(1), style: const TextStyle(color: _textDark, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 2),
                            Text('(${item.reviewsCount})', style: const TextStyle(color: _textGrey, fontSize: 9)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(priceDisplay, style: const TextStyle(color: _brandPurple, fontSize: 13, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCertificatePromoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.verified_rounded, color: _brandPurple, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Obtenez des certificats reconnus', style: TextStyle(color: _textDark, fontSize: 12.5, fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text('Valorisez vos compétences et démarquez-vous sur le marché.', style: TextStyle(color: _textGrey, fontSize: 10)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandPurple,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              children: const [
                Text('Découvrir ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 7),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildContinueLearningCard(bool isAuthed) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Continuez votre apprentissage', style: TextStyle(color: _textGrey, fontSize: 9.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.bolt, color: _emerald, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isAuthed ? 'Marketing Digital' : 'Non connecté', style: TextStyle(color: _textDark, fontSize: 11, fontWeight: FontWeight.w800)),
                    Text(isAuthed ? 'Les fondamentaux' : 'Identifiez-vous', style: TextStyle(color: _textGrey, fontSize: 9)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: LinearProgressIndicator(value: 0.65, backgroundColor: Color(0xFFF1F5F9), color: _emerald, minHeight: 4)),
              const SizedBox(width: 8),
              Text('65%', style: TextStyle(color: _emerald, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMonthlyObjectiveCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Objectif du mois', style: TextStyle(color: _textGrey, fontSize: 9.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Suivez 5 cours pour obtenir un certificat.', style: TextStyle(color: _textDark, fontSize: 9, height: 1.2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('3 / 5 cours', style: TextStyle(color: _brandPurple, fontSize: 11, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  SizedBox(width: 60, child: LinearProgressIndicator(value: 0.6, color: _brandPurple, backgroundColor: Color(0xFFF1F5F9))),
                ],
              ),
              const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 36),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickFooterActions() {
    final footers = [
      {'label': 'Cours gratuits', 'icon': Icons.card_giftcard_rounded, 'color': Colors.green},
      {'label': 'Webinaires', 'icon': Icons.videocam_rounded, 'color': Colors.red},
      {'label': 'Mentorat', 'icon': Icons.supervisor_account_rounded, 'color': Colors.orange},
      {'label': 'Événements', 'icon': Icons.event_rounded, 'color': Colors.blue},
      {'label': 'Aide & support', 'icon': Icons.help_outline_rounded, 'color': Colors.teal},
    ];
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: footers.length,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(
            children: [
              Icon(footers[index]['icon'] as IconData, color: footers[index]['color'] as Color, size: 18),
              const SizedBox(width: 8),
              Text(footers[index]['label'] as String, style: const TextStyle(color: _textDark, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required VoidCallback onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        GestureDetector(
          onTap: onSeeAll,
          child: Row(
            children: const [
              Text('Voir tout ', style: TextStyle(color: _brandPurple, fontSize: 11, fontWeight: FontWeight.bold)),
              Icon(Icons.arrow_forward_ios_rounded, color: _brandPurple, size: 8),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCustomBottomNavBar(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavBarItem(Icons.home_outlined, 'Accueil', false, () => context.go(AppRoutes.home)),
          _buildNavBarItem(Icons.import_contacts_rounded, 'Mes cours', false, () => context.push(AppRoutes.learningDashboard)),
          
          // BOUTON CENTRAL SURÉLEVÉ POUR "APPRENDRE"
          Transform.translate(
            offset: const Offset(0, -14),
            child: GestureDetector(
              onTap: () {}, // Déjà sur la home d'apprentissage
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: _brandPurple, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x4D6366F1), blurRadius: 8, offset: Offset(0, 4))]),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 4),
                  const Text('Apprendre', style: TextStyle(color: _brandPurple, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          
          _buildNavBarItem(Icons.workspace_premium_outlined, 'Certificats', false, () {}),
          _buildNavBarItem(Icons.person_outline_rounded, 'Profil', false, () => context.push(AppRoutes.login)),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? _brandPurple : _textGrey, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? _brandPurple : _textGrey, fontSize: 10, fontWeight: isActive ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }
}
