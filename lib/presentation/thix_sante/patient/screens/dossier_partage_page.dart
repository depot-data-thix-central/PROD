// lib/presentation/thix_sante/patient/screens/dossier_partage_page.dart
// =============================================================================
// Screen: DossierPartagePage - Service Rapide 12 [Innovation Master]
// Role: Partage securise dossier par THIX ID UID avec expiration et logs
// Fonctionnalite academique: QR partage temporaire, niveau acces, audit trail
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';

class DossierPartagePage extends StatefulWidget {
  const DossierPartagePage({super.key});
  @override
  State<DossierPartagePage> createState() => _DossierPartagePageState();
}

class _DossierPartagePageState extends State<DossierPartagePage> {
  final List<Map<String,dynamic>> _shares = [
    {'doctor':'Dr Mukendi','thix':'THIX-CD-0726-12345-ABC-1','access':'Acces complet','until':'Expire dans 2j','active':true},
    {'doctor':'Pharmacie Centrale','thix':'THIX-CD-1123-40001-PHA-4','access':'Ordonnances uniquement','until':'Expire dans 5h','active':true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Dossier Partage', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context)), actions: [IconButton(icon: const Icon(Icons.add_link_rounded, color: ThixSanteColors.primary), onPressed: _showShareSheet)]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(14)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.shield_rounded, color: ThixSanteColors.primary, size: 20)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Partage securise par THIX ID UID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('Chaque acces est logge, expire automatiquement, revocable en 1 clic. Conforme RGPD.', style: TextStyle(fontSize: 11, color: ThixSanteColors.muted))]))])),
          const SizedBox(height: 16),
          Row(children: [const Text('Partages actifs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(20)), child: Text('${_shares.where((s)=>s['active']==true).length} actifs', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixSanteColors.success)))]),
          const SizedBox(height: 10),
        ..._shares.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [CircleAvatar(radius: 18, backgroundColor: ThixSanteColors.primaryLight, child: Text((s['doctor'] as String)[0], style: const TextStyle(color: ThixSanteColors.primary, fontWeight: FontWeight.w800))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s['doctor'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(s['thix'] as String, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: ThixSanteColors.muted))])), Switch(value: s['active'] as bool, onChanged: (v) => setState(() => s['active'] = v), activeColor: ThixSanteColors.success)]),
                  const SizedBox(height: 10),
                  Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: ThixSanteColors.borderLight, borderRadius: BorderRadius.circular(20)), child: Text(s['access'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: ThixSanteColors.warningLight, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.timer_rounded, size: 12, color: ThixSanteColors.warning), const SizedBox(width: 4), Text(s['until'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ThixSanteColors.warning))]))]),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.visibility_rounded, size: 16), label: const Text('Voir logs', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: ThixSanteColors.ink, side: const BorderSide(color: ThixSanteColors.border)))), const SizedBox(width: 8), Expanded(child: ElevatedButton.icon(onPressed: () => setState(() => s['active'] = false), icon: const Icon(Icons.link_off_rounded, size: 16), label: const Text('Revoquer', style: TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.dangerLight, foregroundColor: ThixSanteColors.danger, elevation: 0)))])
                ]),
              )),
          const SizedBox(height: 10),
          SizedBox(height: 48, child: OutlinedButton.icon(onPressed: _showShareSheet, icon: const Icon(Icons.add_rounded), label: const Text('Nouveau partage par THIX ID'), style: OutlinedButton.styleFrom(foregroundColor: ThixSanteColors.primary, side: const BorderSide(color: ThixSanteColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ],
      ),
    );
  }

  void _showShareSheet() {
    final ctrl = TextEditingController();
    String access = 'Acces complet';
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => StatefulBuilder(builder: (ctx,setM) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixSanteColors.border, borderRadius: BorderRadius.circular(2)), alignment: Alignment.center), const SizedBox(height: 16),
      const Text('Partager par THIX ID UID', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 12),
      TextField(controller: ctrl, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'THIX ID destinataire', hintText: 'THIX-CD-...', prefixIcon: const Icon(Icons.fingerprint_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: access, decoration: InputDecoration(labelText: 'Niveau acces', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: const [DropdownMenuItem(value: 'Acces complet', child: Text('Acces complet')), DropdownMenuItem(value: 'Lecture seule', child: Text('Lecture seule')), DropdownMenuItem(value: 'Ordonnances uniquement', child: Text('Ordonnances uniquement')), DropdownMenuItem(value: 'Urgence uniquement', child: Text('Urgence uniquement'))], onChanged: (v) => setM(() => access = v!)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { if (ThixIdValidator.isValidFormat(ctrl.text)) { setState(() => _shares.add({'doctor':'Nouveau destinataire','thix':ThixIdValidator.clean(ctrl.text),'access':access,'until':'Expire dans 48h','active':true})); Navigator.pop(ctx); } }, style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Partager securise - expire 48h')),
      const SizedBox(height: 20),
    ]))));
  }
}
