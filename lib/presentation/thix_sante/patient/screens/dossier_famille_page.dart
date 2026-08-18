// lib/presentation/thix_sante/patient/screens/dossier_famille_page.dart
import 'dart:typed_data'; // Remplacement de dart:io par dart:typed_data
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/thix_id_validator.dart';
import '../providers/famille_provider.dart';
import 'dossier_medical_page.dart';
import 'carnet_vaccination_page.dart';
import 'prendre_rdv_page.dart';
import 'resultats_examens_page.dart';

class DossierFamillePage extends ConsumerStatefulWidget {
  const DossierFamillePage({super.key});
  @override
  ConsumerState<DossierFamillePage> createState() => _DossierFamillePageState();
}

class _DossierFamillePageState extends ConsumerState<DossierFamillePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(familleMembersNotifierProvider.notifier).load());
  }

  void _go(Widget p) => Navigator.push(context, MaterialPageRoute(builder: (_) => p));

  int _age(String? iso) {
    if (iso == null) return 0;
    try {
      final d = DateTime.parse(iso);
      return DateTime.now().year - d.year;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(familleMembersNotifierProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dossier Famille', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
              child: IconButton(icon: const Icon(Icons.person_add_rounded, color: Color(0xFF2563EB)), onPressed: _showAdd),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (members) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF06B6D4)]), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const CircleAvatar(radius: 26, backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=12')),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Famille THIX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)), Text('${members.length} membres • 1 Tuteur', style: const TextStyle(color: Colors.white, fontSize: 11))])),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _stat('${members.length}', 'Membres', Icons.group_rounded, const Color(0xFF2563EB)),
                _stat('${members.where((e) => e['lien'] != 'Vous').length}', 'Enfants', Icons.child_care_rounded, const Color(0xFF16A34A)),
                _stat('${members.length}', 'Dossiers', Icons.folder_special_rounded, const Color(0xFF7C3AED)),
              ]),
              const SizedBox(height: 14),
              const Text('  Membres', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),
              ...members.map((m) => _card(m)),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter par THIX ID'),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2563EB), side: const BorderSide(color: Color(0xFF2563EB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 90),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdd,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Ajouter enfant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _stat(String v, String l, IconData ic, Color c) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(9)), child: Icon(ic, color: c, size: 18)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), Text(l, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))]),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> m) {
    final thix = (m['thix_id'] ?? '') as String;
    final prenom = (m['prenom'] ?? '') as String;
    final nom = (m['nom'] ?? '') as String;
    final lien = (m['lien'] ?? '') as String;
    final groupe = (m['groupe_sanguin'] ?? 'O+') as String;
    final avatar = (m['avatar_url'] ?? 'https://i.pravatar.cc/100?img=5') as String;
    final isTuteur = lien == 'Vous';
    final age = _age(m['date_naissance'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: isTuteur ? const Color(0xFFBFDBFE) : const Color(0xFFF1F5F9))),
      child: Column(children: [
        ListTile(
          onTap: () => _showHealth(m),
          leading: CircleAvatar(radius: 26, backgroundImage: NetworkImage(avatar)),
          title: Row(children: [
            Text('$prenom $nom', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: isTuteur ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(20)),
              child: Text(lien, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isTuteur ? const Color(0xFF2563EB) : const Color(0xFF16A34A))),
            ),
          ]),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$lien • $age ans • $groupe', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            Text(thix, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Color(0xFF94A3B8))),
          ]),
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(children: [
            _act(Icons.folder_rounded, 'Dossier', const Color(0xFF2563EB), () => _go(const DossierMedicalPage())),
            _act(Icons.vaccines_rounded, 'Vaccins', const Color(0xFF16A34A), () => _go(const CarnetVaccinationPage())),
            _act(Icons.event_rounded, 'RDV', const Color(0xFFF59E0B), () => _go(const PrendreRdvPage())),
            _act(Icons.biotech_rounded, 'Examens', const Color(0xFF7C3AED), () => _go(const ResultatsExamensPage())),
            _act(Icons.delete_rounded, 'Suppr', const Color(0xFFEF4444), () => ref.read(familleMembersNotifierProvider.notifier).remove(m['id'] as String)),
          ]),
        ),
      ]),
    );
  }

  Widget _act(IconData i, String l, Color c, VoidCallback t) {
    return Expanded(
      child: InkWell(
        onTap: t,
        child: Column(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(9)), child: Icon(i, color: c, size: 16)),
          const SizedBox(height: 2),
          Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _showHealth(Map<String, dynamic> m) {
    final prenom = m['prenom'] ?? '';
    final thix = m['thix_id'] ?? '';
    final avatar = m['avatar_url'] ?? 'https://i.pravatar.cc/100?img=5';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [CircleAvatar(radius: 28, backgroundImage: NetworkImage(avatar)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['prenom']} ${m['nom']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), Text('$thix', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))])]),
          const SizedBox(height: 14),
          _link('Dossier medical complet', 'Voir dossier sante', Icons.folder_special_rounded, const Color(0xFF2563EB), () => _go(const DossierMedicalPage())),
          _link('Carnet de vaccination', '12 vaccins', Icons.vaccines_rounded, const Color(0xFF16A34A), () => _go(const CarnetVaccinationPage())),
          _link('Prendre RDV pour $prenom', 'Pediatre', Icons.event_rounded, const Color(0xFFF59E0B), () => _go(const PrendreRdvPage())),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _link(String t, String s, IconData i, Color c, VoidCallback onTap) {
    return ListTile(
      onTap: () { Navigator.pop(context); onTap(); },
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: c)),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text(s, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.arrow_forward_rounded, size: 16),
    );
  }

  void _showAdd() {
    final thixCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final postnomCtrl = TextEditingController();
    final prenomCtrl = TextEditingController();
    final poidsCtrl = TextEditingController();
    final tailleCtrl = TextEditingController();
    String sexe = 'M';
    String lien = 'Fille';
    String groupe = 'O+';
    DateTime? dob;
    Uint8List? imageBytes; // Modification: Utilisation de Uint8List au lieu de String
    int step = 0;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        
        // Modification de la fonction pick pour lire les octets
        Future<void> pick(bool cam) async {
          final XFile? x = await picker.pickImage(source: cam ? ImageSource.camera : ImageSource.gallery, imageQuality: 75);
          if (x != null) {
            final bytes = await x.readAsBytes();
            setSt(() => imageBytes = bytes);
          }
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [const Text('Ajouter un enfant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)), child: Text('Etape ${step + 1}/3', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))))]),
              const SizedBox(height: 14),
              if (step == 0) ...[
                TextField(controller: thixCtrl, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'THIX ID enfant', hintText: 'THIX-CD-0325-...', prefixIcon: const Icon(Icons.badge_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info_rounded, size: 16, color: Color(0xFFF59E0B)), SizedBox(width: 8), Expanded(child: Text('THIX ID mineur obligatoire', style: TextStyle(fontSize: 11)))])),
              ],
              if (step == 1) ...[
                Row(children: [Expanded(child: TextField(controller: prenomCtrl, decoration: _dec('Prenom'))), const SizedBox(width: 8), Expanded(child: TextField(controller: nomCtrl, decoration: _dec('Nom')))]),
                const SizedBox(height: 8),
                TextField(controller: postnomCtrl, decoration: _dec('Postnom')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: InkWell(onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: DateTime(2018)); if (d != null) setSt(() => dob = d); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.calendar_month_rounded, size: 18), const SizedBox(width: 6), Text(dob == null ? 'Date naissance' : '${dob!.day}/${dob!.month}/${dob!.year}', style: const TextStyle(fontSize: 13))])))),

                  const SizedBox(width: 8),
                  DropdownButton<String>(value: sexe, items: const [DropdownMenuItem(value: 'M', child: Text('Garcon')), DropdownMenuItem(value: 'F', child: Text('Fille'))], onChanged: (v) => setSt(() => sexe = v!)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(value: lien, decoration: _dec('Lien'), items: const [DropdownMenuItem(value: 'Fille', child: Text('Fille')), DropdownMenuItem(value: 'Fils', child: Text('Fils'))], onChanged: (v) => setSt(() => lien = v!))),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(value: groupe, decoration: _dec('Groupe'), items: const [DropdownMenuItem(value: 'O+', child: Text('O+')), DropdownMenuItem(value: 'A+', child: Text('A+')), DropdownMenuItem(value: 'B+', child: Text('B+')), DropdownMenuItem(value: 'AB+', child: Text('AB+'))], onChanged: (v) => setSt(() => groupe = v!))),
                ]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: TextField(controller: poidsCtrl, keyboardType: TextInputType.number, decoration: _dec('Poids kg'))), const SizedBox(width: 8), Expanded(child: TextField(controller: tailleCtrl, keyboardType: TextInputType.number, decoration: _dec('Taille cm')))]),
              ],
              if (step == 2) ...[
                // Modification de l'image de profil pour supporter le Web (MemoryImage)
                Center(child: Stack(children: [CircleAvatar(radius: 54, backgroundImage: imageBytes != null ? MemoryImage(imageBytes!) as ImageProvider : const NetworkImage('https://i.pravatar.cc/100?img=8')), Positioned(bottom: 0, right: 0, child: InkWell(onTap: () => pick(false), child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18))))])),
                const SizedBox(height: 10),
                const Center(child: Text('Photo avatar', style: TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => pick(false), icon: const Icon(Icons.photo_library_rounded), label: const Text('Galerie'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => pick(true), icon: const Icon(Icons.camera_alt_rounded), label: const Text('Camera')))]),
              ],
              const SizedBox(height: 18),
              Row(children: [
                if (step > 0) Expanded(child: OutlinedButton(onPressed: () => setSt(() => step--), child: const Text('Retour'))),
                if (step > 0) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (step == 0) {
                        if (!ThixIdValidator.isValidFormat(thixCtrl.text)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('THIX ID invalide'))); return; }
                        setSt(() => step = 1);
                      } else if (step == 1) {
                        if (prenomCtrl.text.isEmpty || nomCtrl.text.isEmpty || dob == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prenom, nom et date requis'))); return; }
                        setSt(() => step = 2);
                      } else {
                        try {
                          // Modification de l'appel pour passer avatarBytes au lieu de localAvatarPath
                          await ref.read(familleMembersNotifierProvider.notifier).add(
                            thixId: thixCtrl.text, 
                            nom: nomCtrl.text, 
                            postnom: postnomCtrl.text, 
                            prenom: prenomCtrl.text, 
                            dob: dob!, 
                            sexe: sexe, 
                            lien: lien, 
                            groupe: groupe, 
                            poids: double.tryParse(poidsCtrl.text), 
                            taille: double.tryParse(tailleCtrl.text), 
                            avatarBytes: imageBytes
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${prenomCtrl.text} ajoute'), backgroundColor: const Color(0xFF16A34A)));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(step == 2 ? 'Enregistrer & Lier' : 'Continuer'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        );
      }),
    );
  }

  InputDecoration _dec(String l) => InputDecoration(labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12));
}
