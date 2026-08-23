// lib/presentation/thix_ia/pages/research_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../providers/project_memory_provider.dart';
import '../widgets/fact_card.dart';
import '../widgets/source_card.dart';

class ResearchPage extends ConsumerStatefulWidget {
  const ResearchPage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends ConsumerState<ResearchPage> {
  final _queryController = TextEditingController();

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    await ref.read(analysesProvider.notifier).startMarketAnalysis(country: 'RDC', sector: q);
    if (mounted) {
      _queryController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recherche "$q" lancée')));
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facts = ref.watch(projectFactsProvider);
    final verified = ref.watch(verifiedFactsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Research & Sources', style: ThixPolicy.h3Style)),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _queryController, onSubmitted: (_) => _search(), decoration: InputDecoration(hintText: 'Rechercher marché, loi, concurrent...', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
                SizedBox(width: 8),
                Container(decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(12)), child: IconButton(onPressed: _search, icon: Icon(Icons.arrow_upward_rounded, color: Colors.white))),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(16), child: Row(children: [Icon(Icons.verified_rounded, size: 16, color: ThixPolicy.success), SizedBox(width: 6), Text('${verified.length} faits vérifiés sur ${facts.length}', style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold))])),
          Expanded(
            child: facts.isEmpty
             ? Center(child: Text('Aucune recherche. Lancez une recherche pour collecter sources officielles.', style: ThixPolicy.bodySmallStyle))
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: 24),
                  itemCount: facts.length,
                  itemBuilder: (_, i) {
                    final f = facts[i];
                    return Column(children: [FactCard(fact: f), if (f.sourceName!= null) SourceCard(name: f.sourceName!, url: f.sourceUrl, type: f.type, confidence: f.confidence)]);
                  },
                ),
          ),
        ],
      ),
    );
  }
}
