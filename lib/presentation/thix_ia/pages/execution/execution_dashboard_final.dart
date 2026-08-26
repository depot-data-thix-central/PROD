import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../core/utils/execution_utils.dart';
import 'finance_page.dart';
import 'tasks_page.dart';
import 'roadmap_page.dart';
import 'suppliers_page.dart';
import 'risk_page.dart';

class ExecutionDashboardFinal extends ConsumerWidget {
  const ExecutionDashboardFinal({super.key, required this.projectCode, required this.projectName});
  final String projectCode;
  final String projectName;

  @override Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(executionDashboardProvider(projectCode));
    final tasksStream = ref.watch(executionTasksProvider(projectCode));
    final goalsAsync = ref.watch(executionGoalsProvider(projectCode));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true, backgroundColor: Colors.white, elevation: 0,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Bonjour, Lionel 👋', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), Row(children: [Text(projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)), const Icon(Icons.keyboard_arrow_down, size: 18)])]),
            actions: [Stack(children: [IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: (){}), Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Text('3', style: TextStyle(fontSize: 8, color: Colors.white))))], CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=12')))],
          ),
          SliverToBoxAdapter(child: dashAsync.when(
            loading: ()=> const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            error: (e,s)=> Center(child: Text('Erreur $e')),
            data: (dash){
              final health = dash['health'];
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // FINANCIAL ENGINE - EXACT SCREENSHOT
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Financial Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Trésorerie & Burn Rate', style: TextStyle(fontSize: 12, color: Colors.grey))]), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F3FF), foregroundColor: Colors.indigo, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> FinancePage(projectCode: projectCode))), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter transaction', style: TextStyle(fontSize: 11)))]),
                      const SizedBox(height: 18),
                      Row(children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF1F0FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple)),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Trésorerie actuelle', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(ExecutionUtils.formatCurrency(health?.treasury?? 45890.5), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22))]),
                        const Spacer(),
                        Column(children: [Container(width: 80, height: 30, child: CustomPaint(painter: _MiniChartPainter())), const SizedBox(height: 4), const Row(children: [Icon(Icons.arrow_upward, size: 12, color: Colors.green), Text('12.5%', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))]), const Text('vs mois dernier', style: TextStyle(fontSize: 9, color: Colors.grey))]),
                      ]),
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _BottomKpi(icon: Icons.local_fire_department, iconBg: Colors.orange.shade50, iconColor: Colors.orange, label: 'Burn Rate', value: '\$ ${(health?.burnRate?? 2340).toInt()} /mo'),
                        Container(width: 1, height: 30, color: Colors.grey.shade200),
                        _BottomKpi(icon: Icons.flight, iconBg: Colors.green.shade50, iconColor: Colors.green, label: 'Runway', value: '${(health?.runwayMonths?? 19).toInt()} Mois'),
                        Container(width: 1, height: 30, color: Colors.grey.shade200),
                        _BottomKpi(icon: Icons.trending_up, iconBg: Colors.blue.shade50, iconColor: Colors.blue, label: 'MRR', value: '\$ ${(health?.mrr?? 5670).toInt()} /mo'),
                      ])
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // OKR
                  _SectionHeader(title: 'Objectifs Stratégiques (OKRs)', onViewAll: ()=> {}),
                  const SizedBox(height: 8),
                  goalsAsync.when(
                    loading: ()=> const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                    error: (_,__)=> const SizedBox(),
                    data: (goals){
                      if(goals.isEmpty) return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Text('Aucun objectif - ajoutez 500 clients', style: TextStyle(fontSize: 12)));
                      return SizedBox(height: 95, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: goals.length, separatorBuilder: (_,__)=> const SizedBox(width: 12), itemBuilder: (c,i){
                        final g = goals[i];
                        return Container(width: 200, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: i==0? Colors.blue.shade50 : Colors.orange.shade50, shape: BoxShape.circle), child: Icon(i==0? Icons.flag : Icons.inventory_2, size: 16, color: i==0? Colors.blue : Colors.orange)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis), Text('${g.current.toInt()} / ${g.target.toInt()} ${g.unit}', style: TextStyle(fontSize: 11, color: i==0? Colors.blue : Colors.orange, fontWeight: FontWeight.bold))]))]), const Spacer(), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: g.progress/100, minHeight: 6, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(i==0? Colors.blue : Colors.orange))), const SizedBox(height: 4), Text('${g.progress.toInt()}%', style: const TextStyle(fontSize: 10))]));
                      }));
                    },
                  ),
                  const SizedBox(height: 16),
                  // ROADMAP
                  _SectionHeader(title: 'Roadmap de Lancement', onViewAll: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> RoadmapPage(projectCode: projectCode)))),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(4, (i){
                    final titles = ['Business Plan\nValidé','Création Juridique\n& RCCM','Achat & Importation\nÉquipements','Lancement de la\nProduction'];
                    final months = ['Mois 1','Mois 2','Mois 3','Mois 4'];
                    final isDone = i<2; final isCurrent = i==2;
                    return Column(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: isDone? Colors.green.shade100 : isCurrent? Colors.white : Colors.grey.shade100, shape: BoxShape.circle, border: Border.all(color: isDone? Colors.green : isCurrent? Colors.blue : Colors.grey.shade300, width: isCurrent? 2:1)), child: Center(child: isDone? const Icon(Icons.check, size: 18, color: Colors.green) : Text('${i+1}', style: TextStyle(fontWeight: FontWeight.bold, color: isCurrent? Colors.blue : Colors.grey)))), const SizedBox(height: 6), SizedBox(width: 70, child: Text(titles[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: isCurrent? FontWeight.bold : FontWeight.normal))), Text(months[i], style: TextStyle(fontSize: 9, color: isCurrent? Colors.blue : Colors.grey))]);
                  }))),
                  const SizedBox(height: 16),
                  // FOURNISSEURS
                  _SectionHeader(title: 'Fournisseurs & Partenaires', onViewAll: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> SuppliersPage(projectCode: projectCode)))),
                  const SizedBox(height: 8),
                  FutureBuilder(future: ref.read(thixSupabaseProvider).from('thix_execution_suppliers').select().eq('project_code', projectCode).limit(3).then((v)=> v as List), builder: (c,snap){
                    final list = snap.data?? [];
                    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: list.isEmpty? [const ListTile(title: Text('TechMachinery GmbH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text('Équipement', style: TextStyle(fontSize: 10)), trailing: Chip(label: Text('Validé', style: TextStyle(fontSize: 9)), backgroundColor: Color(0xFFE6F9ED)))] : list.map<Widget>((s)=> ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.business, size: 16)), title: Text(s['name'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text(s['category'].toString(), style: const TextStyle(fontSize: 10)), trailing: Chip(label: Text(s['status'].toString(), style: const TextStyle(fontSize: 9)), backgroundColor: s['status']=='Validé'? const Color(0xFFE6F9ED) : Colors.orange.shade50))).toList()));
                  }),
                  const SizedBox(height: 16),
                  // AUTO-KANBAN
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Auto-Kanban', style: TextStyle(fontWeight: FontWeight.bold)), Text('Tâches générées par l\'IA', style: TextStyle(fontSize: 11, color: Colors.grey))]), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F3FF), foregroundColor: Colors.indigo, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> TasksPage(projectCode: projectCode))), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter tâche', style: TextStyle(fontSize: 11)))]),
                      const SizedBox(height: 12),
                      tasksStream.when(
                        loading: ()=> const CircularProgressIndicator(),
                        error: (e,s)=> Text('$e'),
                        data: (tasks){
                          if(tasks.isEmpty) return const Text('Aucune tâche', style: TextStyle(fontSize: 12));
                          return Column(children: tasks.take(3).map((t)=> Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(t.status=='done'? Icons.check_circle : Icons.radio_button_unchecked, color: t.status=='done'? Colors.green : Colors.grey, size: 20), const SizedBox(width: 10), Expanded(child: Text(t.title, style: TextStyle(fontSize: 12, decoration: t.status=='done'? TextDecoration.lineThrough : null))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: t.category=='Légal'? Colors.red.shade50 : t.category=='Finance'? Colors.green.shade50 : Colors.purple.shade50, borderRadius: BorderRadius.circular(6)), child: Text(t.category, style: const TextStyle(fontSize: 9))), const SizedBox(width: 8), const Icon(Icons.auto_awesome, size: 14, color: Colors.indigo), const Text(' IA', style: TextStyle(fontSize: 10, color: Colors.indigo))] ))).toList());
                        },
                      ),
                      Center(child: TextButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> TasksPage(projectCode: projectCode))), child: const Text('Voir toutes les tâches (3)', style: TextStyle(fontSize: 11)))),
                    ]),
                  ),
                  const SizedBox(height: 100),
                ]),
              );
            },
          ))]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _NavItem(icon: Icons.home, label: 'Accueil', active: true, onTap: (){}),
          _NavItem(icon: Icons.pie_chart, label: 'Analyse', onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> RiskPage(projectCode: projectCode)))),
          Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 28)),
          _NavItem(icon: Icons.folder, label: 'Documents', onTap: (){}),
          _NavItem(icon: Icons.settings, label: 'Paramètres', onTap: (){}),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget { const _SectionHeader({required this.title, required this.onViewAll}); final String title; final VoidCallback onViewAll; @override Widget build(BuildContext context)=> Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), TextButton(onPressed: onViewAll, child: const Text('Voir tout', style: TextStyle(fontSize: 11)))]); }
class _BottomKpi extends StatelessWidget { const _BottomKpi({required this.icon, required this.iconBg, required this.iconColor, required this.label, required this.value}); final IconData icon; final Color iconBg; final Color iconColor; final String label; final String value; @override Widget build(BuildContext context)=> Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: iconColor)), const SizedBox(width: 6), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))])]); }
class _NavItem extends StatelessWidget { const _NavItem({required this.icon, required this.label, this.active=false, required this.onTap}); final IconData icon; final String label; final bool active; final VoidCallback onTap; @override Widget build(BuildContext context)=> GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active? Colors.blue : Colors.grey), Text(label, style: TextStyle(fontSize: 10, color: active? Colors.blue : Colors.grey, fontWeight: active? FontWeight.bold : FontWeight.normal))])); }
class _MiniChartPainter extends CustomPainter { @override void paint(Canvas canvas, Size size){ final p = Paint()..color=Colors.green..strokeWidth=2..style=PaintingStyle.stroke; final path = Path(); path.moveTo(0, size.height*0.7); path.lineTo(size.width*0.2, size.height*0.6); path.lineTo(size.width*0.4, size.height*0.8); path.lineTo(size.width*0.6, size.height*0.4); path.lineTo(size.width*0.8, size.height*0.5); path.lineTo(size.width, size.height*0.1); canvas.drawPath(path, p);} @override bool shouldRepaint(covariant CustomPainter oldDelegate)=> false; }
