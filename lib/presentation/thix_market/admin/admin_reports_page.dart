import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rapports'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportCard(
            title: 'Rapport des ventes',
            description: 'Exportez les détails des ventes par période',
            icon: Icons.receipt,
            onGenerate: () {},
          ),
          _buildReportCard(
            title: 'Rapport des utilisateurs',
            description: 'Exportez la liste des utilisateurs inscrits',
            icon: Icons.people,
            onGenerate: () {},
          ),
          _buildReportCard(
            title: 'Rapport des produits',
            description: 'Exportez l\'inventaire des produits',
            icon: Icons.inventory,
            onGenerate: () {},
          ),
          _buildReportCard(
            title: 'Rapport des boutiques',
            description: 'Exportez les informations des boutiques',
            icon: Icons.store,
            onGenerate: () {},
          ),
          _buildReportCard(
            title: 'Rapport financier',
            description: 'Exportez les transactions financières',
            icon: Icons.attach_money,
            onGenerate: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onGenerate,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32, color: const Color(0xFFE5592F)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: ElevatedButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.download),
          label: const Text('Générer'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5592F)),
        ),
      ),
    );
  }
}
