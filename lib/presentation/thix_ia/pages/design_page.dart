// lib/presentation/thix_ia/pages/design_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../providers/document_provider.dart';
import '../widgets/empty_state_widget.dart';

class DesignPage extends ConsumerStatefulWidget {
  const DesignPage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<DesignPage> createState() => _DesignPageState();
}

class _DesignPageState extends ConsumerState<DesignPage> {
  Future<void> _startDesign() async {
    // CORRECTION ICI : Ajout des paramètres nommés requis
    await ref.read(analysesProvider.notifier).startFinanceAnalysis(
          projectCode: widget.projectCode,
          financialInputs: {
            'type': 'design', 
            'deliverables': ['wireframes', 'user_flow', 'ui_guidelines']
          },
        );
        
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyse Design UX/UI lancée'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final designAnalyses = ref.watch(analysesByTypeProvider('design'));
    final docs = ref.watch(documentsProvider).value ?? [];

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Design & Prototype', style: ThixPolicy.h3Style)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Design System & Prototype', style: ThixPolicy.h3Style),
              const SizedBox(height: 8),
              Text('Wireframes, user flows, UI kit ThixPolicy, Figma-ready', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton.icon(
                  onPressed: _startDesign, 
                  icon: const Icon(Icons.design_services_rounded, color: Colors.white, size: 18), 
                  label: const Text('Générer design system'), 
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary)
                )
              ),
            ]),
          ),
          if (docs.any((d) => d.fileName.contains('figma') || d.fileName.contains('design') || d.fileType.contains('image'))) ...[
            Padding(padding: const EdgeInsets.all(16), child: Text('Fichiers design importés', style: ThixPolicy.labelStyle)),
            ...docs.where((d) => d.fileType.contains('image') || d.fileName.contains('figma')).map((d) => ListTile(
              leading: const Icon(Icons.image_rounded, color: ThixPolicy.primary), 
              title: Text(d.fileName), 
              subtitle: Text('${d.status.name} • ${d.chunksCount} chunks')
            )),
          ],
          if (designAnalyses.isEmpty)
            EmptyStateWidget(
              icon: Icons.design_services_outlined, 
              title: 'Aucun design', 
              subtitle: 'Générez wireframes, user flows et recommandations UI/UX basées sur ThixPolicy.', 
              actionLabel: 'Générer design', 
              onAction: _startDesign
            )
          else
            ...designAnalyses.map((a) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
              padding: const EdgeInsets.all(16), 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)), 
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title ?? 'Design Analysis', style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)), 
                const SizedBox(height: 8), 
                Text(a.summary ?? '', style: ThixPolicy.bodySmallStyle)
              ])
            )),
        ],
      ),
    );
  }
}
