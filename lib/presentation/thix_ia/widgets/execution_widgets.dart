import 'package:flutter/material.dart';
import '../models/execution_project.dart';

class ProjectHealthCard extends StatelessWidget {
  const ProjectHealthCard({super.key, required this.project});
  final ExecutionProject project;

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Santé du projet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: project.healthScore >= 70? Colors.green.shade100 : project.healthScore >= 50? Colors.orange.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(20)), child: Text('${project.healthScore}%', style: TextStyle(fontWeight: FontWeight.bold, color: project.healthScore >=70? Colors.green : project.healthScore>=50? Colors.orange : Colors.red))),
        ]),
        const SizedBox(height: 16),
        ...project.healthDimensions.entries.map((e)=> Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 80, child: Text(e.key, style: const TextStyle(fontSize: 11, color: Colors.grey))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: e.value/100, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(e.value>=70? Colors.green : e.value>=50? Colors.orange : Colors.red)))),
            const SizedBox(width: 8),
            Text('${e.value.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        )),
      ]),
    );
  }
}

class NextBestActionCard extends StatelessWidget {
  const NextBestActionCard({super.key, required this.title, required this.reason, this.onStart});
  final String title; final String reason; final VoidCallback? onStart;
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.indigo.shade600]), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.auto_awesome, color: Colors.white, size: 16), SizedBox(width: 6), Text('THIX IA RECOMMANDE', style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1))]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        ElevatedButton(onPressed: onStart, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Commencer')),
      ]),
    );
  }
}

class ComplianceRow extends StatelessWidget {
  const ComplianceRow({super.key, required this.title, required this.status});
  final String title; final String status;
  @override Widget build(BuildContext context){
    IconData icon = status=='valid'? Icons.check_circle : status=='warning'? Icons.warning_amber : Icons.cancel;
    Color color = status=='valid'? Colors.green : status=='warning'? Colors.orange : Colors.red;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 13))), Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))]));
  }
}
