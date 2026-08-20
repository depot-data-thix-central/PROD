import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/personne_recherchee_model.dart';
import '../providers/recherche_providers.dart';

class CreerAlertePage extends ConsumerStatefulWidget {
  const CreerAlertePage({super.key});

  @override
  ConsumerState<CreerAlertePage> createState() => _CreerAlertePageState();
}

class _CreerAlertePageState extends ConsumerState<CreerAlertePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _tailleCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  TypeAlerte _type = TypeAlerte.disparue;
  String? _sexe; // F | M | X
  Uint8List? _photoBytes;
  String? _photoName;
  bool _loading = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _ageCtrl.dispose();
    _tailleCtrl.dispose();
    _zoneCtrl.dispose();
    _descCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoName = file.name;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final service = ref.read(rechercheServiceProvider);

      String? photoUrl;
      if (_photoBytes != null && _photoBytes!.isNotEmpty) {
        photoUrl = await service.uploadPhoto(
          bytes: _photoBytes!,
          fileName: _photoName ?? 'photo.jpg',
        );
      }

      final age = int.tryParse(_ageCtrl.text.trim());
      final taille = double.tryParse(
        _tailleCtrl.text.trim().replaceAll(',', '.'),
      );

      final created = await service.creerAlerte(
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim().isEmpty
            ? null
            : _prenomCtrl.text.trim(),
        age: age,
        sexe: _sexe,
        tailleCm: taille != null && taille < 3 ? taille * 100 : taille,
        typeAlerte: _type,
        photoUrl: photoUrl,
        derniereZone:
            _zoneCtrl.text.trim().isEmpty ? null : _zoneCtrl.text.trim(),
        derniereVueAt: DateTime.now(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        contactInfo: _contactCtrl.text.trim().isEmpty
            ? null
            : _contactCtrl.text.trim(),
      );

      if (!mounted) return;

      if (created != null) {
        ref.invalidate(alertesActivesProvider);
        ref.invalidate(mesAlertesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte publiée'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Créer une alerte',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Type
            Text('Type d\'alerte',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Disparue'),
                    selected: _type == TypeAlerte.disparue,
                    onSelected: (_) =>
                        setState(() => _type = TypeAlerte.disparue),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Recherchée'),
                    selected: _type == TypeAlerte.recherchee,
                    onSelected: (_) =>
                        setState(() => _type = TypeAlerte.recherchee),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Photo
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photoBytes != null
                    ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined,
                              color: Colors.black38),
                          const SizedBox(height: 6),
                          Text('Ajouter une photo',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.black45)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prenomCtrl,
              decoration: const InputDecoration(
                labelText: 'Prénom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Âge',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _tailleCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Taille (m ou cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sexe
            DropdownButtonFormField<String>(
              value: _sexe,
              decoration: const InputDecoration(
                labelText: 'Sexe',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'F', child: Text('F')),
                DropdownMenuItem(value: 'M', child: Text('M')),
                DropdownMenuItem(value: 'X', child: Text('X')),
              ],
              onChanged: (v) => setState(() => _sexe = v),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _zoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Dernière zone vue',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Publier l\'alerte',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
