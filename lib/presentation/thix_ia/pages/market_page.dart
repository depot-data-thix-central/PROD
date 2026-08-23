// lib/presentation/thix_ia/pages/market_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../providers/project_memory_provider.dart';
import '../widgets/fact_card.dart';
import '../widgets/insight_card.dart';

class MarketPage extends ConsumerWidget {
  const MarketPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketAnalyses = ref.watch(analysesByTypeProvider('market'));
    final facts = ref.watch(projectFactsProvider).where((f) => f.content.toLowerCase().contains('marché') || f.content.toLowerCase().contains('market')).toList();

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Étude de Marché', style: ThixPolicy.h3Style)),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Analyse marché RDC & Afrique', style: ThixPolicy.h3Style),
              SizedBox(height: 8),
              Text('Taille marché, croissance, acteurs, sources officielles (Banque Mondiale, INS RDC)', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => ref.read(analysesProvider.notifier).startMarketAnalysis(country: 'RDC', sector: 'AgriTech'),
                  icon: Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
                  label: Text('Lancer étude de marché'),
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.info),
                ),
              ),
            ]),
          ),
          if (marketAnalyses.isEmpty)...[
            Padding(padding: EdgeInsets.all(24), child: Text('Aucune étude de marché. Lancez-en une pour obtenir des faits sourcés.', style: ThixPolicy.bodySmallStyle)),
          ] else...[
            Padding(padding: EdgeInsets.all(16), child: Text('Résultats', style: ThixPolicy.labelStyle)),
          ...marketAnalyses.map((a) => InsightCard(title: a.title?? 'Étude de marché', content: a.summary?? 'Analyse en cours...', confidence: a.confidence, type: 'market')),
          ],
          if (facts.isNotEmpty)...[
            Padding(padding: EdgeInsets.all(16), child: Text('Faits marché vérifiés', style: ThixPolicy.labelStyle)),
          ...facts.map((f) => FactCard(fact: f)),
          ],
        ],
      ),
    );
  }
}
