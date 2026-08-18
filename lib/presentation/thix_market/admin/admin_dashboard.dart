import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = provider.dashboardStats;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // KPIs
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    _buildKpiCard('Utilisateurs', stats.totalUsers, Icons.people, Colors.blue),
                    _buildKpiCard('Boutiques', stats.totalShops, Icons.store, Colors.purple),
                    _buildKpiCard('Produits', stats.totalProducts, Icons.inventory, Colors.orange),
                    _buildKpiCard('Commandes', stats.totalOrders, Icons.shopping_bag, Colors.green),
                    _buildKpiCard('CA total', '${stats.totalRevenue.toInt()} FCFA', Icons.attach_money, Colors.indigo),
                    _buildKpiCard('CA mensuel', '${stats.thisMonthRevenue.toInt()} FCFA', Icons.trending_up, Colors.teal,
                        growth: stats.revenueGrowth),
                  ],
                ),
                const SizedBox(height: 24),
                // Graphique revenus
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Évolution des revenus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(height: 200, child: _buildRevenueChart()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Commandes récentes
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Commandes récentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            TextButton(onPressed: () {}, child: const Text('Voir tout')),
                          ],
                        ),
                        ...provider.recentOrders.take(5).map((order) => ListTile(
                          leading: const Icon(Icons.shopping_bag),
                          title: Text('Commande #${order['id']}'),
                          subtitle: Text(order['user']?['name'] ?? 'Client'),
                          trailing: Text('${order['total']?.toInt()} FCFA'),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Activités récentes
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Activités récentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...provider.recentActivities.map((activity) => ListTile(
                          leading: Icon(_getActivityIcon(activity['type']), color: _getActivityColor(activity['type'])),
                          title: Text(activity['description']),
                          subtitle: Text(activity['admin']?['name'] ?? 'Admin'),
                          trailing: Text(_formatDate(activity['created_at'])),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String title, dynamic value, IconData icon, Color color, {double? growth}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (growth != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: growth >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(growth >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: growth >= 0 ? Colors.green : Colors.red),
                        const SizedBox(width: 2),
                        Text('${growth.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: growth >= 0 ? Colors.green : Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey[600])),
            Text(value is int ? value.toString() : value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin'][value.toInt() % 6]))),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(6, (i) => FlSpot(i.toDouble(), (1000 + i * 500).toDouble())),
            isCurved: true,
            color: const Color(0xFFE5592F),
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: const Color(0xFFE5592F).withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'product': return Icons.inventory;
      case 'shop': return Icons.store;
      case 'user': return Icons.person;
      default: return Icons.notifications;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'product': return Colors.orange;
      case 'shop': return Colors.purple;
      case 'user': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month} ${date.hour}:${date.minute}';
  }
}
