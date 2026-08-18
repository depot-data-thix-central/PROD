import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/objet_model.dart';
import '../providers/objet_providers.dart';

class DeclarerObjetPage extends ConsumerStatefulWidget {
  final StatutObjet type;

  const DeclarerObjetPage({super.key, required this.type});

  @override
  ConsumerState<DeclarerObjetPage> createState() => _DeclarerObjetPageState();
}

class _DeclarerObjetPageState extends ConsumerState<DeclarerObjetPage> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  final _recompenseCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  String? _categorie;
  bool _isLoading = false;

  XFile? _photo;
  Uint8List? _photoBytes;

  final _picker = ImagePicker();

  final List<String> _categories = [
    'Téléphone',
    'Portefeuille / Sac',
    'Clés',
    'Documents',
    'Bijoux / Montre',
    'Sac à dos',
    'Écouteurs / Accessoires',
    'Autre',
  ];

  bool get isPerdu => widget.type == StatutObjet.perdu;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _lieuCtrl.dispose();
    _recompenseCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () async {
                Navigator.pop(context);
                final x = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 75,
                  maxWidth: 1200,
                );
                if (x != null) {
                  final bytes = await x.readAsBytes();
                  setState(() {
                    _photo = x;
                    _photoBytes = bytes;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () async {
                Navigator.pop(context);
                final x = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 75,
                  maxWidth: 1200,
                );
                if (x != null) {
                  final bytes = await x.readAsBytes();
                  setState(() {
                    _photo = x;
                    _photoBytes = bytes;
                  });
                }
              },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Supprimer la photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _photo = null;
                    _photoBytes = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(objetServiceProvider);

      await service.declarerObjet(
        titre: _titreCtrl.text,
        description: _descCtrl.text,
        statut: widget.type,
        lieu: _lieuCtrl.text,
        recompense: isPerdu && _recompenseCtrl.text.isNotEmpty
            ? _recompenseCtrl.text
            : null,
        categorie: _categorie,
        contactInfo: _contactCtrl.text.isEmpty ? null : _contactCtrl.text,
        photoBytes: _photoBytes,
        photoFileName: _photo?.name ?? 'photo.jpg',
      );

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPerdu
                  ? 'Objet perdu déclaré ! THIX IA cherche des correspondances...'
                  : 'Objet trouvé déclaré. Merci pour la communauté !',
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isPerdu ? "J'ai perdu un objet" : "J'ai trouvé un objet",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPerdu ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    isPerdu ? Icons.search : Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPerdu
                          ? 'Déclarez l\'objet que vous avez perdu. La communauté et THIX IA vont vous aider à le retrouver.'
                          : 'Déclarez l\'objet que vous avez trouvé. Aidez quelqu\'un à le récupérer.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Zone photo (Image.memory = Web + Mobile)
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _photoBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              _photoBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _photo = null;
                                    _photoBytes = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Changer',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 10),
                          Text(
                            'Ajouter une photo',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Caméra ou galerie',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Titre de l\'objet *'),
            TextFormField(
              controller: _titreCtrl,
              decoration: _inputDecoration('Ex: Téléphone Samsung Galaxy A54'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titre obligatoire' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel('Catégorie'),
            DropdownButtonFormField<String>(
              value: _categorie,
              decoration: _inputDecoration('Choisir une catégorie'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categorie = v),
            ),
            const SizedBox(height: 16),

            _buildLabel('Description détaillée *'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: _inputDecoration(
                isPerdu
                    ? 'Couleur, marque, particularités, contenu...'
                    : 'Décrivez précisément l\'objet trouvé...',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Description obligatoire' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel(isPerdu ? 'Lieu de perte *' : 'Lieu de trouvaille *'),
            TextFormField(
              controller: _lieuCtrl,
              decoration: _inputDecoration('Ex: THIX Center, Kiswahili'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Lieu obligatoire' : null,
            ),
            const SizedBox(height: 16),

            if (isPerdu) ...[
              _buildLabel('Récompense (optionnel)'),
              TextFormField(
                controller: _recompenseCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Ex: 20 000 FC'),
              ),
              const SizedBox(height: 16),
            ],

            _buildLabel('Contact (téléphone ou email)'),
            TextFormField(
              controller: _contactCtrl,
              decoration: _inputDecoration('+243 ... ou email@example.com'),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPerdu ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        isPerdu ? 'Déclarer comme perdu' : 'Déclarer comme trouvé',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
