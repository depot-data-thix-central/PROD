// lib/presentation/mon_pays/pages/laws/laws_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/article.dart';
import 'article_type_page.dart';

class LawsPage extends StatefulWidget {
  const LawsPage({super.key});

  @override
  State<LawsPage> createState() => _LawsPageState();
}

class _LawsPageState extends State<LawsPage> {
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBanner = 0;

  // ============================================================
  // CHARTE THIX ID — Design Institutionnel (Navy / Bleu / Or)
  // + accents drapeau RDC réservés à la bannière de sensibilisation
  // ============================================================
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color hairline = Color(0xFFE7EAF3);
  static const Color rdcSkyBlue = Color(0xFF007FFF);
  static const Color rdcRed = Color(0xFFCE1021);

  // ─── Bannières de sensibilisation civique (tournantes) ───
  final List<Map<String, dynamic>> _civicBanners = const [
    {
      'title': 'Connaître ses droits',
      'subtitle': "Chaque citoyen a le droit d'accéder gratuitement à la loi",
      'icon': Icons.gavel_rounded,
    },
    {
      'title': 'Connaître ses devoirs',
      'subtitle': 'Respecter la Constitution est le premier devoir civique',
      'icon': Icons.volunteer_activism_rounded,
    },
    {
      'title': 'La loi pour tous',
      'subtitle': "Nul n'est censé ignorer la loi — informez-vous ici",
      'icon': Icons.balance_rounded,
    },
    {
      'title': 'Citoyenneté active',
      'subtitle': 'Comprendre les textes fondamentaux pour mieux participer',
      'icon': Icons.groups_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startBannerAutoplay();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerAutoplay() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_bannerController.hasClients) {
        final next = (_currentBanner + 1) % _civicBanners.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
        setState(() => _currentBanner = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final types = ArticleType.values.where((t) => t != ArticleType.autre).toList();

    return Scaffold(
      backgroundColor: ivory,
      body: CustomScrollView(
        slivers: [
          _buildInstitutionalHeader(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCivicBannerCarousel(),
                  const SizedBox(height: 22),
                  const Text(
                    'Textes de référence',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Consultez la Constitution et les codes en vigueur en RDC',
                    style: TextStyle(fontSize: 11.5, color: mutedText, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.05,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: types.length,
                    itemBuilder: (context, index) {
                      final type = types[index];
                      return _menuItem(context, type, index);
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER INSTITUTIONNEL — navy, cocarde RDC, recherche
  // ============================================================
  Widget _buildInstitutionalHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: navyDeep,
      surfaceTintColor: navyDeep,
      toolbarHeight: 62,
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [rdcSkyBlue, rdcRed]),
              border: Border.all(color: gold, width: 1.4),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.balance_rounded, size: 13, color: gold),
          ),
          const SizedBox(width: 10),
          const Text(
            'Valeurs & Lois',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
      actions: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recherche globale - bientôt disponible')),
            );
          },
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: const Icon(Icons.search_rounded, size: 17, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BANNIÈRE DE SENSIBILISATION — carrousel civique, drapeau RDC
  // ============================================================
  Widget _buildCivicBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 138,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _civicBanners.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) {
              final banner = _civicBanners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [navyDeep, navy, primaryBlue],
                  ),
                  boxShadow: [
                    BoxShadow(color: navyDeep.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 10)),
                  ],
                ),
                child: Stack(
                  children: [
                    // Diagonale façon drapeau RDC en filigrane
                    Positioned(
                      right: -26,
                      bottom: -26,
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Container(
                          width: 140,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [rdcRed, gold, rdcSkyBlue]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: gold.withOpacity(0.5)),
                            ),
                            child: Icon(banner['icon'] as IconData, color: gold, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  banner['title'] as String,
                                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  banner['subtitle'] as String,
                                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500, height: 1.35),
                                ),
                              ],
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_civicBanners.length, (i) {
            final active = i == _currentBanner;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? gold : hairline,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ============================================================
  // CARTE TYPE DE TEXTE — institutionnelle, icône cerclée or
  // ============================================================
  Widget _menuItem(BuildContext context, ArticleType type, int index) {
    final iconMap = {
      ArticleType.constitution: Icons.menu_book_rounded,
      ArticleType.codePenal: Icons.gavel_rounded,
      ArticleType.codeCivil: Icons.description_rounded,
      ArticleType.codeTravail: Icons.engineering_rounded,
      ArticleType.codeFiscal: Icons.account_balance_wallet_rounded,
      ArticleType.codeMinier: Icons.diamond_rounded,
      ArticleType.codeForestier: Icons.park_rounded,
      ArticleType.codeElectoral: Icons.how_to_vote_rounded,
      ArticleType.loiOrganique: Icons.article_rounded,
      ArticleType.ordonnance: Icons.description_outlined,
      ArticleType.decret: Icons.assignment_rounded,
    };
    final icon = iconMap[type] ?? Icons.bookmark_rounded;

    // Alternance discrète des couleurs d'accent (drapeau RDC) tous les 3 items
    final accentColors = [gold, rdcSkyBlue, rdcRed];
    final accent = accentColors[index % accentColors.length];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleTypePage(type: type, title: type.label),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hairline),
          boxShadow: [
            BoxShadow(color: navyDeep.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: navyDeep,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.6),
              ),
              child: Icon(icon, size: 24, color: gold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                type.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
