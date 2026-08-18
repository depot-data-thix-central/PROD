import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GlobalStatsChart extends StatefulWidget {
  final String userId;
  final String type; // 'sales' ou 'purchases'

  const GlobalStatsChart({super.key, required this.userId, required this.type});

  @override
  State<GlobalStatsChart> createState() => _GlobalStatsChartState();
}

class _GlobalStatsChartState extends State<GlobalStatsChart> {
  List<FlSpot> _spots = [];
  List<String> _labels = [];
  bool _isLoading = true;
  String _period = 'week'; // week, month, year
  double _total = 0;
  double _growth = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .rpc('get_user_stats', params: {
            'user_id': widget.userId,
            'type': widget.type,
            'period': _period,
          });
      
      final data = response as Map<String, dynamic>;
      final series = List<Map<String, dynamic>>.from(data['series'] ?? []);
      
      setState(() {
        _spots = List.generate(series.length, (i) => FlSpot(i.toDouble(), (series[i]['value'] ?? 0).toDouble()));
        _labels = series.map((e) => e['label'] as String).toList();
        _total = data['total']?.toDouble() ?? 0;
        _growth = data['growth']?.toDouble() ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatTotal() {
    if (_total >= 1000000) return '${(_total / 1000000).toStringAsFixed(1)}M FCFA';
    if (_total >= 1000) return '${(_total / 1000).toStringAsFixed(1)}k FCFA';
    return '${_total.toInt()} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.type == 'sales' ? 'Chiffre d\'affaires' : 'Dépenses',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    _buildPeriodChip('Semaine', 'week'),
                    const SizedBox(width: 4),
                    _buildPeriodChip('Mois', 'month'),
                    const SizedBox(width: 4),
                    _buildPeriodChip('Année', 'year'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Total
            Row(
              children: [
                Text(
                  _formatTotal(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE5592F)),
                ),
                const SizedBox(width: 8),
                if (_growth != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _growth > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(_growth > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: _growth > 0 ? Colors.green : Colors.red),
                        const SizedBox(width: 2),
                        Text(
                          '${_growth.abs().toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, color: _growth > 0 ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Graphique
            if (_isLoading)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            else if (_spots.isEmpty)
              const SizedBox(height: 200, child: Center(child: Text('Aucune donnée')))
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        }),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < _labels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_labels[index], style: const TextStyle(fontSize: 10)),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 30,
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _spots,
                        isCurved: true,
                        color: const Color(0xFFE5592F),
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: const Color(0xFFE5592F).withOpacity(0.1)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String period) {
    final isSelected = _period == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _period = period;
          _loadStats();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5592F) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
        ),
      ),
    );
  }
}
