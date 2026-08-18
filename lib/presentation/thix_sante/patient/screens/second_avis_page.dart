// lib/presentation/thix_sante/patient/screens/second_avis_page.dart
// =============================================================================
// Screen: SecondAvisPage - NEW 3
// Role: Demander un second avis a un autre docteur lie par UID
// Fonctionnalite Master: Partage dossier securise, workflow academique
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/patient_dashboard_provider.dart';
import '../models/patient_link_model.dart';

class SecondAvisPage extends ConsumerWidget {
  const SecondAvisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PatientLinkModel>> doctorsAsync = ref.watch(_doctorsProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(
        backgroundColor: ThixSanteColors.surface,
        elevation: 0,
        title: const Text('Second Avis Medical', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context)),
      ),
      body: doctorsAsync.when(
        data: (doctors) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ThixSanteColors.skyLight, borderRadius: BorderRadius.circular(14)), child: const Row(children: [Icon(Icons.health_and_safety_rounded, color: ThixSanteColors.sky), SizedBox(width: 10), Expanded(child: Text('Obtenez un second avis d un specialiste lie a votre THIX ID, sans ressaisir votre dossier.', style: TextStyle(fontSize: 12)))])),
            const SizedBox(height: 20),
            const Text('Choisissez un medecin pour second avis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            if (doctors.isEmpty)
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Column(children: [Icon(Icons.person_search_rounded, size: 48, color: ThixSanteColors.mutedLight), SizedBox(height: 10), Text('Aucun medecin lie', style: TextStyle(fontWeight: FontWeight.w600)), Text('Ajoutez d abord un medecin traitant par THIX ID', style: TextStyle(fontSize: 12, color: ThixSanteColors.muted), textAlign: TextAlign.center)]))
            else
             ...doctors.map((link) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: ThixSanteColors.primaryLight, child: Text(link.doctorProfile?.initials?? 'D', style: const TextStyle(color: ThixSanteColors.primary, fontWeight: FontWeight.w800))),
                      title: Text(link.doctorProfile?.fullName?? 'Dr Inconnu', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(link.doctorProfile?.displaySpeciality?? 'Generaliste', style: const TextStyle(fontSize: 11)),
                      trailing: ElevatedButton(onPressed: () => _requestSecondAvis(context, link), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 14)), child: const Text('Demander', style: TextStyle(fontSize: 11))),
                    ),
                  )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  void _requestSecondAvis(BuildContext context, PatientLinkModel link) {
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Text('Second avis - Dr ${link.doctorProfile?.fullName?? ''}'), content: const Text('Votre dossier medical anonymise sera partage temporairement (48h) avec ce specialiste pour second avis. Confirmez-vous?', style: TextStyle(fontSize: 13)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), ElevatedButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Demande envoyee au Dr ${link.doctorProfile?.fullName}'), backgroundColor: ThixSanteColors.success)); }, style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary), child: const Text('Confirmer', style: TextStyle(color: Colors.white))) ]));
  }
}

final _doctorsProvider = FutureProvider<List<PatientLinkModel>>((ref) async {
  return ref.read(patientLinkServiceProvider).getActiveDoctors();
});
