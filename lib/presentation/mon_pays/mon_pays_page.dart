// lib/presentation/mon_pays/mon_pays_page.dart
// Page d'accueil du module Mon Pays — Espace Citoyen RDC (Design Glassmorphism & ThixPolicy)

import 'dart:async';
import 'dart:ui'; // Nécessaire pour le BackdropFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Import du Design System unique
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ✅ Imports des providers
import 'providers/news_provider.dart';
import 'providers/provinces_provider.dart';
import 'providers/authorities_provider.dart';
import 'providers/citizens_provider.dart'; 
import 'pages/news/news_detail_page.dart';

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
  // ─── Couleurs unifiées via ThixPolicy ────────────────────────────
  static const Color rdcRed = Color(0xFFCE1126); // Spécifique au drapeau RDC
  static const Color rdcYellow = ThixPolicy.gold; 
  static const Color rdcBlue = ThixPolicy.primary; 
  static const Color bgNavy = ThixPolicy.inkDeep; 
  static const Color bgNavyLight = ThixPolicy.primaryDeep; 
  static const Color glassColor = Color(0x1AFFFFFF); // Blanc à 10%
  static const Color glassBorder = Color(0x33FFFFFF); // Blanc à 20%

  // ─── Carrousel patriotique ──────────────────────────────────────
  final PageController _patrioticCtrl = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _currentPatriotic = 0;

  final List<Map<String, String>> patrioticPosters = [
    {'title': 'Unité Nationale', 'subtitle': 'Bendele ya Congo', 'img': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4'},
    {'title': 'Devoir Civique', 'subtitle': 'S\'engager pour la Patrie', 'img': 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac'},
    {'title': 'Mémoire Collective', 'subtitle': 'Honorer nos Héros', 'img': 'https://images.unsplash.com/photo-1497895121-66bdc4d7d3b2'},
    {'title': 'Travail et Progrès', 'subtitle': 'Bâtir la RDC', 'img': 'https://images.unsplash.com/photo-1516026672322-bc52d61a55e5'},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_patrioticCtrl.hasClients) {
        _currentPatriotic = (_currentPatriotic + 1) % patrioticPosters.length;
        _patrioticCtrl.animateToPage(
          _currentPatriotic,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
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
    try { context.push('/mon-pays/admin'); } catch (_) {}
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Module en cours de développement', style: ThixPolicy.bodyMediumStyle.copyWith(color: bgNavy, fontWeight: FontWeight.bold)),
        backgroundColor: rdcYellow,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ─── Utilitaire Glassmorphism ─────────────────────────────────────
  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding, double? width, double? height, Color? customColor, Color? customBorder}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(ThixPolicy.s16),
          decoration: BoxDecoration(
            color: customColor ?? glassColor,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: customBorder ?? glassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? actionText, VoidCallback? onTap}) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: rdcYellow, borderRadius: BorderRadius.circular(ThixPolicy.s2))),
        const SizedBox(width: ThixPolicy.s8),
        Text(title, style: ThixPolicy.titleStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
        const Spacer(),
        if (actionText != null && onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ThixPolicy.rFull),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s8, vertical: ThixPolicy.s4),
              child: Row(
                children: [
                  Text(actionText, style: ThixPolicy.captionStyle.copyWith(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.white70),
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
      backgroundColor: bgNavy,
      body: Stack(
        children: [
          // Background Effets lumineux abstraits (Orbs)
          Positioned(top: -50, left: -50, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: rdcBlue.withOpacity(0.5)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()))),
          Positioned(top: 300, right: -100, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: rdcRed.withOpacity(0.15)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()))),
          Positioned(bottom: 100, left: 50, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: rdcYellow.withOpacity(0.1)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()))),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildTopBar(isAdmin),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: ThixPolicy.s40),
                  child: Column(
                    children: [
                      const SizedBox(height: ThixPolicy.s8),
                      _buildPatrioticCarousel(isAdmin),
                      const SizedBox(height: ThixPolicy.s24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _buildAutoritesFullWidth()),
                      const SizedBox(height: ThixPolicy.s20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _buildALaUneFull()),
                      const SizedBox(height: ThixPolicy.s20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _buildAgencesFull()),
                      const SizedBox(height: ThixPolicy.s20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _buildProvincesSection()),
                      const SizedBox(height: ThixPolicy.s20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _buildFierteNationFull()),
                      const SizedBox(height: ThixPolicy.s20),
                      _buildQuickAccess(),
                      const SizedBox(height: ThixPolicy.s20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _buildAlertRow()),
                      const SizedBox(height: ThixPolicy.s20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _buildFiguresHistoriquesBig()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Barre supérieure (Glass) ────────────────────────────────────
  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: bgNavy.withOpacity(0.7),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      toolbarHeight: ThixPolicy.appBarHeight, 
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.menu, color: Colors.white, size: 24),
          const SizedBox(width: ThixPolicy.s12),
          Container(
            padding: const EdgeInsets.all(ThixPolicy.s4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: rdcYellow, width: 1.5),
              color: glassColor,
            ),
            child: const Center(
              child: Text('CD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: ThixPolicy.s10),
          const Expanded(
            child: Text(
              'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2, letterSpacing: 0.5),
            ),
          ),
          _circleIcon(Icons.search, () => _showComingSoon()),
          const SizedBox(width: ThixPolicy.s12),
          _circleIcon(Icons.notifications_none_rounded, () {}, hasBadge: true),

          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: ThixPolicy.s12),
              child: InkWell(
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                onTap: _goToAdminSpace,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rdcRed.withOpacity(0.8), border: Border.all(color: rdcRed)),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap, {bool hasBadge = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: glassColor, border: Border.all(color: glassBorder)),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: -2, right: -2,
            child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: rdcYellow, shape: BoxShape.circle), child: const Text('3', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: bgNavy))),
          ),
      ],
    );
  }

  // ─── Carrousel patriotique ──────────────────────────────────────
  Widget _buildPatrioticCarousel(bool isAdmin) {
    return SizedBox(
      height: 160, 
      child: PageView.builder(
        controller: _patrioticCtrl,
        itemCount: patrioticPosters.length,
        onPageChanged: (index) => setState(() => _currentPatriotic = index),
        itemBuilder: (context, index) {
          final p = patrioticPosters[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: p['img']!, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, bgNavy.withOpacity(0.9)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: ThixPolicy.s20, left: ThixPolicy.s20, right: ThixPolicy.s20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s8, vertical: ThixPolicy.s4),
                          decoration: BoxDecoration(color: rdcRed, borderRadius: BorderRadius.circular(ThixPolicy.s4)),
                          child: Text(p['title']!.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                        ),
                        const SizedBox(height: ThixPolicy.s8),
                        Text(p['subtitle']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.1)),
                      ],
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

  // ─── Section Autorités ───────────────────────────────────────────
  Widget _buildAutoritesFullWidth() {
    final authAsync = ref.watch(topAuthoritiesProvider);

    return _glassCard(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Gouvernance', actionText: 'Annuaire', onTap: () => context.push('/mon-pays/authorities')),
          const SizedBox(height: ThixPolicy.s20),
          authAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (_, __) => const Text('Erreur', style: TextStyle(color: Colors.red)),
            data: (authorities) {
              if (authorities.isEmpty) return const Text('Aucune autorité', style: TextStyle(color: Colors.white54));

              int getPriority(String? title) {
                final t = (title ?? '').toLowerCase();
                if (t.contains('président')) return 1;
                if (t.contains('premier ministre')) return 2;
                if (t.contains('sénat')) return 3;
                if (t.contains('assemblée')) return 4;
                return 99;
              }

              final sortedList = authorities..sort((a, b) => getPriority(a.title).compareTo(getPriority(b.title)));
              final president = sortedList.first;
              final others = sortedList.length > 1 ? sortedList.sublist(1).take(3).toList() : [];

              return Column(
                children: [
                  InkWell(
                    onTap: () => context.push('/mon-pays/authorities/${president.id}'),
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    child: Container(
                      padding: const EdgeInsets.all(ThixPolicy.s12),
                      decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: glassBorder)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [rdcYellow, rdcRed], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                            child: CircleAvatar(radius: 42, backgroundImage: NetworkImage(president.imageUrl ?? 'https://i.pravatar.cc/200')),
                          ),
                          const SizedBox(width: ThixPolicy.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PRÉSIDENT DE LA RÉPUBLIQUE', style: TextStyle(color: rdcYellow.withOpacity(0.9), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                const SizedBox(height: ThixPolicy.s6),
                                Text(president.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, height: 1.1)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  if (others.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: others.map((a) => Expanded(
                        child: InkWell(
                          onTap: () => context.push('/mon-pays/authorities/${a.id}'),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 2)),
                                child: CircleAvatar(radius: 32, backgroundImage: NetworkImage(a.imageUrl ?? 'https://i.pravatar.cc/100')),
                              ),
                              const SizedBox(height: ThixPolicy.s8),
                              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)),
                              Text(a.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white54)),
                            ],
                          ),
                        ),
                      )).toList(),
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

    return _glassCard(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('À la Une', actionText: 'Toutes les infos', onTap: () => context.push('/mon-pays/news')),
          const SizedBox(height: ThixPolicy.s16),
          SizedBox(
            height: 160,
            child: newsState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: Colors.red))),
              data: (articles) {
                if (articles.isEmpty) return const Center(child: Text('Aucune actualité', style: TextStyle(color: Colors.white54)));

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                  itemBuilder: (context, i) {
                    final article = articles[i];
                    String dateStr = article.publishedAt != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(article.publishedAt!) : '';

                    return InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NewsDetailPage(article: article))),
                      child: Container(
                        width: 140,
                        decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(ThixPolicy.rXs), border: Border.all(color: glassBorder)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXs)),
                              child: article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: article.coverImageUrl!, height: 85, width: 140, fit: BoxFit.cover)
                                  : Container(height: 85, width: 140, color: Colors.white10, child: const Icon(Icons.newspaper, color: Colors.white54)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(ThixPolicy.s10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateStr, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: rdcYellow)),
                                  const SizedBox(height: ThixPolicy.s4),
                                  Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
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
      {'icon': Icons.business, 'label': 'Entreprises Publiques'},
      {'icon': Icons.shield, 'label': 'Sécurité'},
    ];
    return _glassCard(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        children: [
          _sectionHeader('Institutions', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: ThixPolicy.s16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.1, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: items.length,
            itemBuilder: (context, i) {
              return InkWell(
                onTap: _showComingSoon,
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                child: Container(
                  decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(ThixPolicy.rXs), border: Border.all(color: glassBorder)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i]['icon'] as IconData, color: Colors.white, size: 24),
                      const SizedBox(height: ThixPolicy.s8),
                      Text(items[i]['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
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
    return _glassCard(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        children: [
          _sectionHeader('Découpage Territorial', actionText: 'Voir la carte', onTap: () => context.push('/mon-pays/provinces')),
          const SizedBox(height: ThixPolicy.s16),
          SizedBox(
            height: 80, 
            child: prov.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (c, i) {
                    final p = list[i];
                    return InkWell(
                      onTap: () => context.push('/mon-pays/provinces/${p.id}'),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.all(ThixPolicy.s10),
                        decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(ThixPolicy.rXs), border: Border.all(color: glassBorder)),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, color: Colors.white10,
                                image: p.coatOfArmsUrl != null && p.coatOfArmsUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(p.coatOfArmsUrl!), fit: BoxFit.contain) : null,
                              ),
                              child: (p.coatOfArmsUrl == null || p.coatOfArmsUrl!.isEmpty) ? Center(child: Text(p.code.substring(0, 2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
                            ),
                            const SizedBox(width: ThixPolicy.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 11)),
                                  Text(p.capital, style: const TextStyle(fontSize: 9, color: Colors.white54)),
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

  // ─── Ils rendent fière la nation ──────────────────────────────────
  Widget _buildFierteNationFull() {
    final citizensAsync = ref.watch(citizensProvider);

    return _glassCard(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Ils rendent fière la nation', actionText: 'Tous les profils', onTap: () => _showComingSoon()),
          const SizedBox(height: ThixPolicy.s6),
          const Text('Ils bâtissent la RDC au quotidien par leur excellence.', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: ThixPolicy.s16),
          
          SizedBox(
            height: 110, 
            child: citizensAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (e, _) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.red))),
              data: (citizens) {
                if (citizens.isEmpty) return const Center(child: Text('Aucun profil pour le moment.', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)));

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: citizens.length,
                  separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                  itemBuilder: (context, i) {
                    final citizen = citizens[i];
                    return SizedBox(
                      width: 75,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rdcYellow, width: 1.5)),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white10,
                              backgroundImage: citizen.photoUrl != null && citizen.photoUrl!.isNotEmpty ? CachedNetworkImageProvider(citizen.photoUrl!) : null,
                              child: (citizen.photoUrl == null || citizen.photoUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 24) : null,
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s8),
                          Text(citizen.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 11)),
                          Text(citizen.domain, style: const TextStyle(fontSize: 9, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      {'icon': Icons.videocam, 'label': 'Vidéos'},
      {'icon': Icons.folder, 'label': 'Documents'},
      {'icon': Icons.balance, 'label': 'Lois', 'route': '/mon-pays/laws'},
      {'icon': Icons.campaign, 'label': 'Participer'},
    ];
    return SizedBox(
      height: 80, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
        itemBuilder: (c, i) {
          final item = items[i];
          final route = item['route'] as String?;
          return InkWell(
            onTap: () => route != null ? context.push(route) : _showComingSoon(),
            child: _glassCard(
              width: 80,
              padding: const EdgeInsets.all(ThixPolicy.s8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['icon'] as IconData, color: Colors.white, size: 24),
                  const SizedBox(height: ThixPolicy.s8),
                  Text(item['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
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
          const SizedBox(width: ThixPolicy.s12),
          Expanded(child: _alertCard(rdcYellow, 'Recherche\nCitoyenne', Icons.search_rounded)),
        ],
      );

  Widget _alertCard(Color color, String title, IconData icon) => _glassCard(
        customBorder: color.withOpacity(0.5),
        customColor: color.withOpacity(0.1),
        padding: const EdgeInsets.all(ThixPolicy.s16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(child: Text(title, maxLines: 2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: color))),
          ],
        ),
      );

  // ─── Figures Historiques ───────────────────
  Widget _buildFiguresHistoriquesBig() {
    return _glassCard(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Figures Historiques', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: ThixPolicy.s6),
          const Text('Découvrez ceux qui ont marqué notre histoire.', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: ThixPolicy.s16),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.history_edu, size: 40, color: Colors.white24),
                  SizedBox(height: ThixPolicy.s12),
                  Text('Module en préparation', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
