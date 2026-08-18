
import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const List<Map<String, dynamic>> menuItems = [
    {'icon': Icons.dashboard, 'label': 'Tableau de bord', 'route': '/admin'},
    {'icon': Icons.inventory, 'label': 'Produits', 'route': '/admin/products'},
    {'icon': Icons.store, 'label': 'Boutiques', 'route': '/admin/shops'},
    {'icon': Icons.people, 'label': 'Utilisateurs', 'route': '/admin/users'},
    {'icon': Icons.shopping_bag, 'label': 'Commandes', 'route': '/admin/orders'},
    {'icon': Icons.gavel, 'label': 'Litiges', 'route': '/admin/disputes'},
    {'icon': Icons.local_offer, 'label': 'Promotions', 'route': '/admin/promotions'},
    {'icon': Icons.bar_chart, 'label': 'Statistiques', 'route': '/admin/statistics'},
    {'icon': Icons.description, 'label': 'Rapports', 'route': '/admin/reports'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        children: [
          // Logo / En-tête
          Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5592F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'THIX Admin',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
          // Menu
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = selectedIndex == index;
                return ListTile(
                  leading: Icon(
                    item['icon'],
                    color: isSelected ? const Color(0xFFE5592F) : Colors.grey[600],
                  ),
                  title: Text(
                    item['label'],
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFE5592F) : Colors.grey[800],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFFE5592F).withOpacity(0.05),
                  onTap: () {
                    onItemSelected(index);
                    Navigator.pushReplacementNamed(context, item['route']);
                  },
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE5592F),
                  child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Déconnexion',
                        style: TextStyle(fontSize: 12, color: Colors.red[400]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 18),
                  onPressed: () {
                    // Logique de déconnexion
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
