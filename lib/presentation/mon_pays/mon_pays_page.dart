// lib/presentation/mon_pays/mon_pays_page.dart
// Page d'accueil du module Mon Pays — Espace Citoyen RDC

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Imports des providers
import 'providers/news_provider.dart';
import 'providers/provinces_provider.dart';
import 'providers/authorities_provider.dart';
import 'providers/citizens_provider.dart'; 

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

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
  // ─── Couleurs Charte RDC ────────────────────────────────────────
  static const Color rdcRed = Color(0xFFCE1126); // Rouge RDC
  static const Color rdcYellow = Color(0xFFF7D116); // Jaune RDC
  static const Color rdcBlue = ThixPolicy.primaryDeep; // Bleu RDC

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
    // Le WidgetsBinding.instance... a été supprimé !
  }


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(newsProvider).articles.isEmpty) {
        ref.read(newsProvider.notifier).fetchArticles();
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

  // ─── Styles utilitaires ultra-compacts ─────────────────────
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16), // Raccourci pour plus de compacité
      boxShadow: [
        BoxShadow(
          color: rdcBlue.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  Widget _sectionHeader(String title, {String? actionText, VoidCallback? onTap}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: rdcRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: rdcBlue,
            fontSize: 15, // Plus petit
          ),
        ),
        const Spacer(),
        if (actionText != null && onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Text(
                    actionText,
                    style: const TextStyle(
                      color: ThixPolicy.gold,
                      fontSize: 11, // Plus petit
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: ThixPolicy.gold,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── Build principal ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: CustomScrollView(
        slivers: [
          _buildTopBar(isAdmin),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                
                // 1. CARROUSEL HERO
                _buildPatrioticCarousel(isAdmin),
                const SizedBox(height: 12),
                
                // 2. AUTORITÉS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildAutoritesFullWidth(),
                ),
                const SizedBox(height: 12),

                // 3. À LA UNE (Actualités)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildALaUneFull(),
                ),
                const SizedBox(height: 12),

                // 4. AGENCES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildAgencesFull(),
                ),
                const SizedBox(height: 12),
                
                // 5. PROVINCES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildProvincesSection(),
                ),
                const SizedBox(height: 12),

                // 6. CITOYENS EXEMPLAIRES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildCitoyensExemplairesFull(),
                ),
                const SizedBox(height: 12),

                // 7. ACCÈS RAPIDES
                _buildQuickAccess(),
                const SizedBox(height: 12),
                
                // 8. ALERTES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildAlertRow(),
                ),
                const SizedBox(height: 12),
                
                // 9. FIGURES HISTORIQUES 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildFiguresHistoriquesBig(),
                ),
                const SizedBox(height: 24), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Barre supérieure ────────────────────────────────────────────
  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 56, // Plus compact
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.menu, color: rdcBlue, size: 24),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: rdcBlue,
            ),
            child: const Center(
              child: Text(
                'CD',
                style: TextStyle(
                  color: rdcYellow,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: rdcBlue,
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
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: rdcRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _goToAdminSpace,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: rdcRed, width: 1.5),
                    ),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: rdcBlue,
                      child: Icon(Icons.admin_panel_settings, color: rdcYellow, size: 16),
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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ThixPolicy.surfaceSoft,
        ),
        child: Icon(icon, size: 18, color: rdcBlue),
      ),
    );
  }

  // ─── Carrousel patriotique ──────────────────────────────────────
  Widget _buildPatrioticCarousel(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: rdcBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text(
                'Espace Citoyen',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Informer • Comprendre • Participer',
                  style: TextStyle(
                    color: rdcYellow,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAdmin)
                InkWell(
                  onTap: () => _showComingSoon(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140, // Plus compact
          child: PageView.builder(
            controller: _patrioticCtrl,
            itemCount: patrioticPosters.length,
            onPageChanged: (index) => setState(() => _currentPatriotic = index),
            itemBuilder: (context, index) {
              final p = patrioticPosters[index];
              return Container(
                margin: const EdgeInsets.only(right: 8, left: 4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(p['img']!),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            rdcBlue.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
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
                              color: rdcYellow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p['title']!,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: rdcBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p['subtitle']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              height: 1.2,
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
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: index == _currentPatriotic ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _currentPatriotic ? rdcYellow : rdcBlue.withOpacity(0.2),
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
      padding: const EdgeInsets.all(12), // Moins d'espace perdu
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Les Autorités', actionText: 'Voir tout', onTap: () => context.push('/mon-pays/authorities')),
          const SizedBox(height: 12),
          authAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2, color: rdcBlue),
              ),
            ),
            error: (_, __) => const Text('Erreur chargement autorités', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11)),
            data: (authorities) {
              if (authorities.isEmpty) {
                return const Text('Aucune autorité enregistrée', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11));
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [rdcBlue, rdcRed, rdcYellow],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 32, // Plus petit
                              backgroundImage: NetworkImage(
                                president.imageUrl ?? 'https://i.pravatar.cc/200?u=president',
                              ),
                              onBackgroundImageError: (_, __) {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: rdcBlue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'PRÉSIDENT DE LA RÉPUBLIQUE',
                                    style: TextStyle(
                                      color: rdcYellow,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  president.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: ThixPolicy.textMain,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  president.title ?? 'Président de la République',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: ThixPolicy.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (others.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.85, // Mieux équilibré
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: others.length,
                      itemBuilder: (context, i) {
                        final a = others[i];
                        return InkWell(
                          onTap: () => context.push('/mon-pays/authorities/${a.id}'),
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: rdcYellow, width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 26, // Plus petit
                                  backgroundImage: NetworkImage(
                                    a.imageUrl ?? 'https://i.pravatar.cc/100?u=$i',
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  color: ThixPolicy.textMain,
                                ),
                              ),
                              Text(
                                a.title ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 8,
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

  // ─── À la Une ──────────────────────────────────────────────────
  Widget _buildALaUneFull() {
    final newsState = ref.watch(newsProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('À la Une', actionText: 'Voir toutes', onTap: () => context.push('/mon-pays/news')),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: newsState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue, strokeWidth: 2)),
              error: (error, _) => Center(child: Text('Erreur : $error', style: TextStyle(color: Colors.red.shade300, fontSize: 11))),
              data: (articles) {
                if (articles.isEmpty) {
                  return const Center(child: Text('Aucune actualité pour le moment.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11)));
                }

                final topNews = articles.take(5).toList();

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: topNews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final article = topNews[i];
                    String dateStr = '';
                    if (article.publishedAt != null) {
                      dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(article.publishedAt!);
                    }

                    return InkWell(
                      onTap: () => _showComingSoon(), 
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: article.coverImageUrl!,
                                      height: 75,
                                      width: 130,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft, height: 75, width: 130),
                                      errorWidget: (_, __, ___) => Container(color: ThixPolicy.surfaceSoft, height: 75, width: 130, child: const Icon(Icons.broken_image, color: Colors.grey, size: 20)),
                                    )
                                  : Container(height: 75, width: 130, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.newspaper, color: Colors.grey, size: 20)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr.isNotEmpty ? dateStr : 'Récemment',
                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: rdcRed),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    article.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ThixPolicy.textMain, height: 1.2),
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
      {'icon': Icons.business, 'label': 'Entreprises Pub.'},
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _sectionHeader('Institutions', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.3, // Plus aplati (moins de hauteur)
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item['icon'] as IconData, color: rdcBlue, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        item['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
                      ),
                    ],
                  ),
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
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              _sectionHeader('Provinces', actionText: 'Voir toutes', onTap: () => context.push('/mon-pays/provinces')),
              const SizedBox(height: 12),
              SizedBox(
                height: 75, // Plus compact
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (c, i) {
                    final p = list[i];
                    return InkWell(
                      onTap: () => context.push('/mon-pays/provinces/${p.id}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 110,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: rdcBlue,
                                shape: BoxShape.circle,
                                image: p.coatOfArmsUrl != null && p.coatOfArmsUrl!.trim().isNotEmpty
                                    ? DecorationImage(image: NetworkImage(p.coatOfArmsUrl!), fit: BoxFit.contain)
                                    : null,
                              ),
                              child: (p.coatOfArmsUrl == null || p.coatOfArmsUrl!.trim().isEmpty)
                                  ? Center(
                                      child: Text(
                                        p.code.length >= 2 ? p.code.substring(0, 2).toUpperCase() : p.code.toUpperCase(),
                                        style: const TextStyle(color: rdcYellow, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : null,
                            ),
                            const Spacer(),
                            Text(
                              p.name,
                              maxLines: 1,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: ThixPolicy.textMain, fontSize: 10),
                            ),
                            Text(
                              p.capital,
                              style: const TextStyle(fontSize: 8, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
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

  // ─── Citoyens Exemplaires ──────────────────────────────────
  Widget _buildCitoyensExemplairesFull() {
    final citizensAsync = ref.watch(citizensProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Citoyens Exemplaires', actionText: 'Voir tous', onTap: () => _showComingSoon()),
          const SizedBox(height: 4),
          const Text(
            'Ils bâtissent la RDC au quotidien par leur excellence.',
            style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 95, // Erreur / Loading plus compacts
            child: citizensAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue, strokeWidth: 2)),
              error: (e, _) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.red, fontSize: 11))),
              data: (citizens) {
                if (citizens.isEmpty) {
                  return const Center(
                    child: Text('Aucun citoyen mis en avant pour le moment.', style: TextStyle(color: ThixPolicy.textSecondary, fontStyle: FontStyle.italic, fontSize: 11)),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: citizens.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final citizen = citizens[i];

                    return SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rdcYellow, width: 1.5)),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: ThixPolicy.surfaceSoft,
                              backgroundImage: citizen.photoUrl != null && citizen.photoUrl!.isNotEmpty 
                                  ? CachedNetworkImageProvider(citizen.photoUrl!) : null,
                              child: (citizen.photoUrl == null || citizen.photoUrl!.isEmpty) 
                                  ? const Icon(Icons.person, color: rdcBlue, size: 20) : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            citizen.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: ThixPolicy.textMain, fontSize: 10),
                          ),
                          Text(
                            citizen.domain,
                            style: const TextStyle(fontSize: 8, color: rdcRed, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  // ─── Accès rapides ─────────────────────────────────────────────
  Widget _buildQuickAccess() {
    final items = [
      {'icon': Icons.videocam_rounded, 'label': 'Vidéos', 'color': rdcBlue},
      {'icon': Icons.folder_rounded, 'label': 'Documents', 'color': rdcRed},
      {'icon': Icons.balance_rounded, 'label': 'Lois', 'route': '/mon-pays/laws', 'color': rdcYellow},
      {'icon': Icons.campaign_rounded, 'label': 'Participer', 'color': rdcBlue},
    ];
    return SizedBox(
      height: 75, // Plus bas
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final item = items[i];
          final route = item['route'] as String?;
          final color = item['color'] as Color;
          return InkWell(
            onTap: () {
              if (route != null) {
                context.push(route);
              } else {
                _showComingSoon();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: rdcBlue.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(item['icon'] as IconData, color: color == rdcYellow ? const Color(0xFFD4A017) : color, size: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
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
          Expanded(child: _alertCard(rdcRed, 'Personne\nRecherchée', Icons.warning_amber_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _alertCard(rdcBlue, 'Recherche\nCitoyenne', Icons.search_rounded)),
        ],
      );

  Widget _alertCard(Color color, String title, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: color, height: 1.2),
              ),
            ),
          ],
        ),
      );

  // ─── Figures Historiques ───────────────────
  Widget _buildFiguresHistoriquesBig() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Figures Historiques', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: 4),
          const Text(
            'Découvrez ceux qui ont marqué notre histoire.',
            style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.history_edu, size: 32, color: ThixPolicy.surfaceStrong),
                  const SizedBox(height: 8),
                  const Text(
                    'Module en cours de développement',
                    style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700, fontSize: 11),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Utilitaire ─────────────────────────────────────────────────
  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Module en cours de développement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: rdcBlue,
        duration: Duration(seconds: 1),
      ),
    );
  }
}
