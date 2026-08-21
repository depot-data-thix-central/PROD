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

  // ─── Styles utilitaires pour le design épuré ─────────────────────
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ThixPolicy.rXl),
      boxShadow: [
        BoxShadow(
          color: rdcBlue.withOpacity(0.04),
          blurRadius: 20,
          offset: const Offset(0, 8),
        )
      ],
    );
  }

  Widget _sectionHeader(String title, {String? actionText, VoidCallback? onTap}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: rdcRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: rdcBlue,
            fontSize: 17,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
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
                const SizedBox(height: ThixPolicy.s12),
                
                // 1. CARROUSEL HERO
                _buildPatrioticCarousel(isAdmin),
                const SizedBox(height: ThixPolicy.s24),
                
                // 2. AUTORITÉS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildAutoritesFullWidth(),
                ),
                const SizedBox(height: ThixPolicy.s24),

                // 3. À LA UNE (Actualités connectées à Supabase)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildALaUneFull(),
                ),
                const SizedBox(height: ThixPolicy.s24),

                // 4. AGENCES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildAgencesFull(),
                ),
                const SizedBox(height: ThixPolicy.s24),
                
                // 5. PROVINCES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildProvincesSection(),
                ),
                const SizedBox(height: ThixPolicy.s24),

                // 6. CITOYENS EXEMPLAIRES (Connecté)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildCitoyensExemplairesFull(),
                ),
                const SizedBox(height: ThixPolicy.s24),

                // 7. ACCÈS RAPIDES
                _buildQuickAccess(),
                const SizedBox(height: ThixPolicy.s24),
                
                // 8. ALERTES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildAlertRow(),
                ),
                const SizedBox(height: ThixPolicy.s24),
                
                // 9. FIGURES HISTORIQUES 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: _buildFiguresHistoriquesBig(),
                ),
                const SizedBox(height: 40), // Espacement final propre
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
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.menu, color: rdcBlue, size: 28),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: rdcBlue,
            ),
            child: const Center(
              child: Text(
                'CD',
                style: TextStyle(
                  color: rdcYellow,
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
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: rdcRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      fontSize: 9,
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
                      backgroundColor: rdcBlue,
                      child: Icon(Icons.admin_panel_settings, color: rdcYellow, size: 18),
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
          color: ThixPolicy.surfaceSoft,
        ),
        child: Icon(icon, size: 20, color: rdcBlue),
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
            color: rdcBlue,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
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
                    color: rdcYellow,
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
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
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
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        image: DecorationImage(
                          image: NetworkImage(p['img']!),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            rdcBlue.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: rdcYellow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p['title']!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: rdcBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p['subtitle']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                onPressed: () => _showComingSoon(),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: rdcRed, size: 18),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            patrioticPosters.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: index == _currentPatriotic ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
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
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Les Autorités', actionText: 'Voir tout', onTap: () => context.push('/mon-pays/authorities')),
          const SizedBox(height: 20),
          authAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2, color: rdcBlue),
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
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surfaceSoft,
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [rdcBlue, rdcRed, rdcYellow],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundImage: NetworkImage(
                                president.imageUrl ?? 'https://i.pravatar.cc/200?u=president',
                              ),
                              onBackgroundImageError: (_, __) {},
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: rdcBlue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'PRÉSIDENT DE LA RÉPUBLIQUE',
                                    style: TextStyle(
                                      color: rdcYellow,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  if (others.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.80,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
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
                                  border: Border.all(color: rdcYellow, width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 36,
                                  backgroundImage: NetworkImage(
                                    a.imageUrl ?? 'https://i.pravatar.cc/100?u=$i',
                                  ),
                                  onBackgroundImageError: (_, __) {},
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
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

  // ─── À la Une (Actualités branchées sur Supabase via newsProvider) ──────
  Widget _buildALaUneFull() {
    final newsAsync = ref.watch(newsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('À la Une', actionText: 'Voir toutes', onTap: () => context.push('/mon-pays/news')),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: newsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: rdcBlue),
              ),
              error: (err, _) => Center(
                child: Text('Erreur de chargement', style: TextStyle(color: Colors.red.shade300)),
              ),
              data: (newsList) {
                if (newsList.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune actualité pour le moment.',
                      style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                    ),
                  );
                }

                final topNews = newsList.take(5).toList();

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: topNews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    final article = topNews[i];
                    String dateStr = '';
                    if (article.publishedAt != null) {
                      dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(article.publishedAt!);
                    }

                    return InkWell(
                      onTap: () => _showComingSoon(), 
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      child: Container(
                        width: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(ThixPolicy.rMd),
                              ),
                              child: article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: article.coverImageUrl!,
                                      height: 95,
                                      width: 150,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft, height: 95, width: 150),
                                      errorWidget: (_, __, ___) => Container(color: ThixPolicy.surfaceSoft, height: 95, width: 150, child: const Icon(Icons.broken_image, color: Colors.grey)),
                                    )
                                  : Container(
                                      height: 95,
                                      width: 150,
                                      color: ThixPolicy.surfaceSoft,
                                      child: const Icon(Icons.newspaper, color: Colors.grey),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr.isNotEmpty ? dateStr : 'Récemment',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: rdcRed,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    article.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: ThixPolicy.textMain,
                                      height: 1.2,
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
      {'icon': Icons.business, 'label': 'Entreprises Pub.'},
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _sectionHeader('Institutions', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: rdcBlue,
                        size: 26,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ThixPolicy.textMain,
                        ),
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
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              _sectionHeader('Provinces', actionText: 'Voir toutes', onTap: () => context.push('/mon-pays/provinces')),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (c, i) {
                    final p = list[i];
                    return InkWell(
                      onTap: () => context.push('/mon-pays/provinces/${p.id}'),
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: rdcBlue,
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
                                        style: const TextStyle(color: rdcYellow, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : null,
                            ),
                            const Spacer(),
                            Text(
                              p.name,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: ThixPolicy.textMain,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              p.capital,
                              style: const TextStyle(
                                fontSize: 10,
                                color: ThixPolicy.textSecondary,
                                fontWeight: FontWeight.w500,
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

  // ─── Citoyens Exemplaires ──────────────────────────────────
  Widget _buildCitoyensExemplairesFull() {
    final citizensAsync = ref.watch(citizensProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Citoyens Exemplaires', actionText: 'Voir tous', onTap: () => _showComingSoon()),
          const SizedBox(height: 8),
          const Text(
            'Ils bâtissent la RDC au quotidien par leur excellence.',
            style: TextStyle(
              color: ThixPolicy.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 120,
            child: citizensAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
              error: (e, _) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.red))),
              data: (citizens) {
                if (citizens.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun citoyen mis en avant pour le moment.',
                      style: TextStyle(color: ThixPolicy.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: citizens.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final citizen = citizens[i];

                    return SizedBox(
                      width: 85,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: rdcYellow, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 34,
                              backgroundColor: ThixPolicy.surfaceSoft,
                              backgroundImage: citizen.photoUrl != null && citizen.photoUrl!.isNotEmpty 
                                  ? CachedNetworkImageProvider(citizen.photoUrl!) 
                                  : null,
                              child: (citizen.photoUrl == null || citizen.photoUrl!.isEmpty) 
                                  ? const Icon(Icons.person, color: rdcBlue) 
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            citizen.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ThixPolicy.textMain,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            citizen.domain,
                            style: const TextStyle(
                              fontSize: 10,
                              color: rdcRed,
                              fontWeight: FontWeight.w600,
                            ),
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
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            child: Container(
              width: 85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                boxShadow: [
                  BoxShadow(
                    color: rdcBlue.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item['icon'] as IconData, color: color == rdcYellow ? const Color(0xFFD4A017) : color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
          Expanded(child: _alertCard(rdcRed, 'Personne Recherchée', Icons.warning_amber_rounded)),
          const SizedBox(width: 16),
          Expanded(child: _alertCard(rdcBlue, 'Recherche Citoyenne', Icons.search_rounded)),
        ],
      );

  Widget _alertCard(Color color, String title, IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: color,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );

  // ─── Figures Historiques ───────────────────
  Widget _buildFiguresHistoriquesBig() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Figures Historiques', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: 8),
          const Text(
            'Découvrez ceux qui ont marqué notre histoire.',
            style: TextStyle(
              color: ThixPolicy.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.history_edu, size: 48, color: ThixPolicy.surfaceStrong),
                  const SizedBox(height: 12),
                  const Text(
                    'Module en cours de développement',
                    style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
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
        content: Text('Module en cours de développement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: rdcBlue,
        duration: Duration(seconds: 1),
      ),
    );
  }
}
