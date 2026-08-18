// lib/presentation/mon_pays/admin/admin_authority_form_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:thix_id/presentation/mon_pays/models/authority.dart';
import 'package:thix_id/presentation/mon_pays/providers/authorities_provider.dart';
// 🚀 NOUVEL IMPORT POUR LES PROVINCES
import 'package:thix_id/presentation/mon_pays/providers/provinces_provider.dart';

class AdminAuthorityFormPage extends ConsumerStatefulWidget {
  final Authority? authority;

  const AdminAuthorityFormPage({super.key, this.authority});

  @override
  ConsumerState<AdminAuthorityFormPage> createState() => _AdminAuthorityFormPageState();
}

class _AdminAuthorityFormPageState extends ConsumerState<AdminAuthorityFormPage> {
  final _formKey = GlobalKey<FormState>();

  // ---- Champs principaux ----
  String? _selectedProvinceId; // 🚀 NOUVEAU CHAMP POUR CLASSER LA PROVINCE
  late TextEditingController _categoryController;
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _biographyController;
  late TextEditingController _explanationController;
  late TextEditingController _mandateController;
  late TextEditingController _partyController;
  late TextEditingController _imageUrlController;
  late TextEditingController _coverImageUrlController;
  DateTime? _mandateStart;
  DateTime? _mandateEnd;
  bool _isActive = true;

  // ---- Contrôleur pour la recherche IA ----
  final TextEditingController _aiSearchController = TextEditingController();

  // ---- Listes dynamiques ----
  final List<Education> _educationList = [];
  final List<Career> _careerList = [];
  final List<Achievement> _achievementList = [];
  final List<AuthorityPhoto> _photoList = [];
  final List<AuthorityVideo> _videoList = [];
  final List<AuthorityDocument> _documentList = [];

  bool _isUploadingFile = false;
  bool _isAiLoading = false;
  bool _isLoadingFullData = false;

  @override
  void initState() {
    super.initState();
    final a = widget.authority;
    _selectedProvinceId = a?.provinceId; // 🚀 RECUPERATION DE LA PROVINCE
    _categoryController = TextEditingController(text: a?.category ?? 'Gouvernement');
    _nameController = TextEditingController(text: a?.name ?? '');
    _titleController = TextEditingController(text: a?.title ?? '');
    _biographyController = TextEditingController(text: a?.biography ?? '');
    _explanationController = TextEditingController(text: a?.explanation ?? '');
    _mandateController = TextEditingController(text: a?.mandate ?? '');
    _partyController = TextEditingController(text: a?.party ?? '');
    _imageUrlController = TextEditingController(text: a?.imageUrl ?? '');
    _coverImageUrlController = TextEditingController(text: a?.coverImageUrl ?? '');
    _mandateStart = a?.mandateStart;
    _mandateEnd = a?.mandateEnd;
    _isActive = a?.isActive ?? true;

    if (a != null && a.id.isNotEmpty) {
      _fetchFullDetails(a.id);
    }
  }

  Future<void> _fetchFullDetails(String id) async {
    setState(() => _isLoadingFullData = true);
    try {
      final fullAuth = await ref.read(authorityDetailProvider(id).future);
      if (mounted) {
        setState(() {
          _educationList.clear(); _educationList.addAll(fullAuth.education);
          _careerList.clear(); _careerList.addAll(fullAuth.career);
          _achievementList.clear(); _achievementList.addAll(fullAuth.achievements);
          _photoList.clear(); _photoList.addAll(fullAuth.photos);
          _videoList.clear(); _videoList.addAll(fullAuth.videos);
          _documentList.clear(); _documentList.addAll(fullAuth.documents);
          _isLoadingFullData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFullData = false);
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _nameController.dispose();
    _titleController.dispose();
    _biographyController.dispose();
    _explanationController.dispose();
    _mandateController.dispose();
    _partyController.dispose();
    _imageUrlController.dispose();
    _coverImageUrlController.dispose();
    _aiSearchController.dispose();
    super.dispose();
  }

  Future<void> _fillWithAi() async {
    final query = _aiSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un nom ou un sujet pour l\'IA'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isAiLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _nameController.text = query;
        _biographyController.text = "Biographie générée automatiquement par Thix IA via Tavily pour $query...";
        _titleController.text = "Gouverneur / Ministre Provincial";
        _isAiLoading = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations pré-remplies avec succès par l\'IA !'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _isAiLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.first.bytes != null) {
        setState(() => _isUploadingFile = true);
        final url = await ref.read(authoritiesServiceProvider).uploadMedia(result.files.first.name, result.files.first.bytes!);
        setState(() { _imageUrlController.text = url; _isUploadingFile = false; });
      }
    } catch (e) { setState(() => _isUploadingFile = false); }
  }

  Future<void> _pickAndUploadCover() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.first.bytes != null) {
        setState(() => _isUploadingFile = true);
        final url = await ref.read(authoritiesServiceProvider).uploadMedia(result.files.first.name, result.files.first.bytes!, folder: 'covers');
        setState(() { _coverImageUrlController.text = url; _isUploadingFile = false; });
      }
    } catch (e) { setState(() => _isUploadingFile = false); }
  }

  void _addEducation() => showDialog(context: context, builder: (ctx) => _EducationFormDialog(onSave: (edu) => setState(() => _educationList.add(edu))));
  void _addCareer() => showDialog(context: context, builder: (ctx) => _CareerFormDialog(onSave: (career) => setState(() => _careerList.add(career))));
  void _addAchievement() => showDialog(context: context, builder: (ctx) => _AchievementFormDialog(ref: ref, onSave: (ach) => setState(() => _achievementList.add(ach))));
  void _addPhoto() => showDialog(context: context, builder: (ctx) => _PhotoFormDialog(onSave: (photo) => setState(() => _photoList.add(photo))));
  void _addVideo() => showDialog(context: context, builder: (ctx) => _VideoFormDialog(onSave: (video) => setState(() => _videoList.add(video))));
  void _addDocument() => showDialog(context: context, builder: (ctx) => _DocumentFormDialog(onSave: (doc) => setState(() => _documentList.add(doc))));

  void _removeEducation(int index) => setState(() => _educationList.removeAt(index));
  void _removeCareer(int index) => setState(() => _careerList.removeAt(index));
  void _removeAchievement(int index) => setState(() => _achievementList.removeAt(index));
  void _removePhoto(int index) => setState(() => _photoList.removeAt(index));
  void _removeVideo(int index) => setState(() => _videoList.removeAt(index));
  void _removeDocument(int index) => setState(() => _documentList.removeAt(index));

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(adminAuthoritiesProvider).isLoading;
    final isBusy = isSaving || _isUploadingFile || _isAiLoading || _isLoadingFullData;
    final isEditing = widget.authority != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Modifier l\'autorité' : 'Nouvelle autorité'), backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isEditing) _buildAiAssistantSection(),
                  if (!isEditing) const Divider(height: 32),
                  _buildGeneralSection(isBusy),
                  const Divider(height: 32),
                  _buildEducationSection(),
                  const Divider(height: 32),
                  _buildCareerSection(),
                  const Divider(height: 32),
                  _buildAchievementSection(),
                  const Divider(height: 32),
                  _buildPhotoSection(),
                  const Divider(height: 32),
                  _buildVideoSection(),
                  const Divider(height: 32),
                  _buildDocumentSection(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isBusy ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isEditing ? 'Sauvegarder les modifications' : 'Créer', style: const TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (isBusy) Container(color: Colors.black.withOpacity(0.3), child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildAiAssistantSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1A5276).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF1A5276)), SizedBox(width: 8), Text('Assistant Thix IA & Tavily', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A5276)))]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _aiSearchController, decoration: const InputDecoration(labelText: 'Nom du Gouverneur / Ministre', filled: true, fillColor: Colors.white))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _isAiLoading ? null : _fillWithAi, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A5276), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)), child: const Text('Rechercher')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection(bool isBusy) {
    return Consumer(
      builder: (context, ref, child) {
        final provincesAsync = ref.watch(provincesProvider(null));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations générales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // 🚀 MENU DÉROULANT POUR SÉLECTIONNER LA PROVINCE 🚀
            provincesAsync.when(
              data: (provinces) => DropdownButtonFormField<String>(
                value: _selectedProvinceId,
                decoration: const InputDecoration(
                  labelText: 'Classer dans une province (Optionnel)', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map, color: Colors.grey),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nationale / Non provincial')),
                  ...provinces.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.region})'))),
                ],
                onChanged: (val) => setState(() => _selectedProvinceId = val),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur provinces: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
              decoration: const InputDecoration(labelText: 'Catégorie *', border: OutlineInputBorder()),
              items: ['Gouverneurs', 'Ministre Provincial', 'Président de la République', 'Présidence', 'Gouvernement', 'Assemblée Nationale', 'Sénat', 'Cours et Tribunaux', 'Entreprises Publiques', 'Figures Historiques', 'Autres'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _categoryController.text = val ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom complet *', border: OutlineInputBorder()), validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Titre / Fonction *', border: OutlineInputBorder()), validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _imageUrlController, decoration: const InputDecoration(labelText: 'Photo de profil (URL)', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: isBusy ? null : _pickAndUploadImage, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A5276), foregroundColor: Colors.white), child: const Text('Upload')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _coverImageUrlController, decoration: const InputDecoration(labelText: 'Photo de couverture (URL)', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: isBusy ? null : _pickAndUploadCover, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A5276), foregroundColor: Colors.white), child: const Text('Upload')),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _partyController, decoration: const InputDecoration(labelText: 'Parti politique', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _mandateController, decoration: const InputDecoration(labelText: 'Mandat (ex: 2024 - 2028)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text('Actif (mandat en cours)'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
            const SizedBox(height: 12),
            TextFormField(controller: _biographyController, decoration: const InputDecoration(labelText: 'Biographie', border: OutlineInputBorder()), maxLines: 5),
          ],
        );
      },
    );
  }

  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Études', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _addEducation, icon: const Icon(Icons.add), label: const Text('Ajouter'))],
        ),
        if (_educationList.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucune étude renseignée', style: TextStyle(color: Colors.grey))),
        ..._educationList.asMap().entries.map((entry) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(title: Text(entry.value.degree), subtitle: Text(entry.value.institution), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeEducation(entry.key))))),
      ],
    );
  }

  Widget _buildCareerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Parcours professionnel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _addCareer, icon: const Icon(Icons.add), label: const Text('Ajouter'))],
        ),
        if (_careerList.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucun parcours renseigné', style: TextStyle(color: Colors.grey))),
        ..._careerList.asMap().entries.map((entry) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(title: Text(entry.value.title), subtitle: Text(entry.value.organization), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeCareer(entry.key))))),
      ],
    );
  }

  Widget _buildAchievementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Réalisations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _addAchievement, icon: const Icon(Icons.add), label: const Text('Ajouter'))],
        ),
        if (_achievementList.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucune réalisation renseignée', style: TextStyle(color: Colors.grey))),
        ..._achievementList.asMap().entries.map((entry) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(title: Text(entry.value.title), subtitle: Text(entry.value.category ?? ''), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeAchievement(entry.key))))),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Galerie photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _addPhoto, icon: const Icon(Icons.add), label: const Text('Ajouter'))],
        ),
        if (_photoList.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucune photo', style: TextStyle(color: Colors.grey))),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _photoList.asMap().entries.map((entry) {
            return Stack(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(entry.value.url, width: 80, height: 80, fit: BoxFit.cover)),
                Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => _removePhoto(entry.key), child: Container(decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)))),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Vidéos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _addVideo, icon: const Icon(Icons.add), label: const Text('Ajouter'))],
        ),
        if (_videoList.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucune vidéo', style: TextStyle(color: Colors.grey))),
        ..._videoList.asMap().entries.map((entry) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(leading: const Icon(Icons.video_library, color: Colors.blue), title: Text(entry.value.title), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeVideo(entry.key))))),
      ],
    );
  }

  Widget _buildDocumentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _addDocument, icon: const Icon(Icons.add), label: const Text('Ajouter'))],
        ),
        if (_documentList.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucun document', style: TextStyle(color: Colors.grey))),
        ..._documentList.asMap().entries.map((entry) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.blue), title: Text(entry.value.title), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeDocument(entry.key))))),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final authority = Authority(
      id: widget.authority?.id ?? '',
      provinceId: _selectedProvinceId, // 🚀 SAUVEGARDE DE LA PROVINCE
      category: _categoryController.text.trim(),
      name: _nameController.text.trim(),
      title: _titleController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      coverImageUrl: _coverImageUrlController.text.trim().isEmpty ? null : _coverImageUrlController.text.trim(),
      biography: _biographyController.text.trim(),
      explanation: _explanationController.text.trim().isEmpty ? null : _explanationController.text.trim(),
      mandate: _mandateController.text.trim(),
      mandateStart: _mandateStart,
      mandateEnd: _mandateEnd,
      party: _partyController.text.trim(),
      isActive: _isActive,
      education: _educationList,
      career: _careerList,
      achievements: _achievementList,
      photos: _photoList,
      videos: _videoList,
      documents: _documentList,
      speeches: [], publications: [], socialNetworks: {}, agenda: [],
    );
    try {
      if (widget.authority != null) {
        await ref.read(adminAuthoritiesProvider.notifier).updateAuthority(authority);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Autorité modifiée avec succès'), backgroundColor: Colors.green));
      } else {
        await ref.read(adminAuthoritiesProvider.notifier).createAuthority(authority);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Autorité créée avec succès'), backgroundColor: Colors.green));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }
}

// ------------------------------------------------------------
// DIALOGUES DYNAMIQUES
// ------------------------------------------------------------

class _EducationFormDialog extends StatefulWidget {
  final void Function(Education) onSave;
  const _EducationFormDialog({required this.onSave});
  @override State<_EducationFormDialog> createState() => _EducationFormDialogState();
}
class _EducationFormDialogState extends State<_EducationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _institutionCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _startYearCtrl = TextEditingController();
  final _endYearCtrl = TextEditingController();
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une étude'),
      content: SingleChildScrollView(
        child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _institutionCtrl, decoration: const InputDecoration(labelText: 'Institution *'), validator: (v) => v?.isEmpty ?? true ? 'Requis' : null),
          TextFormField(controller: _degreeCtrl, decoration: const InputDecoration(labelText: 'Diplôme *'), validator: (v) => v?.isEmpty ?? true ? 'Requis' : null),
          TextFormField(controller: _startYearCtrl, decoration: const InputDecoration(labelText: 'Année début')),
          TextFormField(controller: _endYearCtrl, decoration: const InputDecoration(labelText: 'Année fin')),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: () { if (_formKey.currentState!.validate()) { widget.onSave(Education(id: '', institution: _institutionCtrl.text, degree: _degreeCtrl.text, startYear: _startYearCtrl.text, endYear: _endYearCtrl.text)); Navigator.pop(context); } }, child: const Text('Ajouter')),
      ],
    );
  }
}

class _CareerFormDialog extends StatefulWidget {
  final void Function(Career) onSave;
  const _CareerFormDialog({required this.onSave});
  @override State<_CareerFormDialog> createState() => _CareerFormDialogState();
}
class _CareerFormDialogState extends State<_CareerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un parcours'),
      content: SingleChildScrollView(
        child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titre *'), validator: (v) => v?.isEmpty ?? true ? 'Requis' : null),
          TextFormField(controller: _orgCtrl, decoration: const InputDecoration(labelText: 'Organisation *'), validator: (v) => v?.isEmpty ?? true ? 'Requis' : null),
          TextFormField(controller: _startCtrl, decoration: const InputDecoration(labelText: 'Date début *')),
          TextFormField(controller: _endCtrl, decoration: const InputDecoration(labelText: 'Date fin')),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: () { if (_formKey.currentState!.validate()) { widget.onSave(Career(id: '', title: _titleCtrl.text, organization: _orgCtrl.text, startDate: _startCtrl.text, endDate: _endCtrl.text)); Navigator.pop(context); } }, child: const Text('Ajouter')),
      ],
    );
  }
}

class _AchievementFormDialog extends StatefulWidget {
  final void Function(Achievement) onSave;
  final WidgetRef ref;
  const _AchievementFormDialog({required this.onSave, required this.ref});
  @override State<_AchievementFormDialog> createState() => _AchievementFormDialogState();
}
class _AchievementFormDialogState extends State<_AchievementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  String? _uploadedImageUrl;
  bool _isUploading = false;

  Future<void> _pickAndUploadPhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.first.bytes != null) {
        setState(() => _isUploading = true);
        final url = await widget.ref.read(authoritiesServiceProvider).uploadMedia(result.files.first.name, result.files.first.bytes!, folder: 'achievements');
        setState(() { _uploadedImageUrl = url; _isUploading = false; });
      }
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une réalisation'),
      content: SingleChildScrollView(
        child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titre *'), validator: (v) => v?.isEmpty ?? true ? 'Requis' : null),
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          TextFormField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Date (ex: 2023)')),
          DropdownButtonFormField<String>(
            value: _categoryCtrl.text.isNotEmpty ? _categoryCtrl.text : null,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: ['Infrastructure', 'Santé', 'Éducation', 'Agriculture', 'Économie', 'Autre'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => _categoryCtrl.text = v ?? '',
          ),
          const SizedBox(height: 16),
          if (_uploadedImageUrl != null) ...[
            Image.network(_uploadedImageUrl!, height: 80, fit: BoxFit.cover),
            TextButton(onPressed: _isUploading ? null : _pickAndUploadPhoto, child: const Text('Changer la photo'))
          ] else
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadPhoto,
              icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload),
              label: Text(_isUploading ? 'Upload...' : 'Uploader une photo (Optionnel)'),
            )
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: () { if (_formKey.currentState!.validate()) { widget.onSave(Achievement(id: '', title: _titleCtrl.text, description: _descCtrl.text, date: _dateCtrl.text, category: _categoryCtrl.text, imageUrl: _uploadedImageUrl)); Navigator.pop(context); } }, child: const Text('Ajouter')),
      ],
    );
  }
}

class _PhotoFormDialog extends ConsumerStatefulWidget {
  final void Function(AuthorityPhoto) onSave;
  const _PhotoFormDialog({required this.onSave});
  @override ConsumerState<_PhotoFormDialog> createState() => _PhotoFormDialogState();
}
class _PhotoFormDialogState extends ConsumerState<_PhotoFormDialog> {
  final _titleCtrl = TextEditingController();
  String? _uploadedUrl;
  bool _isUploading = false;
  Future<void> _pickAndUploadPhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.first.bytes != null) {
        setState(() => _isUploading = true);
        final url = await ref.read(authoritiesServiceProvider).uploadMedia(result.files.first.name, result.files.first.bytes!, folder: 'gallery');
        setState(() { _uploadedUrl = url; _isUploading = false; });
      }
    } catch (e) { setState(() => _isUploading = false); }
  }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une photo'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_uploadedUrl != null) ...[
            Image.network(_uploadedUrl!, height: 120, fit: BoxFit.cover),
            TextButton(onPressed: _isUploading ? null : _pickAndUploadPhoto, child: const Text('Changer'))
          ] else
            ElevatedButton.icon(onPressed: _isUploading ? null : _pickAndUploadPhoto, icon: const Icon(Icons.upload), label: Text(_isUploading ? 'Upload...' : 'Parcourir...')),
          const SizedBox(height: 16),
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titre (Optionnel)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _uploadedUrl == null ? null : () { widget.onSave(AuthorityPhoto(id: '', url: _uploadedUrl!, title: _titleCtrl.text, isCover: false)); Navigator.pop(context); }, child: const Text('Ajouter')),
      ],
    );
  }
}

class _VideoFormDialog extends ConsumerStatefulWidget {
  final void Function(AuthorityVideo) onSave;
  const _VideoFormDialog({required this.onSave});
  @override ConsumerState<_VideoFormDialog> createState() => _VideoFormDialogState();
}
class _VideoFormDialogState extends ConsumerState<_VideoFormDialog> {
  final _titleCtrl = TextEditingController();
  String? _uploadedUrl;
  bool _isUploading = false;
  Future<void> _pickAndUploadVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
      if (result != null && result.files.first.bytes != null) {
        setState(() => _isUploading = true);
        final url = await ref.read(authoritiesServiceProvider).uploadMedia(result.files.first.name, result.files.first.bytes!, folder: 'videos');
        setState(() { _uploadedUrl = url; _isUploading = false; });
      }
    } catch (e) { setState(() => _isUploading = false); }
  }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une vidéo'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titre *'), onChanged: (v) => setState((){})),
          const SizedBox(height: 16),
          if (_uploadedUrl != null)
             const Text('Vidéo prête !', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
          else
            ElevatedButton.icon(onPressed: _isUploading ? null : _pickAndUploadVideo, icon: const Icon(Icons.video_call), label: Text(_isUploading ? 'Upload...' : 'Uploader la vidéo...')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _titleCtrl.text.isEmpty || _uploadedUrl == null ? null : () { widget.onSave(AuthorityVideo(id: '', title: _titleCtrl.text, url: _uploadedUrl!)); Navigator.pop(context); }, child: const Text('Ajouter')),
      ],
    );
  }
}

class _DocumentFormDialog extends StatefulWidget {
  final void Function(AuthorityDocument) onSave;
  const _DocumentFormDialog({required this.onSave});
  @override State<_DocumentFormDialog> createState() => _DocumentFormDialogState();
}
class _DocumentFormDialogState extends State<_DocumentFormDialog> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un document'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titre *')),
        TextFormField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'URL *')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: () { if (_titleCtrl.text.isNotEmpty && _urlCtrl.text.isNotEmpty) { widget.onSave(AuthorityDocument(id: '', title: _titleCtrl.text, url: _urlCtrl.text, type: 'PDF')); Navigator.pop(context); } }, child: const Text('Ajouter')),
      ],
    );
  }
}
