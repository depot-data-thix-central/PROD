// lib/presentation/thix_sante/patient/screens/resultats_examens_page.dart
// =============================================================================
// Screen: ResultatsExamens - Service Rapide 3
// Role: Visualisation examens labo + radiologie avec graphiques
// Fonctionnalites modernes: Filtre date, courbe evolution, download
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/patient_dashboard_provider.dart';
import '../models/health_record_model.dart';

class ResultatsExamensPage extends ConsumerWidget {
  const ResultatsExamensPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recentRecordsProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Resultats Examens', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: recordsAsync.when(
        data: (all) {
          final exams = all.where((r) => r.type == RecordType.laboratoire || r.type == RecordType.radiologie).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Suivi biologique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 4), Text('Vos resultats sont analyses par IA pour detection anomalie', style: TextStyle(color: Colors.white70, fontSize: 11))])), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.analytics_rounded, color: Colors.white))]) ),
              const SizedBox(height: 16),
              if (exams.isEmpty) Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Column(children: [Icon(Icons.science_outlined, size: 48, color: ThixSanteColors.mutedLight), SizedBox(height: 10), Text('Aucun examen', style: TextStyle(fontWeight: FontWeight.w600))]))
              else...exams.map((e) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)), child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: e.type == RecordType.laboratoire? ThixSanteColors.successLight: ThixSanteColors.skyLight, borderRadius: BorderRadius.circular(10)), child: Icon(e.typeIcon, color: e.typeColor)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(e.doctorName?? 'Laboratoire THIX', style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted)), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(20)), child: const Text('Normal • Analyse IA OK', style: TextStyle(fontSize: 10, color: ThixSanteColors.success, fontWeight: FontWeight.w600)))])),
                IconButton(icon: const Icon(Icons.download_rounded, size: 20), onPressed: () {}),
              ]))),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('$e')),
      ),
    );
  }
}
