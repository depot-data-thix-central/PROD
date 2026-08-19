// lib/presentation/mon_pays/admin/admin_dashboard_page.dart
// Tableau de bord de l'administration

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// === MODULE AUTORITÉS ===
import 'admin_authorities_page.dart';
import 'admin_authority_form_page.dart';

// === MODULE LOIS (ARTICLES) ===
import 'admin_articles_page.dart';
import 'admin_article_form_page.dart';

// === MODULE PROVINCES ===
import 'admin_provinces_page.dart';
import 'admin_province_form_page.dart';
import 'admin_government_form_page.dart';
import 'admin_economic_form_page.dart';
import 'admin_budget_form_page.dart';
import 'admin_tourism_form_page.dart';
import 'admin_emergency_form_page.dart';
import 'admin_administrative_form_page.dart';
import 'admin_achievement_form_page.dart';
import 'admin_media_form_page.dart';

// === NOUVEAU MODULE CONNECTÉ ===
import 'admin_news_page.dart';

// === MODULES À VENIR ===
// import 'admin_history_page.dart';
// import 'admin_agencies_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration - Mon Pays'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.canPop() ? context.pop() : context.push('/mon-pays'),
            tooltip: 'Retour à l\'accueil',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1 : Modules principaux
            const Text(
              'Modules principaux',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _adminCard(
                  context,
                  icon: Icons.account_balance,
                  label: 'Autorités',
                  subtitle: 'Gérer les dirigeants',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminAuthoritiesPage()),
                  ),
                ),
                _adminCard(
                  context,
                  icon: Icons.gavel,
                  label: 'Articles (Lois)',
                  subtitle: 'Constitution, Codes...',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminArticlesPage()),
                  ),
                ),
                _adminCard(
                  context,
                  icon: Icons.map,
                  label: 'Provinces',
                  subtitle: 'Gérer les 26 provinces',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminProvincesPage()),
                  ),
                ),
                // ✅ CARTE ACTUALITÉS CONNECTÉE
                _adminCard(
                  context,
                  icon: Icons.newspaper,
                  label: 'Actualités',
                  subtitle: 'Gérer les articles "À la Une"',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminNewsPage()),
                  ),
                ),
                _adminCard(
                  context,
                  icon: Icons.history_edu,
                  label: 'Figures Historiques',
                  subtitle: 'Bientôt disponible',
                  color: Colors.orange,
                  onTap: () => _showComingSoon(context),
                ),
                _adminCard(
                  context,
                  icon: Icons.business,
                  label: 'Agences',
                  subtitle: 'Bientôt disponible',
                  color: Colors.indigo,
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Section 2 : Administration Province (sous-ressources)
            const Text(
              'Administration des provinces',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _adminCard(
                  context,
                  icon: Icons.people,
                  label: 'Gouvernement',
                  subtitle: 'Gouverneur & Ministres',
                  color: Colors.deepPurple,
                  onTap: () => _showSelectProvinceDialog(context, 'government'),
                ),
                _adminCard(
                  context,
                  icon: Icons.attach_money,
                  label: 'Économie',
                  subtitle: 'Ressources & Investissements',
                  color: Colors.green.shade700,
                  onTap: () => _showSelectProvinceDialog(context, 'economic'),
                ),
                _adminCard(
                  context,
                  icon: Icons.monetization_on,
                  label: 'Budget',
                  subtitle: 'Priorités & Plans',
                  color: Colors.amber.shade700,
                  onTap: () => _showSelectProvinceDialog(context, 'budget'),
                ),
                _adminCard(
                  context,
                  icon: Icons.travel_explore,
                  label: 'Tourisme',
                  subtitle: 'Sites & Culture',
                  color: Colors.cyan.shade700,
                  onTap: () => _showSelectProvinceDialog(context, 'tourism'),
                ),
                _adminCard(
                  context,
                  icon: Icons.phone,
                  label: 'Urgences',
                  subtitle: 'Contacts d\'urgence',
                  color: Colors.red.shade700,
                  onTap: () => _showSelectProvinceDialog(context, 'emergency'),
                ),
                _adminCard(
                  context,
                  icon: Icons.settings_ethernet,
                  label: 'Découpage',
                  subtitle: 'Territoires & Chefferies',
                  color: Colors.indigo.shade700,
                  onTap: () => _showSelectProvinceDialog(context, 'administrative'),
                ),
                _adminCard(
                  context,
                  icon: Icons.emoji_events,
                  label: 'Réalisations',
                  subtitle: 'Projets & Accomplissements',
                  color: const Color(0xFFFFD700),
                  onTap: () => _showSelectProvinceDialog(context, 'achievement'),
                ),
                _adminCard(
                  context,
                  icon: Icons.photo_library,
                  label: 'Médias',
                  subtitle: 'Photos & Vidéos',
                  color: Colors.pink.shade700,
                  onTap: () => _showSelectProvinceDialog(context, 'media'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectProvinceDialog(BuildContext context, String section) {
    showDialog(
      context: context,
      builder: (ctx) {
        final TextEditingController _searchController = TextEditingController();
        return AlertDialog(
          title: const Text('Choisir une province'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) {},
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: 26,
                    itemBuilder: (_, i) {
                      final provinces = [
                        'Kinshasa', 'Kongo Central', 'Kwilu', 'Kwango', 'Mai-Ndombe',
                        'Kasaï', 'Kasaï-Central', 'Kasaï-Oriental', 'Lomami', 'Sankuru',
                        'Haut-Lomami', 'Lualaba', 'Haut-Katanga', 'Tanganyika', 'Nord-Kivu',
                        'Sud-Kivu', 'Maniema', 'Ituri', 'Haut-Uélé', 'Bas-Uélé',
                        'Nord-Ubangi', 'Sud-Ubangi', 'Mongala', 'Tshopo', 'Tshuapa', 'Équateur'
                      ];
                      return ListTile(
                        title: Text(provinces[i]),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openSectionForm(context, section, provinces[i]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSectionForm(BuildContext context, String section, String provinceName) {
    // TODO: Récupérer l'ID de la province par son nom
    final provinceId = 'temp-id'; // À remplacer par l'ID réel
    switch (section) {
      case 'government':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminGovernmentFormPage(provinceId: provinceId)));
        break;
      case 'economic':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEconomicFormPage(provinceId: provinceId)));
        break;
      case 'budget':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBudgetFormPage(provinceId: provinceId)));
        break;
      case 'tourism':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminTourismFormPage(provinceId: provinceId)));
        break;
      case 'emergency':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEmergencyFormPage(provinceId: provinceId)));
        break;
      case 'administrative':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAdministrativeFormPage(provinceId: provinceId)));
        break;
      case 'achievement':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAchievementFormPage(provinceId: provinceId)));
        break;
      case 'media':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminMediaFormPage(provinceId: provinceId)));
        break;
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Module en cours de développement'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _adminCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
