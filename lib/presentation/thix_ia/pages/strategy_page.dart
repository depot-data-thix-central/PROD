// lib/presentation/thix_ia/pages/strategy_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../widgets/opportunity_card.dart';
import '../widgets/risk_card.dart';
import '../widgets/insight_card.dart';

class StrategyPage extends ConsumerStatefulWidget {
  const StrategyPage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends ConsumerState<StrategyPage> {
  Future<void> _startStrategy() async {
    await ref.read(analysesProvider.notifier).startFinanceAnalysis({'type': 'strategy', 'framework': 'SWOT + Porter + Lean Canvas'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analyse stratégique lancée (SWOT, Porter, Go-to-Market)')));
  }

  @override
  Widget build(BuildContext context) {
    final strategy = ref.watch(analysesByTypeProvider('strategy'));

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Stratégie & Go-to-Market', style: ThixPolicy.h3Style)),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stratégie complète', style: ThixPolicy.h3Style),
              SizedBox(height: 8),
              Text('SWOT, 5 Forces Porter, Go-to-Market, Roadmap 12 mois', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
              SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _startStrategy, icon: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18), label: Text('Générer stratégie'), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary))),
            ]),
          ),
          if (strategy.isEmpty)
            Padding(padding: EdgeInsets.all(24), child: Text('Aucune stratégie. Lancez une analyse pour obtenir SWOT, opportunités, risques, roadmap.', style: ThixPolicy.bodySmallStyle))
          else...[
            Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Analyses stratégiques', style: ThixPolicy.labelStyle)),
         ...strategy.map((a) => InsightCard(title: a.title?? 'Stratégie', content: a.summary?? '', confidence: a.confidence, type: 'strategy')),
            Padding(padding: EdgeInsets.all(16), child: Text('Opportunités', style: ThixPolicy.labelStyle)),
            OpportunityCard(title: 'Marché émergent RDC', description: 'Croissance 12% AgriTech Kinshasa, faible concurrence digitale', impact: 'high', source: 'Banque Mondiale 2024'),
            Padding(padding: EdgeInsets.all(16), child: Text('Risques', style: ThixPolicy.labelStyle)),
            RiskCard(title: 'Logistique dernier km', content: 'Routes dégradées, coûts transport +30%', level: 'high', source: 'INS RDC'),
          ],
        ],
      ),
    );
  }
}
