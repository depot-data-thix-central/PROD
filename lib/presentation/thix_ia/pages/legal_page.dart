// lib/presentation/thix_ia/pages/legal_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../widgets/risk_card.dart';
import '../widgets/fact_card.dart';
import '../providers/project_memory_provider.dart';

class LegalPage extends ConsumerStatefulWidget {
  const LegalPage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends ConsumerState<LegalPage> {
  String _jurisdiction = 'RDC';
  final _disclaimer = "Cette analyse est fournie à titre informatif et ne constitue pas un avis juridique. Consultez un avocat agréé dans votre juridiction pour validation. Sources : Journal Officiel RDC, OHADA, ARCA.";

  Future<void> _startLegal() async {
    await ref.read(analysesProvider.notifier).startLegalAnalysis(jurisdiction: _jurisdiction, sector: 'General');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analyse juridique $_jurisdiction lancée')));
  }

  @override
  Widget build(BuildContext context) {
    final legalAnalyses = ref.watch(analysesByTypeProvider('legal'));
    final legalFacts = ref.watch(projectFactsProvider).where((f) => f.type == 'legal' || f.content.toLowerCase().contains('loi') || f.content.toLowerCase().contains('réglementation')).toList();

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Réglementation & Juridique', style: ThixPolicy.h3Style)),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        children: [
          // Disclaimer obligatoire §15 cahier
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: ThixPolicy.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.warning.withOpacity(0.3))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: ThixPolicy.warning, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(_disclaimer, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.warning, height: 1.3))),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Juridiction', style: ThixPolicy.labelStyle),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _jurisdiction,
                items: ['RDC', 'RW', 'OHADA', 'KE', 'UG'].map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                onChanged: (v) => setState(() => _jurisdiction = v?? 'RDC'),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _startLegal, icon: Icon(Icons.gavel_rounded, color: Colors.white, size: 18), label: Text('Vérifier réglementation'), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.warning))),
            ]),
          ),
          if (legalAnalyses.isEmpty)
            Padding(padding: EdgeInsets.all(24), child: Text('Aucune analyse juridique. Lancez une vérification pour obtenir lois, décrets, autorités compétentes.', style: ThixPolicy.bodySmallStyle))
          else
            ...legalAnalyses.map((a) => RiskCard(title: a.title?? 'Analyse juridique $_jurisdiction', content: a.summary?? '', level: a.confidence> 0.8? 'low' : 'medium', source: 'Journal Officiel $_jurisdiction')),
          if (legalFacts.isNotEmpty)...[
            Padding(padding: EdgeInsets.all(16), child: Text('Textes de référence', style: ThixPolicy.labelStyle)),
          ...legalFacts.map((f) => FactCard(fact: f)),
          ],
        ],
      ),
    );
  }
}
