import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../core/utils/execution_utils.dart';

class ExecutionPage extends ConsumerWidget {
  const ExecutionPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(executionDashboardProvider(projectCode));
    final tasksStream = ref.watch(executionTasksProvider(projectCode));
    final goalsAsync = ref.watch(executionGoalsProvider(projectCode));
    final suppliersAsync = ref.watch(executionSuppliersProvider(projectCode));
    final roadmapAsync = ref.watch(executionRoadmapProvider(projectCode));
    final financeAsync = ref.watch(executionFinanceProvider(projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: Text(projectCode, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      body: dashboardAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Center(child: Text('Erreur: $e')),
        data: (dash){
          final health = dash['health'];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(executionDashboardProvider),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              // FINANCIAL ENGINE
              _FinancialEngineCard(financeAsync: financeAsync, treasury: health?.treasury ?? 0, burnRate: health?.burnRate ?? 0, runway: health?.runwayMonths ?? 0),
              const SizedBox(height: 16),
              // OKR
              _OkrsSection(goalsAsync: goalsAsync),
              const SizedBox(height: 16),
              // ROADMAP
              _RoadmapSection(roadmapAsync: roadmapAsync),
              const SizedBox(height: 16),
              // FOURNISSEURS
              _SuppliersSection(suppliersAsync: suppliersAsync),
              const SizedBox(height: 16),
              // AUTO-KANBAN RÉEL
              _AutoKanbanSection(tasksAsync: tasksStream, projectCode: projectCode),
            ]),
          );
        },
      ),
    );
  }
}

class _FinancialEngineCard extends StatelessWidget {
  const _FinancialEngineCard({required this.financeAsync, required this.treasury, required this.burnRate, required this.runway});
  final AsyncValue financeAsync; final double treasury; final double burnRate; final double runway;
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Financial Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton.icon(onPressed: (){}, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter transaction'))]),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Trésorerie actuelle', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text(ExecutionUtils.formatCurrency(treasury), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          ]),
          const Spacer(),
          const Icon(Icons.trending_up, color: Colors.green),
          const Text(' 12.5%\nvs mois dernier', style: TextStyle(fontSize: 10, color: Colors.green)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _MiniKpi(icon: Icons.local_fire_department, label: 'Burn Rate', value: '\$ ${burnRate.toStringAsFixed(0)} /mo'),
          _MiniKpi(icon: Icons.flight, label: 'Runway', value: '${runway.toStringAsFixed(0)} Mois'),
          financeAsync.when(data: (s)=> _MiniKpi(icon: Icons.trending_up, label: 'MRR', value: '\$ ${s?.mrr ?? 0} /mo'), loading: ()=> const SizedBox(), error: (_,__)=> const SizedBox()),
        ])
      ]),
    );
  }
}
class _MiniKpi extends StatelessWidget { const _MiniKpi({required this.icon, required this.label, required this.value}); final IconData icon; final String label; final String value; @override Widget build(BuildContext context)=> Row(children: [Icon(icon, size: 18), const SizedBox(width: 6), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])]); }

class _OkrsSection extends StatelessWidget {
  const _OkrsSection({required this.goalsAsync}); final AsyncValue goalsAsync;
  @override Widget build(BuildContext context) {
    return goalsAsync.when(
      loading: ()=> const CircularProgressIndicator(),
      error: (_,__)=> const SizedBox(),
      data: (goals)=> Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Objectifs Stratégiques (OKRs)', style: TextStyle(fontWeight: FontWeight.bold)), TextButton(onPressed: (){}, child: const Text('Voir tout'))]),
        const SizedBox(height: 8),
        SizedBox(height: 90, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: goals.length, separatorBuilder: (_,__)=> const SizedBox(width: 12), itemBuilder: (c,i){
          final g = goals[i];
          return Container(width: 220, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('${g.current.toInt()} / ${g.target.toInt()} ${g.unit}', style: const TextStyle(fontSize: 11)), const Spacer(), LinearProgressIndicator(value: g.progress/100, minHeight: 6), Text('${g.progress.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10))]));
        }))
      ]),
    );
  }
}

class _RoadmapSection extends StatelessWidget {
  const _RoadmapSection({required this.roadmapAsync}); final AsyncValue roadmapAsync;
  @override Widget build(BuildContext context)=> roadmapAsync.when(
    loading: ()=> const SizedBox(), error: (_,__)=> const SizedBox(),
    data: (steps)=> Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Roadmap de Lancement', style: TextStyle(fontWeight: FontWeight.bold)), TextButton(onPressed: (){}, child: const Text('Voir tout'))]), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: steps.map((s)=> Column(children: [CircleAvatar(backgroundColor: s['status']=='done'? Colors.green : Colors.blue, child: Text(s['order_index'].toString(), style: const TextStyle(color: Colors.white))), const SizedBox(height: 6), SizedBox(width: 70, child: Text(s['title'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 9)))] )).toList())])),
  );
}

class _SuppliersSection extends StatelessWidget {
  const _SuppliersSection({required this.suppliersAsync}); final AsyncValue suppliersAsync;
  @override Widget build(BuildContext context)=> suppliersAsync.when(
    loading: ()=> const SizedBox(), error: (_,__)=> const SizedBox(),
    data: (suppliers)=> Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: suppliers.take(3).map((s)=> ListTile(leading: const Icon(Icons.business), title: Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text(s.category, style: const TextStyle(fontSize: 10)), trailing: Chip(label: Text(s.status, style: const TextStyle(fontSize: 9))))).toList())),
  );
}

class _AutoKanbanSection extends ConsumerWidget {
  const _AutoKanbanSection({required this.tasksAsync, required this.projectCode});
  final AsyncValue tasksAsync; final String projectCode;
  @override Widget build(BuildContext context, WidgetRef ref) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Auto-Kanban', style: TextStyle(fontWeight: FontWeight.bold)), ElevatedButton.icon(onPressed: () async { await ref.read(executionAiServiceProvider).autoGenerateTasksFromObjective(projectCode, 'Lancement'); }, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter tâche', style: TextStyle(fontSize: 11)))]),
      const Text('Tâches générées par l\'IA', style: TextStyle(fontSize: 10, color: Colors.grey)),
      const SizedBox(height: 8),
      tasksAsync.when(
        loading: ()=> const CircularProgressIndicator(),
        error: (e,s)=> Text('Erreur: $e'),
        data: (tasks)=> Column(children: tasks.take(5).map((t)=> CheckboxListTile(value: t.status=='done', onChanged: (v) async { if(v==true) await ref.read(executionRepositoryProvider).completeTask(t.id); }, title: Text(t.title, style: TextStyle(fontSize: 12, decoration: t.status=='done'? TextDecoration.lineThrough : null)), secondary: Chip(label: Text(t.category, style: const TextStyle(fontSize: 9))), controlAffinity: ListTileControlAffinity.leading)).toList()),
      )
    ]));
  }
}
