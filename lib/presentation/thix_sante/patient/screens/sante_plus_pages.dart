// lib/presentation/thix_sante/patient/screens/sante_plus_pages.dart
// =============================================================================
// Screens: RappelsVaccin + CertificatMedical + AssuranceSante
// Role: Cloture Services Rapides - 20/20 cases conformes capture
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
// ---------------- RAPPELS VACCIN ----------------
class RappelsVaccinPage extends StatelessWidget {
  const RappelsVaccinPage({super.key});
  @override
  Widget build(BuildContext context) {
    final vaccins = [
      {'nom':'Tetanus','date':'15/08/2026','status':'A venir','color':ThixSanteColors.warning},
      {'nom':'Grippe','date':'10/03/2026','status':'Fait','color':ThixSanteColors.success},
      {'nom':'Hepatite B','date':'02/12/2025','status':'Expire','color':ThixSanteColors.danger},
    ];
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Rappels Vaccin', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.vaccines_rounded, color: ThixSanteColors.primary), const SizedBox(width: 10), const Expanded(child: Text('Carnet lie a votre THIX ID UID - presentable partout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))])),
        const SizedBox(height: 16),
      ...vaccins.map((v) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: (v['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.shield_rounded, color: v['color'] as Color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v['nom'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(v['date'] as String, style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted))])), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (v['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(v['status'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: v['color'] as Color))) ]))),
        const SizedBox(height: 12),
        SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.qr_code_rounded), label: const Text('Mon carnet QR THIX ID'), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white))),
      ]),
    );
  }
}

// ---------------- CERTIFICAT MEDICAL ----------------
class CertificatMedicalPage extends StatelessWidget {
  const CertificatMedicalPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Certificat Medical', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixSanteColors.borderLight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.verified_rounded, color: ThixSanteColors.success)), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Certificat d aptitude', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), Text('Delivre par Dr Mukendi • THIX-CD-0726-12345-ABC-1', style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))]),
          const SizedBox(height: 16),
          Container(height: 120, decoration: BoxDecoration(color: ThixSanteColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.borderLight, style: BorderStyle.solid)), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.picture_as_pdf_rounded, size: 36, color: ThixSanteColors.mutedLight), SizedBox(height: 6), Text('Apercu PDF certificat verifiable QR', style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Telecharger PDF', style: TextStyle(fontSize: 12)))), const SizedBox(width: 10), Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.share_rounded, size: 16), label: const Text('Partager THIX ID', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white)))])
        ])),
        const SizedBox(height: 16),
        const Text('Demander un nouveau certificat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
       ...['Certificat de repos','Aptitude sportive','Vaccination','Non contagion'].map((t) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.borderLight)), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.description_rounded, size: 18, color: ThixSanteColors.primary)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), trailing: const Icon(Icons.chevron_right_rounded, size: 18), onTap: () {}))),
      ]),
    );
  }
}

// ---------------- ASSURANCE SANTE ----------------
class AssuranceSantePage extends StatelessWidget {
  const AssuranceSantePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Assurance Sante', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.shield_rounded, color: Colors.white)), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('THIX Assurance - Plan Famille', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)), Text('Lie a THIX-CD-0726-12345-ABC-1', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'))]))]), const SizedBox(height: 14), Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Couverture', style: TextStyle(color: Colors.white70, fontSize: 11)), const Text('85% frais medicaux', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))])), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Prochaine echeance', style: TextStyle(color: Colors.white70, fontSize: 11)), const Text('15 Aout 2026', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))]))])])),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: _assuranceStat(icon: Icons.receipt_long_rounded, label: 'Remboursements', value: '3 en cours', color: ThixSanteColors.successLight)), const SizedBox(width: 10), Expanded(child: _assuranceStat(icon: Icons.local_hospital_rounded, label: 'Soins couverts', value: '12 / an', color: ThixSanteColors.primaryLight))]),
        const SizedBox(height: 16),
        const Text('Actions rapides', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6, children: [
          _actionCard(icon: Icons.upload_file_rounded, title: 'Soumettre facture', subtitle: 'Remboursement 24h via THIX ID'),
          _actionCard(icon: Icons.card_membership_rounded, title: 'Carte numerique', subtitle: 'QR assurance THIX ID'),
          _actionCard(icon: Icons.support_agent_rounded, title: 'Assistance 24/7', subtitle: 'Chat avec conseiller'),
          _actionCard(icon: Icons.history_rounded, title: 'Historique', subtitle: 'Factures & remboursements'),
        ]),
      ]),
    );
  }

  static Widget _assuranceStat({required IconData icon, required String label, required String value, required Color color}) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.borderLight)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: ThixSanteColors.primary)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))])]));
  static Widget _actionCard({required IconData icon, required String title, required String subtitle}) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.borderLight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: ThixSanteColors.primary)), const Spacer(), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), Text(subtitle, style: const TextStyle(fontSize: 10, color: ThixSanteColors.muted))]));
}
