// lib/presentation/opportunities/opportunity_admin_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

// Tes services et modèles
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/services/opportunity_service.dart';

class OpportunityAdminPage extends StatefulWidget {
  const OpportunityAdminPage({super.key});

  @override
  State<OpportunityAdminPage> createState() => _OpportunityAdminPageState();
}

class _OpportunityAdminPageState extends State<OpportunityAdminPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Contrôleurs
  final _titleCtrl = TextEditingController();
  final _organizerCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Image d'Upload
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;

  // Liste dynamique pour les critères d'éligibilité
  final List<TextEditingController> _eligibilityCtrls = [TextEditingController()];

  String _selectedCategory = 'Emplois';
  final List<String> _categories = ['Emplois', 'Bourses', 'Concours', 'Subventions', 'Événements'];

  DateTime? _selectedDeadline;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _organizerCtrl.dispose();
    _locationCtrl.dispose();
    _rewardCtrl.dispose();
    _linkCtrl.dispose();
    _descCtrl.dispose();
    for (var ctrl in _eligibilityCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ThixPolicy.primary,
              onPrimary: Colors.white,
              onSurface: ThixPolicy.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // Nécessaire pour avoir les bytes de l'image
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedImageBytes = file.bytes;
          _selectedImageExt = file.extension ?? 'jpg';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la sélection de l\'image.'), backgroundColor: ThixPolicy.danger),
      );
    }
  }

  Future<void> _submitOpportunity() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.', style: TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger),
      );
      return;
    }

    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date limite.', style: TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = OpportunityService();
      String? finalImageUrl;

      // 1. Upload de l'image s'il y en a une
      if (_selectedImageBytes != null) {
        finalImageUrl = await service.uploadOpportunityImage(
          bytes: _selectedImageBytes!,
          extension: _selectedImageExt!,
        );
      }

      // 2. Préparation des critères
      final eligibilityList = _eligibilityCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

      // 3. Création de l'objet Opportunity
      final newItem = OpportunityItem(
        id: '', // L'ID sera généré par le backend ou ton service
        title: _titleCtrl.text.trim(),
        organizer: _organizerCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        category: _selectedCategory,
        rewardLabel: _rewardCtrl.text.trim(),
        deadlineLabel: DateFormat('dd MMM yyyy', 'fr_FR').format(_selectedDeadline!),
        deadline: _selectedDeadline!,
        description: _descCtrl.text.trim(),
        eligibility: eligibilityList,
        applyUrl: _linkCtrl.text.trim(),
        imageAssetPath: finalImageUrl, // Sera null si pas d'image, sinon l'URL Supabase
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Insertion via ton service
      await service.createOpportunity(newItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opportunité publiée avec succès !', style: TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.success),
        );
        context.pop(); // Retour à la liste
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e', style: const TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        title: const Text('Publier une opportunité', style: TextStyle(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: ThixPolicy.border, height: 1)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ThixPolicy.s16),
          physics: const BouncingScrollPhysics(),
          children: [
            // 🌟 NOUVEAU BLOC IMAGE
            _buildImageUploadSection(),
            const SizedBox(height: ThixPolicy.s24),

            _buildSection(
              title: 'Informations Générales',
              icon: Icons.info_outline_rounded,
              children: [
                _buildInputField(label: 'Titre de l\'opportunité *', controller: _titleCtrl, hint: 'Ex: Bourse d\'étude MasterCard 2026'),
                const SizedBox(height: ThixPolicy.s16),
                _buildInputField(label: 'Organisateur / Entreprise *', controller: _organizerCtrl, hint: 'Ex: Fondation MasterCard'),
                const SizedBox(height: ThixPolicy.s16),
                _buildDropdown(),
              ],
            ),
            const SizedBox(height: ThixPolicy.s24),
            
            _buildSection(
              title: 'Détails Pratiques',
              icon: Icons.work_outline_rounded,
              children: [
                _buildInputField(label: 'Lieu *', controller: _locationCtrl, hint: 'Ex: Kinshasa, RDC ou En ligne'),
                const SizedBox(height: ThixPolicy.s16),
                _buildInputField(label: 'Récompense / Salaire *', controller: _rewardCtrl, hint: 'Ex: Financement total ou 1500\$/mois'),
                const SizedBox(height: ThixPolicy.s16),
                _buildDatePicker(),
                const SizedBox(height: ThixPolicy.s16),
                _buildInputField(label: 'Lien de candidature (URL) *', controller: _linkCtrl, hint: 'https://...', keyboardType: TextInputType.url),
              ],
            ),
            const SizedBox(height: ThixPolicy.s24),

            _buildSection(
              title: 'Contenu',
              icon: Icons.article_outlined,
              children: [
                _buildInputField(label: 'Description complète *', controller: _descCtrl, hint: 'Détaillez l\'opportunité ici...', maxLines: 6),
                const SizedBox(height: ThixPolicy.s24),
                const Text('Critères d\'éligibilité *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                const SizedBox(height: ThixPolicy.s8),
                ..._buildEligibilityList(),
                const SizedBox(height: ThixPolicy.s12),
                TextButton.icon(
                  onPressed: () => setState(() => _eligibilityCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Ajouter un critère'),
                  style: TextButton.styleFrom(foregroundColor: ThixPolicy.primary),
                ),
              ],
            ),
            const SizedBox(height: ThixPolicy.s40),
            
            // Bouton de soumission
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitOpportunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primaryDeep,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('PUBLIER L\'OPPORTUNITÉ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: ThixPolicy.s40),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WIDGETS FACTORY
  // ============================================================
  
  // 🌟 DESIGN PREMIUM POUR L'UPLOAD D'IMAGE
  Widget _buildImageUploadSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(
            color: _selectedImageBytes != null ? ThixPolicy.primary : ThixPolicy.borderStrong,
            width: _selectedImageBytes != null ? 2 : 1,
          ),
          image: _selectedImageBytes != null
              ? DecorationImage(
                  image: MemoryImage(_selectedImageBytes!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                )
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedImageBytes != null ? Colors.white.withOpacity(0.2) : ThixPolicy.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedImageBytes != null ? Icons.edit_rounded : Icons.add_photo_alternate_rounded,
                  color: _selectedImageBytes != null ? Colors.white : ThixPolicy.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: ThixPolicy.s12),
              Text(
                _selectedImageBytes != null ? 'Modifier la photo de couverture' : 'Ajouter une photo de couverture',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _selectedImageBytes != null ? Colors.white : ThixPolicy.primaryDeep,
                ),
              ),
              if (_selectedImageBytes == null)
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Text('Formats recommandés : JPG, PNG (Max 5MB)', style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ThixPolicy.primary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
            ],
          ),
          const SizedBox(height: ThixPolicy.s20),
          const Divider(height: 1, color: ThixPolicy.border),
          const SizedBox(height: ThixPolicy.s20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain),
          validator: isRequired ? (value) => value == null || value.trim().isEmpty ? 'Ce champ est requis' : null : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: ThixPolicy.textMuted, fontSize: 13),
            filled: true,
            fillColor: ThixPolicy.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: const BorderSide(color: ThixPolicy.danger, width: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Catégorie *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: ThixPolicy.card,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.textSecondary),
              style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
              items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date limite de candidature *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDeadline,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: _selectedDeadline == null ? ThixPolicy.textMuted : ThixPolicy.primary),
                const SizedBox(width: 10),
                Text(
                  _selectedDeadline == null ? 'Sélectionner une date' : DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDeadline!),
                  style: TextStyle(fontSize: 14, color: _selectedDeadline == null ? ThixPolicy.textMuted : ThixPolicy.textMain, fontWeight: _selectedDeadline == null ? FontWeight.normal : FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildEligibilityList() {
    return List.generate(_eligibilityCtrls.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _eligibilityCtrls[index],
                style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain),
                decoration: InputDecoration(
                  hintText: 'Ex: Être citoyen d\'un pays d\'Afrique Subsaharienne',
                  hintStyle: const TextStyle(color: ThixPolicy.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: ThixPolicy.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_eligibilityCtrls.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: ThixPolicy.danger),
                onPressed: () {
                  setState(() {
                    _eligibilityCtrls[index].dispose();
                    _eligibilityCtrls.removeAt(index);
                  });
                },
              ),
          ],
        ),
      );
    });
  }
}
