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
  

  @override
  Widget build(BuildContext context) {
    final strategy = ref.watch(analysesByTypeProvider('strategy'));

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        title: Text('Stratégie & Go-to-Market', style: ThixPolicy.h3Style)
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stratégie complète', style: ThixPolicy.h3Style),
              const SizedBox(height: 8),
              Text('SWOT, 5 Forces Porter, Go-to-Market, Roadmap 12 mois', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton.icon(
                  onPressed: _startStrategy, 
                  icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18), 
                  label: const Text('Générer stratégie'), 
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary)
                )
              ),
            ]),
          ),
          if (strategy.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24), 
              child: Text('Aucune stratégie. Lancez une analyse pour obtenir SWOT, opportunités, risques, roadmap.', style: ThixPolicy.bodySmallStyle)
            )
          else ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Analyses stratégiques', style: ThixPolicy.labelStyle)),
            ...strategy.map((a) => InsightCard(title: a.title ?? 'Stratégie', content: a.summary ?? '', confidence: a.confidence, type: 'strategy')),
            Padding(padding: const EdgeInsets.all(16), child: Text('Opportunités', style: ThixPolicy.labelStyle)),
            const OpportunityCard(title: 'Marché émergent RDC', description: 'Croissance 12% AgriTech Kinshasa, faible concurrence digitale', impact: 'high', source: 'Banque Mondiale 2024'),
            Padding(padding: const EdgeInsets.all(16), child: Text('Risques', style: ThixPolicy.labelStyle)),
            const RiskCard(title: 'Logistique dernier km', content: 'Routes dégradées, coûts transport +30%', level: 'high', source: 'INS RDC'),
          ],
        ],
      ),
    );
  }
}
