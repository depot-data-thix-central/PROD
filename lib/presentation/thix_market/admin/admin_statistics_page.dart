import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_provider.dart';

class AdminStatisticsPage extends StatefulWidget {
  const AdminStatisticsPage({super.key});

  @override
  State<AdminStatisticsPage> createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage> {
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: _period,
            items: const [
              DropdownMenuItem(value: 'week', child: Text('Semaine')),
              DropdownMenuItem(value: 'month', child: Text('Mois')),
              DropdownMenuItem(value: 'year', child: Text('Année')),
            ],
            onChanged: (value) => setState(() => _period = value!),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Revenus par période', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(height: 250, child: _buildRevenueChart()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Top catégories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ..._buildTopCategories(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Taux de conversion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: 0.032, backgroundColor: Colors.grey[200], color: const Color(0xFFE5592F)),
                    const SizedBox(height: 8),
                    const Text('3.2% des visiteurs achètent'),
                  ],
                ),
              ),
            ),
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
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][value.toInt() % 7]))),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(7, (i) => FlSpot(i.toDouble(), (5000 + i * 800).toDouble())),
            isCurved: true,
            color: const Color(0xFFE5592F),
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: const Color(0xFFE5592F).withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopCategories() {
    return [
      _buildCategoryRow('Mode', 45),
      _buildCategoryRow('Électronique', 28),
      _buildCategoryRow('Maison', 15),
      _buildCategoryRow('Beauté', 8),
      _buildCategoryRow('Autres', 4),
    ];
  }

  Widget _buildCategoryRow(String name, int percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(name)),
          Expanded(
            child: LinearProgressIndicator(value: percent / 100, backgroundColor: Colors.grey[200], color: const Color(0xFFE5592F)),
          ),
          const SizedBox(width: 8),
          Text('$percent%'),
        ],
      ),
    );
  }
}
