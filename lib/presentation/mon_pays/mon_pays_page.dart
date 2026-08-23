// lib/presentation/mon_pays/mon_pays_page.dart
// Page d'accueil du module Mon Pays — Espace Citoyen RDC (Design Blanc Pur & Institutionnel)

import 'dart:async';
import 'package:flutter/material.dart';
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
  // ─── Couleurs Institutionnelles (Blanc / Bleu / Jaune / Rouge) ───
  static const Color rdcRed = Color(0xFFCE1126); 
  static const Color rdcYellow = Color(0xFFF7D116); 
  static const Color rdcBlue = Color(0xFF0A1F44); 
  static const Color bgLight = Color(0xFFF8F9FA); // Fond très légèrement grisé pour faire ressortir les cartes blanches

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
      const SnackBar(
        content: Text('Module en cours de développement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: rdcBlue,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ─── Utilitaire Cartes Blanches (Pur & Épuré) ───────────────────
  Widget _cleanCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: rdcBlue.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, {String? actionText, VoidCallback? onTap}) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: rdcRed, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: rdcBlue, fontSize: 14, letterSpacing: 0.2)),
        const Spacer(),
        if (actionText != null && onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Text(actionText, style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, size: 16, color: Colors.blue.shade700),
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
      body: Stack(
        children: [
          // FILIGRANE DE LA CARTE DE LA RDC EN FOND
          Positioned(
            top: 150,
            right: -80,
            child: Opacity(
              opacity: 0.03, // Très subtil pour ne pas gêner la lecture
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Democratic_Republic_of_the_Congo_location_map.svg/1024px-Democratic_Republic_of_the_Congo_location_map.svg.png',
                width: 450,
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
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildPatrioticCarousel(isAdmin),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildAutoritesFullWidth()),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildALaUneFull()),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildAgencesFull()),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildProvincesSection()),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildFierteNationFull()),
                      const SizedBox(height: 16),
                      _buildQuickAccess(),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildAlertRow()),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildFiguresHistoriquesBig()),
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

  // ─── Barre supérieure (Blanche & Épurée) ─────────────────────────
  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 60, 
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.menu, color: rdcBlue, size: 24),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: rdcBlue, borderRadius: BorderRadius.circular(4)),
            child: const Center(child: Text('CD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: rdcBlue, height: 1.2),
            ),
          ),
          _circleIcon(Icons.search, () => _showComingSoon()),
          const SizedBox(width: 8),
          _circleIcon(Icons.notifications_none_rounded, () {}, hasBadge: true),

          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _goToAdminSpace,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rdcRed.withOpacity(0.1)),
                  child: const Icon(Icons.admin_panel_settings, color: rdcRed, size: 18),
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade100),
            child: Icon(icon, size: 20, color: rdcBlue),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: -2, right: -2,
            child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: rdcYellow, shape: BoxShape.circle), child: const Text('3', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: rdcBlue))),
          ),
      ],
    );
  }

  // ─── Carrousel patriotique ──────────────────────────────────────
  Widget _buildPatrioticCarousel(bool isAdmin) {
    return SizedBox(
      height: 140, // Plus compact
      child: PageView.builder(
        controller: _patrioticCtrl,
        itemCount: patrioticPosters.length,
        onPageChanged: (index) => setState(() => _currentPatriotic = index),
        itemBuilder: (context, index) {
          final p = patrioticPosters[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: p['img']!, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, rdcBlue.withOpacity(0.8)]),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: rdcYellow, borderRadius: BorderRadius.circular(4)),
                          child: Text(p['title']!.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: rdcBlue)),
                        ),
                        const SizedBox(height: 4),
                        Text(p['subtitle']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.1)),
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

  // ─── Section Hautes Autorités (Corrigée et bien classée) ─────────
  Widget _buildAutoritesFullWidth() {
    final authAsync = ref.watch(topAuthoritiesProvider);

    return _cleanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Les Hautes Autorités', actionText: 'Annuaire', onTap: () => context.push('/mon-pays/authorities')),
          const SizedBox(height: 16),
          authAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
            error: (_, __) => const Text('Erreur de chargement', style: TextStyle(color: Colors.red)),
            data: (authorities) {
              if (authorities.isEmpty) return const Text('Aucune autorité enregistrée', style: TextStyle(color: Colors.grey));

              // ✅ CORRECTION DU CLASSEMENT : On cible spécifiquement les mots-clés uniques
              int getPriority(String? title) {
                final t = (title ?? '').toLowerCase();
                if (t.contains('république') || t.contains('republique')) return 1; // 1. Président de la République
                if (t.contains('premier') || t.contains('première')) return 2; // 2. Premier Ministre
                if (t.contains('sénat') || t.contains('senat')) return 3; // 3. Président du Sénat
                if (t.contains('assemblée') || t.contains('assemblee')) return 4; // 4. Président de l'Assemblée
                return 99;
              }

              final sortedList = authorities..sort((a, b) => getPriority(a.title).compareTo(getPriority(b.title)));
              final president = sortedList.first;
              final others = sortedList.length > 1 ? sortedList.sublist(1).take(3).toList() : [];

              return Column(
                children: [
                  // CARTE DU PRÉSIDENT DE LA RÉPUBLIQUE
                  InkWell(
                    onTap: () => context.push('/mon-pays/authorities/${president.id}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [rdcBlue, rdcRed, rdcYellow])),
                            child: CircleAvatar(radius: 36, backgroundImage: NetworkImage(president.imageUrl ?? 'https://i.pravatar.cc/200')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: rdcBlue, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('PRÉSIDENT DE LA RÉPUBLIQUE', style: TextStyle(color: rdcYellow, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 4),
                                Text(president.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: rdcBlue, height: 1.1)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // LES 3 AUTRES AUTORITÉS (Premier Ministre, Sénat, Assemblée)
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
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rdcYellow, width: 1.5)),
                                child: CircleAvatar(radius: 28, backgroundImage: NetworkImage(a.imageUrl ?? 'https://i.pravatar.cc/100')),
                              ),
                              const SizedBox(height: 6),
                              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: rdcBlue)),
                              Text(a.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Colors.grey)),
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
          const SizedBox(height: 12),
          SizedBox(
            height: 140, // Taille réduite
            child: newsState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
              error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: Colors.red))),
              data: (articles) {
                if (articles.isEmpty) return const Center(child: Text('Aucune actualité', style: TextStyle(color: Colors.grey, fontSize: 11)));

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final article = articles[i];
                    String dateStr = article.publishedAt != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(article.publishedAt!) : '';

                    return InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NewsDetailPage(article: article))),
                      child: Container(
                        width: 130,
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: article.coverImageUrl!, height: 75, width: 130, fit: BoxFit.cover)
                                  : Container(height: 75, width: 130, color: Colors.grey.shade200, child: const Icon(Icons.newspaper, color: Colors.grey)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateStr, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: rdcRed)),
                                  const SizedBox(height: 2),
                                  Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rdcBlue, height: 1.2)),
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
      {'icon': Icons.business, 'label': 'Entreprises'},
      {'icon': Icons.shield, 'label': 'Sécurité'},
    ];
    return _cleanCard(
      child: Column(
        children: [
          _sectionHeader('Institutions', actionText: 'Explorer', onTap: () => _showComingSoon()),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: items.length,
            itemBuilder: (context, i) {
              return InkWell(
                onTap: _showComingSoon,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i]['icon'] as IconData, color: rdcBlue, size: 20),
                      const SizedBox(height: 4),
                      Text(items[i]['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: rdcBlue)),
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
          const SizedBox(height: 12),
          SizedBox(
            height: 60, 
            child: prov.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (c, i) {
                    final p = list[i];
                    return InkWell(
                      onTap: () => context.push('/mon-pays/provinces/${p.id}'),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, color: rdcBlue,
                                image: p.coatOfArmsUrl != null && p.coatOfArmsUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(p.coatOfArmsUrl!), fit: BoxFit.contain) : null,
                              ),
                              child: (p.coatOfArmsUrl == null || p.coatOfArmsUrl!.isEmpty) ? Center(child: Text(p.code.substring(0, 2), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))) : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: rdcBlue, fontSize: 10)),
                                  Text(p.capital, style: const TextStyle(fontSize: 8, color: Colors.grey)),
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
          _sectionHeader('Ils rendent fière la nation', actionText: 'Tous les profils', onTap: () => _showComingSoon()),
          const SizedBox(height: 4),
          const Text('Ils bâtissent la RDC au quotidien par leur excellence.', style: TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 90, 
            child: citizensAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: rdcBlue)),
              error: (e, _) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.red))),
              data: (citizens) {
                if (citizens.isEmpty) return const Center(child: Text('Aucun profil pour le moment.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 11)));

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: citizens.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final citizen = citizens[i];
                    return SizedBox(
                      width: 65,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rdcYellow, width: 1.5)),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey.shade100,
                              backgroundImage: citizen.photoUrl != null && citizen.photoUrl!.isNotEmpty ? CachedNetworkImageProvider(citizen.photoUrl!) : null,
                              child: (citizen.photoUrl == null || citizen.photoUrl!.isEmpty) ? const Icon(Icons.person, color: rdcBlue, size: 20) : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(citizen.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: rdcBlue, fontSize: 9)),
                          Text(citizen.domain, style: const TextStyle(fontSize: 8, color: rdcRed), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      height: 70, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final item = items[i];
          final route = item['route'] as String?;
          return InkWell(
            onTap: () => route != null ? context.push(route) : _showComingSoon(),
            child: Container(
              width: 75,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['icon'] as IconData, color: rdcBlue, size: 20),
                  const SizedBox(height: 6),
                  Text(item['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: rdcBlue)),
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

  Widget _alertCard(Color color, String title, IconData icon) => _cleanCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(title, maxLines: 2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: color))),
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
          const SizedBox(height: 4),
          const Text('Découvrez ceux qui ont marqué notre histoire.', style: TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.history_edu, size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  const Text('Module en préparation', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
