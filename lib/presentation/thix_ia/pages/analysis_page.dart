// lib/presentation/thix_ia/pages/analysis_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../widgets/analysis_progress_widget.dart';
import '../widgets/empty_state_widget.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analysesProvider.notifier).refresh());
  }

  Future<void> _startMarket() async {
    await ref.read(analysesProvider.notifier).startMarketAnalysis(
          projectCode: widget.projectCode, // AJOUT OBLIGATOIRE
          country: 'RDC',
          sector: 'AgriTech',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Étude de marché lancée')),
      );
    }
  }

  Future<void> _startLegal() async {
    await ref.read(analysesProvider.notifier).startLegalAnalysis(
          projectCode: widget.projectCode, // AJOUT OBLIGATOIRE
          jurisdiction: 'RDC',
          sector: 'AgriTech',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyse légale lancée')),
      );
    }
  }

  Future<void> _startFinance() async {
    await ref.read(analysesProvider.notifier).startFinanceAnalysis(
          projectCode: widget.projectCode, // AJOUT OBLIGATOIRE
          financialInputs: {
            'initial_investment': 50000,
            'monthly_revenue': 10000
          }, // PARAMÈTRE NOMMÉ CORRIGÉ
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyse financière lancée')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysesAsync = ref.watch(analysesProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Analyses IA', style: ThixPolicy.h3Style),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lancer une analyse', style: ThixPolicy.labelStyle),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.trending_up_rounded,
                        label: 'Marché',
                        color: ThixPolicy.info,
                        onTap: _startMarket,
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.gavel_rounded,
                        label: 'Légal',
                        color: ThixPolicy.warning,
                        onTap: _startLegal,
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.calculate_rounded,
                        label: 'Finance',
                        color: ThixPolicy.success,
                        onTap: _startFinance,
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.people_rounded,
                        label: 'Concurrence',
                        color: ThixPolicy.primary,
                        onTap: () => ref.read(analysesProvider.notifier).startCompetitorAnalysis(
                              projectCode: widget.projectCode, // AJOUT OBLIGATOIRE
                              country: 'RDC',
                              sector: 'Général',
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: analysesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur $e')),
              data: (analyses) {
                if (analyses.isEmpty) return EmptyAnalyses(onStart: _startMarket);
                return RefreshIndicator(
                  onRefresh: () => ref.read(analysesProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: analyses.length,
                    itemBuilder: (_, i) => AnalysisProgressWidget(
                      analysis: analyses[i],
                      onRetry: () => _startMarket(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: color,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
