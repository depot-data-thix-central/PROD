// lib/presentation/thix_ia/pages/business_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../providers/project_memory_provider.dart';
import '../widgets/fact_card.dart';
import '../widgets/insight_card.dart';

class BusinessPage extends ConsumerWidget {
  const BusinessPage({super.key, required this.projectCode});
  final String projectCode;

  // Petit nettoyeur pour s'assurer que la carte de prévisualisation n'affiche jamais de code JSON
  String _cleanSummary(String? raw) {
    if (raw == null || raw.isEmpty) return 'Analyse en cours...';
    String text = raw.trim();
    if (text.startsWith('{')) {
      // Nettoyage agressif des caractères JSON pour faire un résumé lisible
      text = text.replaceAll(RegExp(r'["{}\[\]_]'), ' ').replaceAll(':', ' - ').trim();
      return text.length > 120 ? '${text.substring(0, 120)}...' : text;
    }
    return text;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAnalyses = ref.watch(analysesByTypeProvider('business_plan'));
    final memory = ref.watch(projectMemoryProvider).value;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        title: Text('Business Model & Plan', style: ThixPolicy.h3Style)
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Business Model Canvas', style: ThixPolicy.h3Style),
              const SizedBox(height: 12),
              if (memory != null) ...[
                _CanvasRow(label: 'Problème', value: memory.context.problem ?? 'Non défini'),
                _CanvasRow(label: 'Proposition de valeur', value: memory.context.valueProposition ?? 'Non défini'),
                _CanvasRow(label: 'Clients cibles', value: memory.context.targetCustomers.isEmpty ? 'Non défini' : memory.context.targetCustomers.join(', ')),
                const _CanvasRow(label: 'Canaux', value: 'Non défini'), 
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final idea = memory?.context.valueProposition ?? 'Générer un business plan complet pour ce projet';
                    await ref.read(analysesProvider.notifier).startBusinessPlanAnalysis(
                          ideaDescription: idea,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Génération du Business Plan lancée !')),
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  label: const Text('Générer Business Plan complet'),
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
                ),
              ),
            ]),
          ),
          if (businessAnalyses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24), 
              child: Text('Aucun business plan généré. Complétez votre mémoire projet puis générez.', style: ThixPolicy.bodySmallStyle)
            )
          else
           ...businessAnalyses.map((a) => InsightCard(
             title: a.title ?? 'Business Plan', 
             // 👇 On utilise le nettoyeur ici pour le résumé de la carte
             content: _cleanSummary(a.summary), 
             confidence: a.confidence, 
             type: 'business'
           )),
          if (memory != null && memory.facts.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.all(16), child: Text('Faits business', style: ThixPolicy.labelStyle)),
           ...memory.facts.where((f) => f.type == 'fact').take(5).map((f) => FactCard(fact: f)),
          ],
        ],
      ),
    );
  }
}

class _CanvasRow extends StatelessWidget {
  const _CanvasRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(label, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold))),
        Expanded(child: Text(value, style: ThixPolicy.bodySmallStyle)),
      ]),
    );
  }
}
