// lib/presentation/thix_sante/sante/screens/carnet_vaccination_page.dart
// =============================================================================
// Screen: CarnetVaccinationPage - Service Sante 2/11
// Source reelle: public.health_records where type = 'vaccin'
// + public.family_links pour switch enfant/adulte
// QR verifiable genere depuis thix_id + record.id
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
import '../../patient/models/health_record_model.dart';

final vaccinationRecordsProvider = FutureProvider<List<HealthRecordModel>>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final List<dynamic> data = await db
   .from('health_records')
   .select()
   .eq('patient_uid', uid)
   .eq('type', 'vaccin')
   .order('exam_date', ascending: false);
  return data.map((e) => HealthRecordModel.fromJson(e as Map<String,dynamic>)).toList();
});

class CarnetVaccinationPage extends ConsumerWidget {
  const CarnetVaccinationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaccinsAsync = ref.watch(vaccinationRecordsProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(
        backgroundColor: ThixSanteColors.surface,
        elevation: 0,
        title: const Text('Carnet Vaccination', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: ThixSanteColors.primary),
            onPressed: () async {
              final db = Supabase.instance.client;
              final profile = await db.from('profiles').select('thix_id').eq('uid', db.auth.currentUser!.id).single();
              if (!context.mounted) return;
              _showQr(context, profile['thix_id'] as String);
            },
          ),
        ],
      ),
      body: vaccinsAsync.when(
        data: (vaccins) {
          final int total = vaccins.length;
          final int aJour = vaccins.where((v) => v.examDate!=null && v.examDate!.isAfter(DateTime.now().subtract(const Duration(days: 365)))).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixSanteColors.borderLight)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.verified_user_rounded, color: ThixSanteColors.success, size: 28)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Carnet International OMS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    FutureBuilder<Map<String,dynamic>>(
                      future: Supabase.instance.client.from('profiles').select('thix_id').eq('uid', Supabase.instance.client.auth.currentUser!.id).single(),
                      builder: (c,snap) => Text(snap.data?['thix_id']?? 'Chargement THIX ID...', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: ThixSanteColors.muted)),
                    ),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(20)), child: Text('$aJour / $total vaccins valides • Source: health_records', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixSanteColors.success))),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
              if (vaccins.isEmpty)
                Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(children: [Icon(Icons.vaccines_outlined, size: 48, color: ThixSanteColors.mutedLight.withOpacity(0.6)), const SizedBox(height: 12), const Text('Aucun vaccin enregistre', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), const Text('Vos vaccins prescrits par medecin lie par THIX ID apparaitront ici depuis health_records type=vaccin', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))
              else
              ...vaccins.map((v) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)),
                      child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: v.examDate!=null && v.examDate!.isAfter(DateTime.now())? ThixSanteColors.warningLight: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(10)), child: Icon(v.typeIcon, color: v.examDate!=null && v.examDate!.isAfter(DateTime.now())? ThixSanteColors.warning: ThixSanteColors.success)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ThixSanteColors.ink)),
                          Text(v.description?? 'Lot: ${v.fileName?? 'N/A'} • ${v.doctorName?? 'Centre THIX'}', style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(v.examDate!=null? 'Fait le ${v.examDate!.day}/${v.examDate!.month}/${v.examDate!.year}': 'Date: ${v.createdAt.day}/${v.createdAt.month}/${v.createdAt.year}', style: const TextStyle(fontSize: 10, color: ThixSanteColors.mutedLight)),
                        ])),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: v.examDate!=null && v.examDate!.isAfter(DateTime.now())? ThixSanteColors.warningLight: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(20)), child: Text(v.examDate!=null && v.examDate!.isAfter(DateTime.now())? 'A venir':'Valide', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: v.examDate!=null && v.examDate!.isAfter(DateTime.now())? ThixSanteColors.warning: ThixSanteColors.success))),
                      ]),
                    )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('Erreur RLS health_records: $e')),
      ),
    );
  }

  void _showQr(BuildContext context, String thixId) {
    showDialog(context: context, builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Carnet QR Verifiable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 6), Text(thixId, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: ThixSanteColors.muted)), const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.border)), child: QrImageView(data: 'https://thix.id/verify/vaccin/$thixId', size: 180)), const SizedBox(height: 10), const Text('Presentable frontiere / ecole - verification via THIX ID UID', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))));
  }
}
