import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';

final insuranceClaimsProvider = FutureProvider<List<Map<String,dynamic>>>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final List<dynamic> data = await db.from('insurance_claims').select().eq('patient_uid', uid).order('created_at', ascending: false);
  return data.map((e) => e as Map<String,dynamic>).toList();
});

final insuranceStatsProvider = FutureProvider<Map<String,dynamic>>((ref) async {
  final claims = await ref.watch(insuranceClaimsProvider.future);
  final int total = claims.length;
  final int pending = claims.where((c) => c['status']=='pending').length;
  final double totalAmount = claims.fold<double>(0, (s,e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
  final double reimbursed = claims.where((c)=>c['status']=='approved').fold<double>(0, (s,e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
  return {'total': total, 'pending': pending, 'totalAmount': totalAmount, 'reimbursed': reimbursed};
});

class AssuranceSantePage extends ConsumerWidget {
  const AssuranceSantePage({super.key});

  Future<void> _uploadInvoice(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','jpg','png'], withData: true);
    if (result==null || result.files.first.bytes==null) return;
    final file = result.files.first;
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser!.id;
    try {
      final String path = '$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await db.storage.from('invoices').uploadBinary(path, file.bytes!);
      final String publicUrl = db.storage.from('invoices').getPublicUrl(path);
      await db.from('insurance_claims').insert({
        'patient_uid': uid,
        'amount': 0,
        'status': 'pending',
        'invoice_url': publicUrl,
        'file_name': file.name,
        'description': 'Facture en attente',
        'created_at': DateTime.now().toIso8601String(),
      });
      ref.invalidate(insuranceClaimsProvider);
      ref.invalidate(insuranceStatsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Facture uploadee'), backgroundColor: ThixSanteColors.success));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixSanteColors.danger));
    }
  }

  void _showInsuranceCard(BuildContext context, String thixId, String fullName) {
    showDialog(context: context, builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.shield_rounded, color: Colors.white), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)), Text(thixId, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10))]))])), const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.border)), child: QrImageView(data: 'https://thix.id/insurance/verify/$thixId', size: 160)), const SizedBox(height: 10), const Text('Carte assurance verifiable QR', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(insuranceClaimsProvider);
    final statsAsync = ref.watch(insuranceStatsProvider);
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Assurance Sante', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context)), actions: [IconButton(icon: const Icon(Icons.qr_code_rounded, color: ThixSanteColors.primary), onPressed: () async {
        final db = Supabase.instance.client;
        final profile = await db.from('profiles').select('thix_id, full_name').eq('uid', db.auth.currentUser!.id).single();
        if (!context.mounted) return;
        _showInsuranceCard(context, profile['thix_id'] as String, profile['full_name'] as String);
      })]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        statsAsync.when(data: (s) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(16)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Rembourse', style: TextStyle(color: Colors.white70, fontSize: 11)), Text('${s['reimbursed']} FC', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))])), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Demandes', style: TextStyle(color: Colors.white70, fontSize: 11)), Text('${s['total']} dont ${s['pending']} en cours', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))]))])), loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())), error: (e,_) => Text('Erreur: $e')),
        const SizedBox(height: 16),
        SizedBox(height: 44, child: ElevatedButton.icon(onPressed: () => _uploadInvoice(context, ref), icon: const Icon(Icons.upload_file_rounded, size: 18), label: const Text('Soumettre facture'), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white))),
        const SizedBox(height: 16),
        claimsAsync.when(data: (claims) => Column(children: claims.map((c) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.borderLight)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long_rounded, color: ThixSanteColors.primary)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c['file_name'] ?? 'Facture', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)), Text('${c['status']}', style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))]))).toList()), loading: () => const CircularProgressIndicator(), error: (e,_) => Text('$e')),
      ]),
    );
  }
}
