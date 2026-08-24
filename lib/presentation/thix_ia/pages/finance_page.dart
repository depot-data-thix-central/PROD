// lib/presentation/thix_ia/pages/finance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/analysis_provider.dart';
import '../widgets/insight_card.dart';

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  final _investmentController = TextEditingController(text: '50000');
  final _revenueController = TextEditingController(text: '10000');
  final _costController = TextEditingController(text: '6000');
  final _growthController = TextEditingController(text: '15');

  @override
  void dispose() {
    _investmentController.dispose();
    _revenueController.dispose();
    _costController.dispose();
    _growthController.dispose();
    super.dispose();
  }

  // 👇 LA MÉTHODE _startFinance ÉTAIT MANQUANTE DANS TON EXTRAIT
  Future<void> _startFinance() async {
    final inputs = {
      'initial_investment': double.tryParse(_investmentController.text) ?? 50000,
      'monthly_revenue': double.tryParse(_revenueController.text) ?? 10000,
      'monthly_cost': double.tryParse(_costController.text) ?? 6000,
      'growth_rate': double.tryParse(_growthController.text) ?? 15,
      'deterministic': true,
    };

    // Appel avec le paramètre 'inputs:' correct attendu par le Notifier
    await ref.read(analysesProvider.notifier).startFinanceAnalysis(
          inputs: inputs,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modèle financier lancé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeAnalyses = ref.watch(analysesByTypeProvider('finance'));

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Modèle Financier', style: ThixPolicy.h3Style)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Paramètres financiers', style: ThixPolicy.labelStyle),
              const SizedBox(height: 12),
              _Field(controller: _investmentController, label: 'Investissement initial (USD)', icon: Icons.attach_money_rounded),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _Field(controller: _revenueController, label: 'Revenu mensuel')), const SizedBox(width: 12), Expanded(child: _Field(controller: _costController, label: 'Coût mensuel'))]),
              const SizedBox(height: 12),
              _Field(controller: _growthController, label: 'Croissance mensuelle %'),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ThixPolicy.info.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.info_outline_rounded, size: 16, color: ThixPolicy.info), const SizedBox(width: 8), Expanded(child: Text('Calculs déterministes côté backend Python (NPV, IRR, Break-even). Scénarios base/optimiste/pessimiste.', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.info)))])),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _startFinance, icon: const Icon(Icons.calculate_rounded, color: Colors.white), label: const Text('Calculer modèle financier'), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.success))),
            ]),
          ),
          if (financeAnalyses.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('Aucun modèle financier. Entrez vos paramètres pour générer prévisionnel 3 ans.', style: TextStyle(fontSize: 14)))
          else
           ...financeAnalyses.map((a) => InsightCard(title: a.title ?? 'Modèle financier', content: a.summary ?? 'Calculs en cours...', confidence: a.confidence, type: 'finance')),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.icon});
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
