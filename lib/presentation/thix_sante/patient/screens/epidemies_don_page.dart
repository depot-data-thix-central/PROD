// lib/presentation/thix_sante/patient/screens/epidemies_don_page.dart
// =============================================================================
// Screens: EpidemiesPage + DonSangPage - Services Rapides 13 & 14
// Role: Veille epidemiologique + don sang avec THIX ID donneur
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
// ---------------- EPIDEMIES ----------------
class EpidemiesPage extends StatelessWidget {
  const EpidemiesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final alerts = [
      {'title':'Grippe saisonniere','level':'Modere','color':ThixSanteColors.warning,'desc':'Pic attendu semaine prochaine a Kinshasa','action':'Voir conseils'},
      {'title':'Cholera - Kasaï','level':'Eleve','color':ThixSanteColors.danger,'desc':'3 cas confirmes - eviter eau non traitee','action':'Protocole'},
      {'title':'COVID-19','level':'Faible','color':ThixSanteColors.success,'desc':'Aucune alerte dans votre zone THIX ID','action':'Rappel vaccin'},
    ];
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Veille Epidemies', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ThixSanteColors.skyLight, borderRadius: BorderRadius.circular(14)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.coronavirus_rounded, color: ThixSanteColors.sky)), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Surveillance basee sur votre zone THIX ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), Text('Donnees INSP + OMS mises a jour toutes les 6h', style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))])),
          const SizedBox(height: 16),
        ...alerts.map((a) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.warning_amber_rounded, color: a['color'] as Color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(a['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text(a['level'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: a['color'] as Color))) ]), Text(a['desc'] as String, style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted))])), TextButton(onPressed: () {}, child: Text(a['action'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))]))),
        ],
      ),
    );
  }
}

// ---------------- DON DE SANG ----------------
class DonSangPage extends StatefulWidget {
  const DonSangPage({super.key});
  @override
  State<DonSangPage> createState() => _DonSangPageState();
}

class _DonSangPageState extends State<DonSangPage> {
  bool isDonor = true;
  String bloodGroup = 'O+';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Don de Sang', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]), borderRadius: BorderRadius.circular(16)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 28)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Devenez donneur THIX ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)), Text('Votre THIX ID UID permet un don trace et securise', style: TextStyle(color: Colors.white70, fontSize: 11))]))])),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Je suis donneur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Switch(value: isDonor, onChanged: (v) => setState(() => isDonor = v), activeColor: ThixSanteColors.danger)]),
            if (isDonor)...[
              const Divider(),
              Row(children: [const Text('Groupe sanguin', style: TextStyle(fontSize: 12)), const Spacer(), DropdownButton<String>(value: bloodGroup, underline: const SizedBox(), items: ['A+','A-','B+','B-','AB+','AB-','O+','O-'].map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontWeight: FontWeight.w700)))).toList(), onChanged: (v) => setState(() => bloodGroup = v!))]),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ThixSanteColors.background, borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.fingerprint_rounded, size: 16, color: ThixSanteColors.muted), const SizedBox(width: 6), const Expanded(child: Text('THIX-CD-0726-12345-ABC-1 • Don trace', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: ThixSanteColors.muted))), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(10)), child: const Text('Verifie', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ThixSanteColors.success))) ])),
            ],
          ])),
          const SizedBox(height: 16),
          const Text('Demandes urgentes proches', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.danger.withOpacity(0.2))), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: ThixSanteColors.dangerLight, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('O+', style: TextStyle(fontWeight: FontWeight.w900, color: ThixSanteColors.danger, fontSize: 16)))), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Besoin urgent O+ - Hopital General', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('Il y a 12 min • 1.2 km • 3 donneurs recherches', style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))])), ElevatedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci! Centre contacte via THIX ID'), backgroundColor: ThixSanteColors.success)), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Donner', style: TextStyle(fontSize: 11)))])),
        ],
      ),
    );
  }
}
