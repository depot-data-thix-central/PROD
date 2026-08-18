import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Ajout de l'import

class ShopStatistics extends StatefulWidget {
  final String shopId;

  const ShopStatistics({super.key, required this.shopId});

  @override
  State<ShopStatistics> createState() => _ShopStatisticsState();
}

class _ShopStatisticsState extends State<ShopStatistics> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _period = 'week'; // week, month, year

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client
          .rpc('get_shop_statistics', params: {
            'shop_id': widget.shopId,
            'period': _period,
          });
      
      setState(() {
        _stats = Map<String, dynamic>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Période selector
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildPeriodButton('Semaine', 'week'),
              const SizedBox(width: 8),
              _buildPeriodButton('Mois', 'month'),
              const SizedBox(width: 8),
              _buildPeriodButton('Année', 'year'),
            ],
          ),
          const SizedBox(height: 16),
          
          // KPIs
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                'Ventes',
                '${_stats['total_sales'] ?? 0}',
                Icons.shopping_bag,
                Colors.green,
                '+${_stats['sales_growth'] ?? 0}%',
              ),
              _buildStatCard(
                'Chiffre d\'affaires',
                '${_formatNumber(_stats['revenue'] ?? 0)} FCFA',
                Icons.attach_money,
                Colors.blue,
                '+${_stats['revenue_growth'] ?? 0}%',
              ),
              _buildStatCard(
                'Vues',
                _formatNumber(_stats['total_views'] ?? 0),
                Icons.visibility,
                Colors.purple,
                '+${_stats['views_growth'] ?? 0}%',
              ),
              _buildStatCard(
                'Conversion',
                '${_stats['conversion_rate']?.toStringAsFixed(1) ?? 0}%',
                Icons.percent,
                Colors.orange,
                null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Graphique des ventes
          const Text(
            'Évolution des ventes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _buildSalesChart(),
          ),
          const SizedBox(height: 24),
          
          // Top produits
          const Text(
            'Meilleures ventes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...(_stats['top_products'] as List? ?? []).map((product) => _buildTopProductTile(product)),
          const SizedBox(height: 24),
          
          // Activity timeline
          const Text(
            'Activité récente',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...(_stats['recent_activity'] as List? ?? []).map((activity) => _buildActivityTile(activity)),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _period == period;
    return ElevatedButton(
      onPressed: () {
        setState(() => _period = period);
        _loadStatistics();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFE5592F) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(label),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String? growth) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
                if (growth != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward, size: 10, color: Colors.green),
                        const SizedBox(width: 2),
                        Text(
                          growth,
                          style: const TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    final salesData = _stats['sales_data'] as List? ?? [];
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (salesData.isNotEmpty && value.toInt() < salesData.length) {
                  return Text(
                    salesData[value.toInt()]['label'],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(salesData.length, (index) {
              return FlSpot(
                index.toDouble(),
                (salesData[index]['value'] ?? 0).toDouble(),
              );
            }),
            isCurved: true,
            color: const Color(0xFFE5592F),
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFE5592F).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductTile(Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage( // ✅ Correction : CachedNetworkImage (pas CachedNetworklmage)
            imageUrl: product['image_url'],
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 50,
              height: 50,
              color: Colors.grey[200],
              child: const Icon(Icons.image, size: 24),
            ),
          ),
        ),
        title: Text(product['name']),
        subtitle: Text('${product['sales_count']} ventes'),
        trailing: Text(
          '${product['revenue']?.toInt() ?? 0} FCFA',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5592F)),
        ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActivityColor(activity['type']).withOpacity(0.1),
          child: Icon(_getActivityIcon(activity['type']), color: _getActivityColor(activity['type'])),
        ),
        title: Text(activity['message']),
        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(activity['created_at']))),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'sale': return Icons.shopping_bag;
      case 'view': return Icons.visibility;
      case 'follow': return Icons.favorite;
      case 'review': return Icons.star;
      default: return Icons.notifications;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'sale': return Colors.green;
      case 'view': return Colors.blue;
      case 'follow': return Colors.red;
      case 'review': return Colors.amber;
      default: return Colors.grey;
    }
  }

  String _formatNumber(num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toString();
  }
}
