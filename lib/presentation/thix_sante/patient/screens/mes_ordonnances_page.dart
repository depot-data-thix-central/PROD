// lib/presentation/thix_sante/patient/screens/mes_ordonnances_page.dart
// =============================================================================
// Screen: MesOrdonnancesPage - Service Rapide 4
// Role: Ordonnances digitales QR verifiable + envoi pharmacie par THIX ID
// Fonctionnalites Master: QR code, statut temps reel, partage securise
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/patient_dashboard_provider.dart';
import '../models/prescription_model.dart';
import '../services/prescription_service.dart';

final prescriptionsProvider = FutureProvider<List<PrescriptionModel>>((ref) async {
  return ref.read(prescriptionServiceProvider).getMyPrescriptions();
});

class MesOrdonnancesPage extends ConsumerWidget {
  const MesOrdonnancesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordosAsync = ref.watch(prescriptionsProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Mes Ordonnances', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: ordosAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: ThixSanteColors.purpleLight, shape: BoxShape.circle), child: const Icon(Icons.receipt_long_rounded, size: 40, color: ThixSanteColors.purple)), const SizedBox(height: 16), const Text('Aucune ordonnance', style: TextStyle(fontWeight: FontWeight.w700)), const Text('Vos ordonnances prescrites par vos medecins lies par THIX ID apparaitront ici', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: ThixSanteColors.muted)),])));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (c,i) {
              final o = list[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixSanteColors.borderLight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _statusColor(o.status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(o.status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(o.status)))),
                    const Spacer(),
                    Text('${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year}', style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted)),
                  ]),
                  const SizedBox(height: 10),
                  Text(o.doctorName?? 'Dr Prescripteur', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text('${o.medicamentCount} medicaments • Expire le ${o.expiryDate?.day?? 30}/${o.expiryDate?.month?? 12}', style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted)),
                  const SizedBox(height: 10),
                 ...o.items.take(2).map((it) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [const Icon(Icons.medication_rounded, size: 14, color: ThixSanteColors.muted), const SizedBox(width: 6), Expanded(child: Text('${it.medicament} - ${it.posologie}', style: const TextStyle(fontSize: 12)))]))),
                  if (o.items.length > 2) Text('+ ${o.items.length - 2} autres', style: const TextStyle(fontSize: 11, color: ThixSanteColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _showQr(context, o), icon: const Icon(Icons.qr_code_rounded, size: 16), label: const Text('QR Verif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: ThixSanteColors.primary, side: const BorderSide(color: ThixSanteColors.primary)))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(onPressed: () => _sendToPharmacy(context, ref, o), icon: const Icon(Icons.local_pharmacy_rounded, size: 16), label: const Text('Envoyer pharma', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.success, foregroundColor: Colors.white))),
                  ]),
                ]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('$e')),
      ),
    );
  }

  Color _statusColor(PrescriptionStatus s) {
    switch (s) {
      case PrescriptionStatus.prescrite: return ThixSanteColors.primary;
      case PrescriptionStatus.envoyee: return ThixSanteColors.warning;
      case PrescriptionStatus.preparee: return ThixSanteColors.sky;
      case PrescriptionStatus.delivree: return ThixSanteColors.success;
      case PrescriptionStatus.expiree: return ThixSanteColors.danger;
    }
  }

  void _showQr(BuildContext context, PrescriptionModel o) {
    showDialog(context: context, builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Ordonnance Verifiable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 6), Text('Hash: ${o.qrHash}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: ThixSanteColors.muted)), const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.border)), child: QrImageView(data: o.qrVerificationUrl, size: 180)), const SizedBox(height: 12), const Text('Presentable en pharmacie pour verification instantanee', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))));
  }

  void _sendToPharmacy(BuildContext context, WidgetRef ref, PrescriptionModel o) {
    final TextEditingController ctrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Envoyer a la pharmacie par THIX ID', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 12), TextField(controller: ctrl, decoration: InputDecoration(labelText: 'THIX ID Pharmacie', hintText: 'THIX-CD-...', prefixIcon: const Icon(Icons.local_pharmacy_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), textCapitalization: TextCapitalization.characters), const SizedBox(height: 16), ElevatedButton(onPressed: () async { try { await ref.read(prescriptionServiceProvider).sendToPharmacy(prescriptionId: o.id, pharmacyThixId: ctrl.text.trim()); if (context.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ordonnance envoyee'), backgroundColor: ThixSanteColors.success)); ref.invalidate(prescriptionsProvider); } } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: ThixSanteColors.danger)); } }, style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white), child: const Text('Envoyer')), const SizedBox(height: 20)])));
  }
}
