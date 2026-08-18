import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/objet_model.dart';
import '../providers/objet_providers.dart';
import 'object_detail_page.dart';

class MesRecherchesPage extends ConsumerStatefulWidget {
  const MesRecherchesPage({super.key});

  @override
  ConsumerState<MesRecherchesPage> createState() => _MesRecherchesPageState();
}

class _MesRecherchesPageState extends ConsumerState<MesRecherchesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesObjetsAsync = ref.watch(mesObjetsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes recherches',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3A8A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1E3A8A),
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Objets perdus'),
            Tab(text: 'Objets trouvés'),
            Tab(text: 'Récupérés'),
          ],
        ),
      ),
      body: mesObjetsAsync.when(
        data: (objets) {
          final perdus = objets.where((o) => o.statut == StatutObjet.perdu).toList();
          final trouves = objets.where((o) => o.statut == StatutObjet.trouve).toList();
          final recuperes = objets.where((o) => o.statut == StatutObjet.recupere).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(perdus, emptyMessage: 'Aucun objet perdu déclaré'),
              _buildList(trouves, emptyMessage: 'Aucun objet trouvé déclaré'),
              _buildList(recuperes, emptyMessage: 'Aucun objet récupéré'),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text('Erreur de chargement', style: GoogleFonts.inter(color: Colors.red)),
              TextButton(
                onPressed: () => ref.invalidate(mesObjetsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<ObjetModel> items, {required String emptyMessage}) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: GoogleFonts.inter(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final obj = items[index];
        final isRecovered = obj.statut == StatutObjet.recupere;

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
                ),
              ),
            );
          },
          child: Container(
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconForCategorie(obj.categorie),
                    size: 26,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obj.titre,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${obj.statutLabel} • ${_formatDate(obj.date)}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isRecovered
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRecovered ? 'Récupéré' : 'En recherche',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isRecovered
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

    String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    // CORRECTION ICI : Utilisation de $ au lieu de \( \)
    final timeStr = '${date.hour}h${date.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) {
      return 'Aujourd\'hui, $timeStr';
    }
    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Hier, $timeStr';
    }
    // CORRECTION ICI AUSSI
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
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
