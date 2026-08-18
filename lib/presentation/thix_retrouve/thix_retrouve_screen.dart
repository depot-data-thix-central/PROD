import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/objet_model.dart';
import 'pages/declarer_objet_page.dart';
import 'pages/carte_signalements_page.dart';
import 'pages/object_detail_page.dart';
import 'pages/mes_recherches_page.dart';
import 'providers/objet_providers.dart';

class ThixRetrouveScreen extends ConsumerStatefulWidget {
  const ThixRetrouveScreen({super.key});

  @override
  ConsumerState<ThixRetrouveScreen> createState() => _ThixRetrouveScreenState();
}

class _ThixRetrouveScreenState extends ConsumerState<ThixRetrouveScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final objetsAsync = ref.watch(objetsRecentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black87),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Text(
                      'THIX CENTRAL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(objetsRecentsProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Logo ──────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.search, color: Color(0xFFFBBF24), size: 28),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'THIX ',
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'RETROUVE',
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Perdu ? Trouvé ? On vous aide !',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Boutons Perdu / Trouvé ────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              color: const Color(0xFFF59E0B),
                              icon: Icons.search,
                              title: "J'ai perdu\nun objet",
                              subtitle: 'Déclarez un objet\nque vous avez perdu',
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DeclarerObjetPage(type: StatutObjet.perdu),
                                  ),
                                );
                                if (result == true) {
                                  ref.invalidate(objetsRecentsProvider);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              color: const Color(0xFF2563EB),
                              icon: Icons.inventory_2_outlined,
                              title: "J'ai trouvé\nun objet",
                              subtitle: 'Déclarez un objet\nque vous avez trouvé',
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DeclarerObjetPage(type: StatutObjet.trouve),
                                  ),
                                );
                                if (result == true) {
                                  ref.invalidate(objetsRecentsProvider);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Voir les objets autour de moi ─────────────
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CarteSignalementsPage()),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Voir les objets autour de moi',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Explorer la carte',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Objets récents ────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Objets récents',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MesRecherchesPage()),
                              );
                            },
                            child: Text(
                              'Voir tout',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── Liste dynamique (Riverpod) ────────────────
                      objetsAsync.when(
                        data: (objets) {
                          if (objets.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aucun objet pour le moment',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Soyez le premier à déclarer !',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: objets.take(8).map((obj) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ObjectDetailPage(
                                        title: obj.titre,
                                        status: obj.statutLabel,
                                        location: obj.lieu,
                                        time: _formatDate(obj.date),
                                        description: obj.description,
                                        reward: obj.recompense ?? '',
                                        imageUrl: obj.imageUrl, // <--- AJOUTÉ ICI
                                      ),
                                    ),
                                  );
                                },
                                child: _buildObjectCard(obj),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        error: (err, stack) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'Impossible de charger les objets',
                                  style: GoogleFonts.inter(color: Colors.red[700]),
                                ),
                                TextButton(
                                  onPressed: () => ref.invalidate(objetsRecentsProvider),
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final timeStr = '${date.hour}h${date.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) {
      return 'Aujourd\'hui, $timeStr';
    }
    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Hier, $timeStr';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _iconForCategorie(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'téléphone':
        return Icons.phone_android;
      case 'portefeuille / sac':
        return Icons.account_balance_wallet;
      case 'clés':
        return Icons.vpn_key;
      case 'sac à dos':
        return Icons.backpack;
      case 'bijoux / montre':
        return Icons.watch;
      case 'documents':
        return Icons.description_outlined;
      case 'écouteurs / accessoires':
        return Icons.headphones;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildActionCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withOpacity(0.9),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectCard(ObjetModel obj) {
    final isLost = obj.statut == StatutObjet.perdu;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Photo ou icône ────────────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: obj.imageUrl != null && obj.imageUrl!.isNotEmpty
                  ? Image.network(
                      obj.imageUrl!,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey[400],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Icon(
                        _iconForCategorie(obj.categorie),
                        size: 28,
                        color: Colors.grey[700],
                      ),
                    )
                  : Icon(
                      _iconForCategorie(obj.categorie),
                      size: 28,
                      color: Colors.grey[700],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obj.titre,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${obj.statutLabel} • ${_formatDate(obj.date)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isLost ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  obj.lieu,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (obj.hasRecompense)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'RÉCOMPENSE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD97706),
                ),
              ),
            )
          else if (obj.statut == StatutObjet.trouve)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TROUVÉ',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);

          if (i == 2) {
            // Bouton +
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Que souhaitez-vous faire ?',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF59E0B),
                          child: Icon(Icons.search, color: Colors.white),
                        ),
                        title: const Text("J'ai perdu un objet"),
                        onTap: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeclarerObjetPage(type: StatutObjet.perdu),
                            ),
                          );
                          if (result == true) {
                            ref.invalidate(objetsRecentsProvider);
                          }
                        },
                      ),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF2563EB),
                          child: Icon(Icons.inventory_2_outlined, color: Colors.white),
                        ),
                        title: const Text("J'ai trouvé un objet"),
                        onTap: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeclarerObjetPage(type: StatutObjet.trouve),
                            ),
                          );
                          if (result == true) {
                            ref.invalidate(objetsRecentsProvider);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else if (i == 1) {
            // Services → Mes recherches
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MesRecherchesPage()),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 36, color: Color(0xFFF59E0B)),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
