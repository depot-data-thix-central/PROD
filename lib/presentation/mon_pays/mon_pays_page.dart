// lib/presentation/mon_pays/mon_pays_page.dart
// Page d'accueil du module Mon Pays — Espace Citoyen RDC

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'providers/news_provider.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'providers/provinces_provider.dart';
import 'providers/authorities_provider.dart';

// ─── Provider rôle admin ──────────────────────────────────────────
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final role = (res?['role'] ?? '').toString().toLowerCase();
    return role == 'admin' || role == 'super_admin';
  } catch (_) {
    return false;
  }
});

class MonPaysPage extends ConsumerStatefulWidget {
  const MonPaysPage({super.key});

  @override
  ConsumerState<MonPaysPage> createState() => _MonPaysPageState();
}

class _MonPaysPageState extends ConsumerState<MonPaysPage> {
  // Couleur spécifique au drapeau, conservée localement
  static const Color rdcRed = Color(0xFFCE1126);

  // ─── Carrousel patriotique ──────────────────────────────────────
  final PageController _patrioticCtrl = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _currentPatriotic = 0;

  final List<Map<String, String>> patrioticPosters = [
    {'title': 'Unité Nationale', 'subtitle': 'Bendele ya Congo', 'img': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4'},
    {'title': 'Devoir Civique', 'subtitle': 'S\'engager pour la Patrie', 'img': 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac'},
    {'title': 'Mémoire Collective', 'subtitle': 'Honorer nos Héros', 'img': 'https://images.unsplash.com/photo-1497895121-66bdc4d7d3b2'},
    {'title': 'Travail et Progrès', 'subtitle': 'Bâtir la RDC', 'img': 'https://images.unsplash.com/photo-1516026672322-bc52d61a55e5'},
    {'title': 'Education pour Tous', 'subtitle': 'Avenir de la Nation', 'img': 'https://images.unsplash.com/photo-1503676260728-1c00da094a0b'},
    {'title': 'Paix et Sécurité', 'subtitle': 'Fondement du Développement', 'img': 'https://images.unsplash.com/photo-1447069387593-a5de0862481e'},
    {'title': 'Culture et Identité', 'subtitle': 'Notre Richesse', 'img': 'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3'},
    {'title': 'Jeunesse d\'Avenir', 'subtitle': 'Espoir de la République', 'img': 'https://images.unsplash.com/photo-1529390079861-591de354faf5'},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_patrioticCtrl.hasClients) {
        _currentPatriotic = (_currentPatriotic + 1) % patrioticPosters.length;
        _patrioticCtrl.animateToPage(
          _currentPatriotic,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _patrioticCtrl.dispose();
    super.dispose();
  }

  void _goToAdminSpace() {
    try {
      context.push('/mon-pays/admin');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'accéder à l\'Espace Admin')),
      );
    }
  }

  // ─── Build principal ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      body: CustomScrollView(
        slivers: [
          _buildTopBar(isAdmin),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: ThixPolicy.s12),
                
                // 1. CARROUSEL HERO
                _buildPatrioticCarousel(isAdmin),
                const SizedBox(height: ThixPolicy.s20),
                
                // 2. AUTORITÉS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildAutoritesFullWidth(),
                ),
                const SizedBox(height: ThixPolicy.s20),

                // 3. À LA UNE (Déplacé ici)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildALaUneFull(),
                ),
                const SizedBox(height: ThixPolicy.s20),

                // 4. AGENCES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildAgencesFull(),
                ),
                const SizedBox(height: ThixPolicy.s20),
                
                // 5. PROVINCES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildProvincesSection(),
                ),
                const SizedBox(height: ThixPolicy.s20),

                // 6. NOUVELLE SECTION: CITOYENS EXEMPLAIRES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildCitoyensExemplairesFull(),
                ),
                const SizedBox(height: ThixPolicy.s20),

                // 7. ACCÈS RAPIDES
                _buildQuickAccess(),
                const SizedBox(height: ThixPolicy.s16),
                
                // 8. ALERTES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildAlertRow(),
                ),
                const SizedBox(height: ThixPolicy.s20),
                
                // 9. FIGURES HISTORIQUES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildFiguresHistoriquesBig(),
                ),
                const SizedBox(height: 110), // Espace pour la bottom nav
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Barre supérieure ────────────────────────────────────────────
  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.menu, color: ThixPolicy.primaryDeep, size: 28),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: ThixPolicy.primaryDeep,
            ),
            child: const Center(
              child: Text(
                'CD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ThixPolicy.primaryDeep,
                height: 1.1,
              ),
            ),
          ),
          _circleIcon(Icons.search, () => _showComingSoon()),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _circleIcon(Icons.notifications_none_rounded, () {}),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: ThixPolicy.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Bouton Espace Admin ──
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _goToAdminSpace,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: rdcRed, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: ThixPolicy.primaryDeep,
                      child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ThixPolicy.border),
          color: Colors.white,
        ),
        child: Icon(icon, size: 20, color: ThixPolicy.primaryDeep),
      ),
    );
  }

  // ─── Carrousel patriotique ──────────────────────────────────────
  Widget _buildPatrioticCarousel(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ThixPolicy.primaryDeep,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Row(
            children: [
              const Text(
                'Espace Citoyen',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Informer • Comprendre • Participer',
                  style: TextStyle(
                    color: ThixPolicy.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAdmin)
                InkWell(
                  onTap: () => _showComingSoon(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _patrioticCtrl,
            itemCount: patrioticPosters.length,
            onPageChanged: (index) => setState(() => _currentPatriotic = index),
            itemBuilder: (context, index) {
              final p = patrioticPosters[index];
              return Container(
                margin: const EdgeInsets.only(right: 12, left: 4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image de fond
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        image: DecorationImage(
                          image: NetworkImage(p['img']!),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        ),
                        boxShadow: ThixPolicy.shadowSoft(),
                      ),
                    ),
                    // Gradient et textes
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            ThixPolicy.primaryDeep.withOpacity(0.95),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ThixPolicy.gold,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p['title']!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ThixPolicy.textMain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p['subtitle']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Boutons Admin (Modifier/Supprimer)
                    if (isAdmin)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                onPressed: () => _showComingSoon(),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                onPressed: () => _showComingSoon(),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            patrioticPosters.length,
            (index) => Container(
              width: index == _currentPatriotic ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _currentPatriotic
                    ? ThixPolicy.primary
                    : ThixPolicy.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Section Autorités ───────────────────────────────────────────
  Widget _buildAutoritesFullWidth() {
    final authAsync = ref.watch(topAuthoritiesProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '1. Les Autorités',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ThixPolicy.primaryDeep,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/mon-pays/authorities'),
                child: const Row(
                  children: [
                    Text(
                      'Voir tout',
                      style: TextStyle(
                        color: ThixPolicy.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: ThixPolicy.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.account_balance, size: 18, color: ThixPolicy.textSecondary),
              SizedBox(width: 6),
              Text(
                'Hautes Autorités',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ThixPolicy.textMain,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          authAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
              ),
            ),
            error: (_, __) => const Text('Erreur chargement autorités', style: TextStyle(color: ThixPolicy.textSecondary)),
            data: (authorities) {
              if (authorities.isEmpty) {
                return const Text('Aucune autorité enregistrée', style: TextStyle(color: ThixPolicy.textSecondary));
              }

              int getPriority(String? title) {
                if (title == null) return 99;
                final t = title.toLowerCase();
                if (t.contains('président de la république') ||
                    t.contains('president de la republique')) return 1;
                if (t.contains('premier ministre')) return 2;
                if (t.contains('sénat') || t.contains('senat')) return 3;
                if (t.contains('assemblée') || t.contains('assemblee')) return 4;
                return 99;
              }

              final sortedList = authorities..sort(
                    (a, b) => getPriority(a.title)
                        .compareTo(getPriority(b.title)),
                  );

              final president = sortedList.first;
              final others = sortedList.length > 1
                  ? sortedList.sublist(1).take(3).toList()
                  : [];

              return Column(
                children: [
                  InkWell(
                    onTap: () => context.push('/mon-pays/authorities/${president.id}'),
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surface,
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        border: Border.all(
                          color: ThixPolicy.gold.withOpacity(0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: ThixPolicy.gold,
                            ),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundImage: NetworkImage(
                                president.imageUrl ??
                                    'https://i.pravatar.cc/200?u=president',
                              ),
                              onBackgroundImageError: (_, __) {},
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.primaryDeep,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'PRÉSIDENT DE LA RÉPUBLIQUE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  president.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: ThixPolicy.textMain,
                                  ),
                                ),
                                Text(
                                  president.title ?? 'Président de la République',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ThixPolicy.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (others.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: others.length,
                      itemBuilder: (context, i) {
                        final a = others[i];
                        return InkWell(
                          onTap: () => context.push('/mon-pays/authorities/${a.id}'),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ThixPolicy.gold, width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 34,
                                  backgroundImage: NetworkImage(
                                    a.imageUrl ??
                                        'https://i.pravatar.cc/100?u=$i',
                                  ),
                                  onBackgroundImageError: (_, __) {},
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: ThixPolicy.textMain,
                                ),
                              ),
                              Text(
                                a.title ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: ThixPolicy.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  
    // ─── À la Une (Connecté à Supabase) ─────────────────────────────
  Widget _buildALaUneFull() {
    // 1. On écoute le provider des actualités
    final newsAsync = ref.watch(newsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'À la Une',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ThixPolicy.primaryDeep,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/mon-pays/news'), // Redirige vers la liste complète
                child: const Text(
                  'Voir toutes',
                  style: TextStyle(
                    color: ThixPolicy.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 2. Gestion des états : Chargement, Erreur, ou Données
          SizedBox(
            height: 165,
            child: newsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: ThixPolicy.primary),
              ),
              error: (err, _) => Center(
                child: Text('Erreur de chargement', style: TextStyle(color: Colors.red.shade300)),
              ),
              data: (newsList) {
                // Si la base de données est vide
                if (newsList.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune actualité pour le moment.',
                      style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                    ),
                  );
                }

                // On prend seulement les 5 plus récentes pour l'accueil
                final topNews = newsList.take(5).toList();

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: topNews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final article = topNews[i];
                    
                    // Formatage de la date (ex: 27 Mai 2026)
                    String dateStr = '';
                    if (article.publishedAt != null) {
                      dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(article.publishedAt!);
                    }

                    return InkWell(
                      onTap: () {
                        // Navigation future vers le détail de l'article
                        _showComingSoon(); 
                      },
                      child: Container(
                        width: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                          color: ThixPolicy.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Image de l'article
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(ThixPolicy.rSm),
                              ),
                              child: article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: article.coverImageUrl!,
                                      height: 90,
                                      width: 140,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey.shade200, height: 90, width: 140),
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200, height: 90, width: 140, child: const Icon(Icons.broken_image, color: Colors.grey)),
                                    )
                                  : Container(
                                      height: 90,
                                      width: 140,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.newspaper, color: Colors.grey),
                                    ),
                            ),
                            // Textes (Date + Titre)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr.isNotEmpty ? dateStr : 'Récemment',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: ThixPolicy.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    article.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: ThixPolicy.textMain,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Agences & Institutions ─────────────────────────────────────
  Widget _buildAgencesFull() {
    final items = [
      {'icon': Icons.account_balance, 'label': 'Présidence'},
      {'icon': Icons.flag, 'label': 'Gouvernement'},
      {'icon': Icons.gavel, 'label': 'Parlement'},
      {'icon': Icons.work, 'label': 'Ministères'},
      {'icon': Icons.map, 'label': 'Provinces', 'route': '/mon-pays/provinces'},
      {'icon': Icons.business, 'label': 'Entreprises Publiques'},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Agences et Institutions',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ThixPolicy.primaryDeep,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showComingSoon(),
                child: const Text(
                  'Explorer',
                  style: TextStyle(
                    color: ThixPolicy.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final route = item['route'] as String?;
              return InkWell(
                onTap: () {
                  if (route != null) {
                    context.push(route);
                  } else {
                    _showComingSoon();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: ThixPolicy.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: ThixPolicy.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Provinces ──────────────────────────────────────────────────
  Widget _buildProvincesSection() {
    final prov = ref.watch(provincesProvider(null));
    return prov.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rXl),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Provinces',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ThixPolicy.primaryDeep,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => context.push('/mon-pays/provinces'),
                    child: const Text(
                      'Voir toutes',
                      style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (c, i) {
                    final p = list[i];
                    return InkWell(
                      onTap: () => context.push('/mon-pays/provinces/${p.id}'),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ThixPolicy.surface,
                          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                          border: Border.all(color: ThixPolicy.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🌟 Affichage du Blason de la Province ou Initiales
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: ThixPolicy.primary,
                                shape: BoxShape.circle,
                                image: p.coatOfArmsUrl != null && p.coatOfArmsUrl!.trim().isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(p.coatOfArmsUrl!),
                                        fit: BoxFit.contain,
                                      )
                                    : null,
                              ),
                              child: (p.coatOfArmsUrl == null || p.coatOfArmsUrl!.trim().isEmpty)
                                  ? Center(
                                      child: Text(
                                        p.code.length >= 2 ? p.code.substring(0, 2).toUpperCase() : p.code.toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : null,
                            ),
                            const Spacer(),
                            Text(
                              p.name,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ThixPolicy.textMain,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              p.capital,
                              style: const TextStyle(
                                fontSize: 9,
                                color: ThixPolicy.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Citoyens Exemplaires ─────────────────────────────────────────
  Widget _buildCitoyensExemplairesFull() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Citoyens Exemplaires',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ThixPolicy.primaryDeep,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showComingSoon(),
                child: const Text(
                  'Voir tous',
                  style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ils bâtissent la RDC au quotidien par leur excellence.',
            style: TextStyle(
              color: ThixPolicy.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                return SizedBox(
                  width: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ThixPolicy.gold, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=${40 + i}'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Patriote',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ThixPolicy.textMain,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        'Excellence',
                        style: TextStyle(
                          fontSize: 10,
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Accès rapides ─────────────────────────────────────────────
  Widget _buildQuickAccess() {
    final items = [
      {'icon': Icons.videocam_rounded, 'label': 'Vidéos Officielles'},
      {'icon': Icons.folder_rounded, 'label': 'Documentaires'},
      {'icon': Icons.emoji_events_rounded, 'label': 'Citoyens'},
      {'icon': Icons.balance_rounded, 'label': 'Valeurs et Lois', 'route': '/mon-pays/laws'},
      {'icon': Icons.campaign_rounded, 'label': 'Participer'},
    ];
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final item = items[i];
          final route = item['route'] as String?;
          return InkWell(
            onTap: () {
              if (route != null) {
                context.push(route);
              } else {
                _showComingSoon();
              }
            },
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item['icon'] as IconData, color: ThixPolicy.primaryDeep),
                  const SizedBox(height: 6),
                  Text(
                    item['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Alertes ────────────────────────────────────────────────────
  Widget _buildAlertRow() => Row(
        children: [
          Expanded(child: _alertCard(ThixPolicy.danger, 'Personne Recherchée', Icons.warning_amber_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _alertCard(ThixPolicy.primary, 'Recherche Personnalisée', Icons.search_rounded)),
        ],
      );

  Widget _alertCard(Color color, String title, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );

  // ─── Figures Historiques ──────────────────────────────────────
  Widget _buildFiguresHistoriquesBig() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Figures Historiques',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ThixPolicy.primaryDeep,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showComingSoon(),
                child: const Text(
                  'Explorer',
                  style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Découvrez ceux qui ont marqué notre histoire.',
            style: TextStyle(
              color: ThixPolicy.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                return Container(
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    color: ThixPolicy.surface,
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(ThixPolicy.rMd),
                        ),
                        child: Image.network(
                          'https://i.pravatar.cc/200?img=${30 + i}',
                          height: 110,
                          width: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 110,
                            width: 140,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Patrice Lumumba',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ThixPolicy.textMain,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        '1960 - Héros National',
                        style: TextStyle(
                          fontSize: 10,
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Barre de navigation inférieure ────────────────────────────────
  Widget _buildBottomNav() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: ThixPolicy.shadowCard(),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(Icons.home_rounded, 'Accueil', '/'),
            _nav(Icons.flag_rounded, 'Mon Pays', '/mon-pays'),
            
            // Blason RDC au centre
            InkWell(
              onTap: () => _showComingSoon(),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: ThixPolicy.shadowSoft(),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Image.asset(
                  'assets/images/1000103460.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, color: ThixPolicy.primaryDeep, size: 28),
                ),
              ),
            ),
            
            _nav(Icons.grid_view_rounded, 'Services', null),
            _nav(Icons.person_rounded, 'Mon Compte', null),
          ],
        ),
      );

  Widget _nav(IconData icon, String label, String? route) => InkWell(
        onTap: () {
          if (route != null) {
            context.go(route);
          } else {
            _showComingSoon();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: label == 'Mon Pays' ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary,
              size: 22,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: label == 'Mon Pays' ? FontWeight.w700 : FontWeight.w500,
                color: label == 'Mon Pays' ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary,
              ),
            ),
          ],
        ),
      );

  // ─── Utilitaire ─────────────────────────────────────────────────
  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Module en cours de développement', style: TextStyle(color: Colors.white)),
        backgroundColor: ThixPolicy.warning,
        duration: Duration(seconds: 1),
      ),
    );
  }
}
