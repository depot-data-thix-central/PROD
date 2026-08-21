// lib/presentation/mon_pays/mon_pays_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'providers/news_provider.dart';
import 'providers/provinces_provider.dart';
import 'providers/authorities_provider.dart';
import 'providers/citizens_provider.dart';

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
  // === COULEURS INSTITUTIONNELLES ===
  static const Color instBlue = Color(0xFF0A1F44); // Bleu profond
  static const Color instYellow = Color(0xFFFFD100); // Jaune RDC
  static const Color instRed = Color(0xFFCE1126); // Rouge RDC
  static const Color instBg = Color(0xFFF4F6F9); // Fond très clair
  static const Color instBorder = Color(0xFFE7EAF3); // Bordures

  void _goToAdminSpace() {
    try {
      context.push('/mon-pays/admin');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'accéder à l\'Espace Admin')),
      );
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Module en cours de développement', style: TextStyle(color: Colors.white)),
        backgroundColor: instBlue,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: instBg,
      // Suppression de la bottomNavigationBar comme demandé
      body: CustomScrollView(
        slivers: [
          _buildTopBar(isAdmin),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER INSTITUTIONNEL (Remplace les mockups)
                _buildInstitutionalHeader(),
                const SizedBox(height: 20),
                
                // 2. AUTORITÉS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAutorites(),
                ),
                const SizedBox(height: 20),

                // 3. ACTUALITÉS (À LA UNE) CONNECTÉES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildActualites(),
                ),
                const SizedBox(height: 20),

                // 4. CITOYENS EXEMPLAIRES CONNECTÉS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCitoyens(),
                ),
                const SizedBox(height: 20),

                // 5. PROVINCES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildProvinces(),
                ),
                const SizedBox(height: 20),

                // 6. AGENCES & INSTITUTIONS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAgences(),
                ),
                const SizedBox(height: 20),

                // 7. ACCÈS RAPIDES & ALERTES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAccesRapides(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Barre Supérieure ────────────────────────────────────────────
  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          InkWell(
            onTap: () => context.canPop() ? context.pop() : null,
            child: const Icon(Icons.arrow_back, color: instBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 22,
            decoration: BoxDecoration(color: instBlue, borderRadius: BorderRadius.circular(4)),
            child: const Center(child: Text('CD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: instBlue, height: 1.1),
            ),
          ),
          if (isAdmin)
            InkWell(
              onTap: _goToAdminSpace,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: instRed, borderRadius: BorderRadius.circular(4)),
                child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: Container(color: instYellow, height: 4), // Ligne jaune RDC
      ),
    );
  }

  // ─── Header Institutionnel ───────────────────────────────────────
  Widget _buildInstitutionalHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: instBlue,
        border: Border(bottom: BorderSide(color: instYellow, width: 4)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ESPACE CITOYEN",
            style: TextStyle(color: instYellow, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
          ),
          SizedBox(height: 8),
          Text(
            "Informations Officielles\net Services Publics",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2),
          ),
        ],
      ),
    );
  }

  // ─── Section Autorités ───────────────────────────────────────────
  Widget _buildAutorites() {
    final authAsync = ref.watch(topAuthoritiesProvider);

    return _buildSectionContainer(
      title: 'Hautes Autorités',
      actionText: 'Voir l\'annuaire',
      onAction: () => context.push('/mon-pays/authorities'),
      child: authAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: instBlue)),
        error: (_, __) => const Text('Erreur de chargement', style: TextStyle(color: instRed)),
        data: (authorities) {
          if (authorities.isEmpty) return const Text('Aucune donnée', style: TextStyle(color: Colors.grey));
          
          final president = authorities.firstWhere((a) => (a.title ?? '').toLowerCase().contains('président'), orElse: () => authorities.first);
          
          return Column(
            children: [
              // Carte Président
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: instBorder),
                  borderRadius: BorderRadius.circular(8),
                  color: instBg,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: instYellow, width: 2),
                        image: DecorationImage(
                          image: NetworkImage(president.imageUrl ?? 'https://i.pravatar.cc/200'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(president.title?.toUpperCase() ?? 'PRÉSIDENT', style: const TextStyle(fontSize: 10, color: instBlue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(president.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Section À la Une (Actualités) ───────────────────────────────
  Widget _buildActualites() {
    final newsAsync = ref.watch(newsProvider);

    return _buildSectionContainer(
      title: 'À la Une',
      actionText: 'Toutes les actualités',
      onAction: () => context.push('/mon-pays/news'),
      child: SizedBox(
        height: 180,
        child: newsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: instBlue)),
          error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: instRed))),
          data: (news) {
            if (news.isEmpty) return const Center(child: Text('Aucune actualité', style: TextStyle(color: Colors.grey)));
            
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: news.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = news[i];
                final date = item.publishedAt != null ? DateFormat('dd/MM/yyyy').format(item.publishedAt!) : '';

                return Container(
                  width: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: instBorder),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: instBg,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          image: item.coverImageUrl != null && item.coverImageUrl!.isNotEmpty
                              ? DecorationImage(image: NetworkImage(item.coverImageUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: (item.coverImageUrl == null || item.coverImageUrl!.isEmpty)
                            ? const Center(child: Icon(Icons.newspaper, color: instBlue, size: 32))
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: instBlue)),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── Section Citoyens Exemplaires ────────────────────────────────
  Widget _buildCitoyens() {
    final citizensAsync = ref.watch(citizensProvider);

    return _buildSectionContainer(
      title: 'Citoyens Exemplaires',
      actionText: 'Voir tous',
      onAction: _showComingSoon,
      child: SizedBox(
        height: 110,
        child: citizensAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: instBlue)),
          error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: instRed))),
          data: (citizens) {
            if (citizens.isEmpty) return const Center(child: Text('Aucun citoyen listé', style: TextStyle(color: Colors.grey)));

            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: citizens.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final citizen = citizens[i];
                return SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: instBlue, width: 2),
                          image: citizen.photoUrl != null && citizen.photoUrl!.isNotEmpty
                              ? DecorationImage(image: NetworkImage(citizen.photoUrl!), fit: BoxFit.cover)
                              : null,
                          color: instBg,
                        ),
                        child: (citizen.photoUrl == null || citizen.photoUrl!.isEmpty)
                            ? const Icon(Icons.person, color: instBlue)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(citizen.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: instBlue)),
                      Text(citizen.domain, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── Section Provinces ───────────────────────────────────────────
  Widget _buildProvinces() {
    final provAsync = ref.watch(provincesProvider(null));

    return _buildSectionContainer(
      title: 'Découpage Provincial',
      actionText: 'Carte complète',
      onAction: () => context.push('/mon-pays/provinces'),
      child: SizedBox(
        height: 80,
        child: provAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: instBlue)),
          error: (_, __) => const Text('Erreur', style: TextStyle(color: instRed)),
          data: (list) {
            if (list.isEmpty) return const Text('Aucune province', style: TextStyle(color: Colors.grey));
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final p = list[i];
                return InkWell(
                  onTap: () => context.push('/mon-pays/provinces/${p.id}'),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: instBorder),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: instBg,
                            image: p.coatOfArmsUrl != null && p.coatOfArmsUrl!.isNotEmpty
                                ? DecorationImage(image: NetworkImage(p.coatOfArmsUrl!), fit: BoxFit.contain)
                                : null,
                          ),
                          child: (p.coatOfArmsUrl == null || p.coatOfArmsUrl!.isEmpty)
                              ? Center(child: Text(p.code.substring(0, 2), style: const TextStyle(color: instBlue, fontWeight: FontWeight.bold, fontSize: 12)))
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: instBlue)),
                              Text(p.capital, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── Section Agences & Institutions ──────────────────────────────
  Widget _buildAgences() {
    final items = [
      {'icon': Icons.account_balance, 'label': 'Présidence'},
      {'icon': Icons.flag, 'label': 'Gouvernement'},
      {'icon': Icons.gavel, 'label': 'Parlement'},
      {'icon': Icons.work, 'label': 'Ministères'},
      {'icon': Icons.business, 'label': 'Entreprises Publiques'},
      {'icon': Icons.local_police, 'label': 'Justice & Sécurité'},
    ];

    return _buildSectionContainer(
      title: 'Institutions',
      actionText: '',
      onAction: () {},
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          return InkWell(
            onTap: _showComingSoon,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: instBorder),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(items[i]['icon'] as IconData, color: instBlue, size: 20),
                  const SizedBox(height: 6),
                  Text(items[i]['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: instBlue)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Accès Rapides ───────────────────────────────────────────────
  Widget _buildAccesRapides() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.push('/mon-pays/laws'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: instBlue, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.balance, color: instYellow, size: 24),
                      SizedBox(width: 12),
                      Text('Lois & Textes\nOfficiels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _showComingSoon,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: instBorder), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.folder, color: instBlue, size: 24),
                      SizedBox(width: 12),
                      Text('Documents\nPublics', style: TextStyle(color: instBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: instRed.withOpacity(0.1), border: Border.all(color: instRed.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: instRed),
              SizedBox(width: 12),
              Text('Personnes Recherchées / Alertes', style: TextStyle(color: instRed, fontWeight: FontWeight.bold, fontSize: 12)),
              Spacer(),
              Icon(Icons.chevron_right, color: instRed),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Utilitaire pour les conteneurs de section ───────────────────
  Widget _buildSectionContainer({required String title, required String actionText, required VoidCallback onAction, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: instBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: instYellow), // Ligne jaune décorative
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: instBlue)),
              const Spacer(),
              if (actionText.isNotEmpty)
                InkWell(
                  onTap: onAction,
                  child: Text(actionText, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
