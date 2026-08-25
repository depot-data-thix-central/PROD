// lib/presentation/mon_pays/mon_pays_page.dart
// Page d'accueil du module Mon Pays — Espace Citoyen RDC (Design Premium & Institutionnel)

import 'dart:async';
import 'dart:ui'; // Requis pour le Glassmorphism (ImageFilter)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Import du Design System
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
  // ─── Couleurs Institutionnelles Premium ───
  static const Color rdcRed = Color(0xFFCE1126); 
  static const Color rdcYellow = Color(0xFFF7D116); 
  static const Color rdcBlue = Color(0xFF0A1F44); 
  static const Color rdcBlueDeep = Color(0xFF051126); 
  static const Color bgLight = Color(0xFFF4F7FB); // Fond très légèrement bleuté pour contraster les cartes pures

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
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
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
    HapticFeedback.lightImpact();
    try { context.push('/mon-pays/admin'); } catch (_) {}
  }

  void _showComingSoon() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.construction_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Module en cours de développement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: rdcBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Utilitaire Cartes Blanches (Pur & Épuré) ───────────────────
  Widget _cleanCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: rdcBlue.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, {String? actionText, VoidCallback? onTap}) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: rdcRed, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: rdcBlue, fontSize: 18, letterSpacing: -0.3)),
        const Spacer(),
        if (actionText != null && onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rdcBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(actionText, style: const TextStyle(color: rdcBlue, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: rdcBlue),
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
      backgroundColor: bgLight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // FILIGRANE DE LA CARTE DE LA RDC EN FOND
          Positioned(
            top: 150,
            right: -100,
            child: Opacity(
              opacity: 0.02, 
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Democratic_Republic_of_the_Congo_location_map.svg/1024px-Democratic_Republic_of_the_Congo_location_map.svg.png',
                width: 550,
                color: rdcBlue,
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildTopBar(isAdmin),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildPatrioticCarousel(isAdmin),
                      const SizedBox(height: 24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAutoritesFullWidth()),
                      const SizedBox(height: 24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildALaUneFull()),
                      const SizedBox(height: 24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAgencesFull()),
                      const SizedBox(height: 24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildProvincesSection()),
                      const SizedBox(height: 24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildFierteNationFull()),
                      const SizedBox(height: 24),
                      _buildQuickAccess(),
                      const SizedBox(height: 24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAlertRow()),
                      const SizedBox(height: 24),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildFiguresHistoriquesBig()),
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

  // ─── Barre supérieure (Glassmorphism & Épurée) ─────────────────────────
  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      toolbarHeight: 64, 
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5)),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          const Icon(Icons.menu_rounded, color: rdcBlue, size: 28),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [rdcBlue, rdcBlueDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: rdcBlue.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]
            ),
            child: const Center(child: Text('CD', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: rdcBlue, height: 1.2, letterSpacing: 0.2),
            ),
          ),
          _circleIcon(Icons.search_rounded, () => _showComingSoon()),
          const SizedBox(width: 10),
          _circleIcon(Icons.notifications_none_rounded, () {}, hasBadge: true),

          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _goToAdminSpace,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rdcRed.withOpacity(0.1), border: Border.all(color: rdcRed.withOpacity(0.2))),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: rdcRed, size: 20),
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
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
            child: Icon(icon, size: 20, color: rdcBlue),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: -2, right: -2,
            child: Container(
              padding: const EdgeInsets.all(4), 
              decoration: BoxDecoration(color: rdcYellow, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), 
              child: const Text('3', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: rdcBlue))
            ),
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
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: p['img']!, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter, 
                        colors: [Colors.transparent, rdcBlueDeep.withOpacity(0.95)],
                        stops: const [0.3, 1.0]
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: rdcYellow, borderRadius: BorderRadius.circular(6)),
                          child: Text(p['title']!.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: rdcBlue, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 8),
                        Text(p['subtitle']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, height: 1.1, letterSpacing: -0.5)),
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

  // ─── Section Hautes Autorités ─────────────────────────
  Widget _buildAutoritesFullWidth() {
    final authAsync = ref.watch(topAuthoritiesProvider);

    return _cleanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Les Hautes Autorités', actionText: 'Annuaire', onTap: () => context.push('/mon-pays/authorities')),
          const SizedBox(height: 20),
          authAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
            error: (_, __) => const Text('Erreur de chargement', style: TextStyle(color: Colors.red)),
            data: (authorities) {
              if (authorities.isEmpty) return const Text('Aucune autorité enregistrée', style: TextStyle(color: Colors.grey));

              // LOGIQUE DE CLASSEMENT CONSERVÉE INTACTE
              int getPriority(String? title) {
                final t = (title ?? '').toLowerCase();
                if (t.contains('république') || t.contains('republique')) return 1; 
                if (t.contains('premier') || t.contains('première')) return 2; 
                if (t.contains('sénat') || t.contains('senat')) return 3; 
                if (t.contains('assemblée') || t.contains('assemblee')) return 4; 
                return 99;
              }

              final sortedList = authorities..sort((a, b) => getPriority(a.title).compareTo(getPriority(b.title)));
              final president = sortedList.first;
              final others = sortedList.length > 1 ? sortedList.sublist(1).take(3).toList() : [];

              return Column(
                children: [
                  // CARTE DU PRÉSIDENT DE LA RÉPUBLIQUE (Design Majestueux)
                  InkWell(
                    onTap: () => context.push('/mon-pays/authorities/${president.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        borderRadius: BorderRadius.circular(20), 
                        border: Border.all(color: rdcYellow.withOpacity(0.5), width: 1.5),
                        boxShadow: [BoxShadow(color: rdcYellow.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [rdcBlue, rdcRed, rdcYellow], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                            child: CircleAvatar(radius: 40, backgroundImage: NetworkImage(president.imageUrl ?? 'https://i.pravatar.cc/200')),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: rdcBlueDeep, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('PRÉSIDENT DE LA RÉPUBLIQUE', style: TextStyle(color: rdcYellow, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                ),
                                const SizedBox(height: 8),
                                Text(president.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: rdcBlue, height: 1.1, letterSpacing: -0.5)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: rdcBlue, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // LES 3 AUTRES AUTORITÉS
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
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 2)),
                                child: CircleAvatar(radius: 32, backgroundImage: NetworkImage(a.imageUrl ?? 'https://i.pravatar.cc/100')),
                              ),
                              const SizedBox(height: 8),
                              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: rdcBlue)),
                              const SizedBox(height: 2),
                              Text(a.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, height: 1.2)),
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

  // ─── À la Une (Actualités) ──────────────────────────────────────
  Widget _buildALaUneFull() {
    final newsState = ref.watch(newsProvider);

    return _cleanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('À la Une', actionText: 'Tout lire', onTap: () => context.push('/mon-pays/news')),
          const SizedBox(height: 16),
          SizedBox(
            height: 180, 
            child: newsState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
              error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: Colors.red))),
              data: (articles) {
                if (articles.isEmpty) return const Center(child: Text('Aucune actualité', style: TextStyle(color: Colors.grey, fontSize: 12)));

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    final article = articles[i];
                    String dateStr = article.publishedAt != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(article.publishedAt!) : '';

                    return InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NewsDetailPage(article: article))),
                      child: Container(
                        width: 160,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, width: 1.5)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: article.coverImageUrl!, height: 100, width: 160, fit: BoxFit.cover)
                                  : Container(height: 100, width: 160, color: Colors.grey.shade100, child: const Icon(Icons.newspaper_rounded, color: Colors.grey, size: 30)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateStr.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: rdcRed, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: rdcBlue, height: 1.3)),
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
      {'icon': Icons.account_balance_rounded, 'label': 'Présidence'},
      {'icon': Icons.flag_rounded, 'label': 'Gouvernement'},
      {'icon': Icons.gavel_rounded, 'label': 'Parlement'},
      {'icon': Icons.work_rounded, 'label': 'Ministères'},
      {'icon': Icons.business_rounded, 'label': 'Entreprises'},
      {'icon': Icons.shield_rounded, 'label': 'Sécurité'},
    ];
    return _cleanCard(
      child: Column(
        children: [
          _sectionHeader('Institutions', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.1, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              return InkWell(
                onTap: _showComingSoon,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: rdcBlue.withOpacity(0.05), blurRadius: 4)]), child: Icon(items[i]['icon'] as IconData, color: rdcBlue, size: 22)),
                      const SizedBox(height: 8),
                      Text(items[i]['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: rdcBlue)),
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
    return _cleanCard(
      child: Column(
        children: [
          _sectionHeader('Découpage Territorial', actionText: 'Carte', onTap: () => context.push('/mon-pays/provinces')),
          const SizedBox(height: 16),
          SizedBox(
            height: 75, 
            child: prov.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (c, i) {
                    final p = list[i];
                    return InkWell(
                      onTap: () => context.push('/mon-pays/provinces/${p.id}'),
                      child: Container(
                        width: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, width: 1.5)),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, color: bgLight, border: Border.all(color: Colors.grey.shade200),
                                image: p.coatOfArmsUrl != null && p.coatOfArmsUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(p.coatOfArmsUrl!), fit: BoxFit.contain) : null,
                              ),
                              child: (p.coatOfArmsUrl == null || p.coatOfArmsUrl!.isEmpty) ? Center(child: Text(p.code.substring(0, 2), style: const TextStyle(color: rdcBlue, fontSize: 14, fontWeight: FontWeight.w900))) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: rdcBlue, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(p.capital, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
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

    return _cleanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Fierté de la Nation', actionText: 'Tous les profils', onTap: () => _showComingSoon()),
          const SizedBox(height: 6),
          const Text('Ils bâtissent la RDC au quotidien par leur excellence.', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 110, 
            child: citizensAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
              error: (e, _) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.red))),
              data: (citizens) {
                if (citizens.isEmpty) return const Center(child: Text('Aucun profil pour le moment.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)));

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: citizens.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final citizen = citizens[i];
                    return SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rdcYellow, width: 2)),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.grey.shade100,
                              backgroundImage: citizen.photoUrl != null && citizen.photoUrl!.isNotEmpty ? CachedNetworkImageProvider(citizen.photoUrl!) : null,
                              child: (citizen.photoUrl == null || citizen.photoUrl!.isEmpty) ? const Icon(Icons.person_rounded, color: rdcBlue, size: 28) : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(citizen.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: rdcBlue, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(citizen.domain, style: const TextStyle(fontSize: 9, color: rdcRed, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      {'icon': Icons.play_circle_filled_rounded, 'label': 'Vidéos'},
      {'icon': Icons.folder_shared_rounded, 'label': 'Documents'},
      {'icon': Icons.account_balance_rounded, 'label': 'Lois', 'route': '/mon-pays/laws'},
      {'icon': Icons.campaign_rounded, 'label': 'Participer'},
    ];
    return SizedBox(
      height: 85, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c, i) {
          final item = items[i];
          final route = item['route'] as String?;
          return InkWell(
            onTap: () => route != null ? context.push(route) : _showComingSoon(),
            child: Container(
              width: 90,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200, width: 1.5), boxShadow: [BoxShadow(color: rdcBlue.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['icon'] as IconData, color: rdcBlue, size: 28),
                  const SizedBox(height: 8),
                  Text(item['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: rdcBlue)),
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
          Expanded(child: _alertCard(rdcRed, 'Personne\nRecherchée', Icons.warning_amber_rounded, rdcRed.withOpacity(0.1))),
          const SizedBox(width: 16),
          Expanded(child: _alertCard(rdcBlue, 'Recherche\nCitoyenne', Icons.person_search_rounded, rdcBlue.withOpacity(0.1))),
        ],
      );

  Widget _alertCard(Color color, String title, IconData icon, Color bgColor) => _cleanCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, maxLines: 2, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: color, height: 1.2))),
          ],
        ),
      );

  // ─── Figures Historiques ───────────────────
  Widget _buildFiguresHistoriquesBig() {
    return _cleanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Figures Historiques', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: 6),
          const Text('Découvrez ceux qui ont marqué notre histoire.', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 2)),
              child: Column(
                children: [
                  Icon(Icons.history_edu_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Module en préparation', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 14))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
