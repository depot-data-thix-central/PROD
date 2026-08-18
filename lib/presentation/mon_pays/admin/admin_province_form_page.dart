// lib/presentation/mon_pays/admin/admin_province_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/province.dart';
import '../models/city.dart';
import '../models/province_economic.dart';
import '../models/province_tourism.dart';
import '../models/province_emergency.dart';
import '../models/province_administrative.dart';
import '../models/province_government.dart';
import '../providers/provinces_provider.dart';

class AdminProvinceFormPage extends ConsumerStatefulWidget {
  final Province? province;
  const AdminProvinceFormPage({super.key, this.province});

  @override
  ConsumerState<AdminProvinceFormPage> createState() => _AdminProvinceFormPageState();
}

class _AdminProvinceFormPageState extends ConsumerState<AdminProvinceFormPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _capitalController;
  late TextEditingController _regionController;
  late TextEditingController _areaController;
  late TextEditingController _populationController;
  late TextEditingController _descriptionController;

  late TextEditingController _historyController;
  late TextEditingController _climateController;
  late TextEditingController _infrastructureController;
  late TextEditingController _educationController;

  String? _coverImageUrl;
  String? _coatOfArmsUrl;
  String? _mapUrl;
  late TextEditingController _websiteController;

  late TextEditingController _governorController;
  String? _governorPhotoUrl;
  late TextEditingController _viceGovernorController;
  String? _viceGovernorPhotoUrl;
  
  List<Map<String, dynamic>> _ministers = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _economicSectors = [];
  List<Map<String, dynamic>> _tourismSites = [];
  List<Map<String, dynamic>> _emergencyContacts = [];
  List<Map<String, dynamic>> _administrativeDivisions = [];
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _tribes = [];
  List<Map<String, dynamic>> _galleryMedia = [];

  ProvinceGovernment? _government;

  late TextEditingController _languagesController;
  late TextEditingController _resourcesController;
  late TextEditingController _territoriesCountController;
  
  bool _isEditing = false;
  String? _provinceId;
  bool _isBusy = false; 
  bool _isLoadingFullData = false; // <-- NOUVEAU : État de chargement

  int _keyCounter = 0;
  String _newKey() => 'k${_keyCounter++}_${DateTime.now().microsecondsSinceEpoch}';

  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color redThix = Color(0xFFD32F2F);
  static const Color lightBg = Color(0xFFF6F7FB);

  @override
  void initState() {
    super.initState();
    final p = widget.province;
    _isEditing = p != null;
    _provinceId = p?.id;
    
    // 1. Initialiser les contrôleurs (Vides par défaut)
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _capitalController = TextEditingController();
    _regionController = TextEditingController();
    _areaController = TextEditingController();
    _populationController = TextEditingController();
    _descriptionController = TextEditingController();
    _historyController = TextEditingController();
    _climateController = TextEditingController();
    _infrastructureController = TextEditingController();
    _educationController = TextEditingController();
    _websiteController = TextEditingController();
    _governorController = TextEditingController();
    _viceGovernorController = TextEditingController();
    _languagesController = TextEditingController();
    _resourcesController = TextEditingController();
    _territoriesCountController = TextEditingController();

    // 2. Remplir avec les données initiales (légères)
    if (p != null) {
      _populateData(p);
    }

    // 3. Lancer le téléchargement des données complètes
    if (_isEditing && _provinceId != null) {
      _loadFullData();
    }
  }

  // =========================================================================
  // FONCTION : Remplit le formulaire avec les données de la province
  // =========================================================================
  void _populateData(Province p) {
    _nameController.text = p.name;
    _codeController.text = p.code;
    _capitalController.text = p.capital;
    
    String safeRegion = p.region.trim();
    if (safeRegion.isNotEmpty) safeRegion = safeRegion[0].toUpperCase() + safeRegion.substring(1).toLowerCase();
    final validRegions = ['Centre', 'Est', 'Ouest', 'Nord', 'Sud'];
    if (!validRegions.contains(safeRegion)) safeRegion = 'Centre';
    _regionController.text = safeRegion;

    _areaController.text = p.area?.toString() ?? '';
    _populationController.text = p.population?.toString() ?? '';
    _descriptionController.text = p.description ?? '';
    _historyController.text = p.history ?? '';
    _climateController.text = p.climate ?? '';
    _infrastructureController.text = p.infrastructure ?? '';
    _educationController.text = p.education ?? '';
    _websiteController.text = p.website ?? '';
    _governorController.text = p.governor ?? '';
    _viceGovernorController.text = p.viceGovernor ?? '';
    _languagesController.text = p.languages ?? '';
    _resourcesController.text = p.resources ?? '';
    _territoriesCountController.text = p.territoriesCount?.toString() ?? '';

    _coverImageUrl = p.coverImageUrl;
    _coatOfArmsUrl = p.coatOfArmsUrl;
    _mapUrl = p.mapUrl;
    _governorPhotoUrl = p.governorPhotoUrl;
    _viceGovernorPhotoUrl = p.viceGovernorPhotoUrl;
    _government = p.government;

    _ministers = p.ministers?.map<Map<String, dynamic>>((m) => <String, dynamic>{'_localKey': _newKey(), 'name': m['name'] ?? '', 'role': m['role'] ?? '', 'photo_url': m['photoUrl'] ?? m['photo_url'] ?? ''}).toList() ?? <Map<String, dynamic>>[];
    
    _cities = p.cities.map<Map<String, dynamic>>((c) => <String, dynamic>{
      '_localKey': _newKey(),
      'id': c.id, 'province_id': c.provinceId, 'name': c.name, 'population': c.population?.toString() ?? '',
      'is_capital': c.isCapital, 'mayor': c.mayor ?? '', 'mayor_photo_url': c.mayorPhotoUrl ?? '',
      'media': c.media != null ? List<Map<String, dynamic>>.from(c.media!) : <Map<String, dynamic>>[],
    }).toList();

    _economicSectors = p.economicResources.map<Map<String, dynamic>>((e) => <String, dynamic>{
      '_localKey': _newKey(),
      'id': e.id, 'province_id': e.provinceId, 'name': e.name, 'description': e.description ?? '',
      'media': e.media != null ? List<Map<String, dynamic>>.from(e.media!) : <Map<String, dynamic>>[],
    }).toList();

    _tourismSites = p.tourismSites.map<Map<String, dynamic>>((t) => <String, dynamic>{
      '_localKey': _newKey(),
      'id': t.id, 'province_id': t.provinceId, 'name': t.name, 'type': t.type, 'description': t.description ?? '',
      'media': t.media != null ? List<Map<String, dynamic>>.from(t.media!) : <Map<String, dynamic>>[],
    }).toList();

    _emergencyContacts = p.emergencyContacts.map<Map<String, dynamic>>((e) => <String, dynamic>{
      '_localKey': _newKey(),
      'id': e.id, 'province_id': e.provinceId, 'service': e.service, 'phone': e.phone
    }).toList();
    
    _administrativeDivisions = p.administrativeDivisions.map<Map<String, dynamic>>((a) => <String, dynamic>{
      '_localKey': _newKey(),
      'id': a.id, 'province_id': a.provinceId, 'type': a.type, 'name': a.name, 'capital': a.capital ?? '', 
      'population': a.population?.toString() ?? '', 'area': a.area?.toString() ?? '', 'administrator': a.administrator ?? '',
      'media': a.media != null ? List<Map<String, dynamic>>.from(a.media!) : <Map<String, dynamic>>[],
    }).toList();

    _achievements = p.achievements?.map<Map<String, dynamic>>((a) => <String, dynamic>{
      '_localKey': _newKey(),
      'title': a['title'] ?? '', 'description': a['description'] ?? '', 'date': a['date'] ?? '', 'location': a['location'] ?? '',
      'media': a['media'] != null ? List<Map<String, dynamic>>.from(a['media']) : <Map<String, dynamic>>[],
    }).toList() ?? <Map<String, dynamic>>[];

    _tribes = p.tribes?.map<Map<String, dynamic>>((tr) => <String, dynamic>{
      '_localKey': _newKey(),
      'name': tr['name'] ?? '', 'zone': tr['zone'] ?? '', 'history': tr['history'] ?? '',
      'media': tr['media'] != null ? List<Map<String, dynamic>>.from(tr['media']) : <Map<String, dynamic>>[],
    }).toList() ?? <Map<String, dynamic>>[];

    _galleryMedia = p.galleryMedia?.map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m)).toList() ?? <Map<String, dynamic>>[];
  }

  // =========================================================================
  // FONCTION : Télécharge la version complète de la province
  // =========================================================================
  Future<void> _loadFullData() async {
    setState(() => _isLoadingFullData = true);
    try {
      final fullProvince = await ref.read(provinceWithAllRelationsProvider(_provinceId!).future);
      if (mounted) {
        setState(() {
          _populateData(fullProvince); // On remplace par les données complètes
          _isLoadingFullData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFullData = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Impossible de charger les détails complets : $e'), backgroundColor: Colors.orange));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose(); _codeController.dispose(); _capitalController.dispose();
    _regionController.dispose(); _areaController.dispose(); _populationController.dispose();
    _descriptionController.dispose(); _historyController.dispose(); _climateController.dispose();
    _infrastructureController.dispose(); _educationController.dispose(); _websiteController.dispose();
    _governorController.dispose(); _viceGovernorController.dispose(); _languagesController.dispose();
    _resourcesController.dispose(); _territoriesCountController.dispose();
    super.dispose();
  }

  Future<void> _uploadMultiFiles(String folderName, Function(String url, String type) onUploaded) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.media, allowMultiple: true, withData: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() => _isBusy = true);
        for (var file in result.files) {
          if (file.bytes != null) {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final path = '$folderName/$fileName';
            final ext = file.extension?.toLowerCase() ?? '';
            final type = (ext == 'mp4' || ext == 'mov' || ext == 'avi') ? 'video' : 'photo';
            await Supabase.instance.client.storage.from('provinces').uploadBinary(path, file.bytes!, fileOptions: const FileOptions(upsert: true));
            final url = Supabase.instance.client.storage.from('provinces').getPublicUrl(path);
            onUploaded(url, type);
          }
        }
        setState(() => _isBusy = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Médias ajoutés !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isBusy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur Médias : $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _uploadSingleFile(String folderName, Function(String url) onUploaded) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.first.bytes != null) {
        setState(() => _isBusy = true);
        final file = result.files.first;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final path = '$folderName/$fileName';
        await Supabase.instance.client.storage.from('provinces').uploadBinary(path, file.bytes!, fileOptions: const FileOptions(upsert: true));
        final url = Supabase.instance.client.storage.from('provinces').getPublicUrl(path);
        onUploaded(url);
        setState(() => _isBusy = false);
      }
    } catch (e) {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(title: Text(_isEditing ? 'Modifier la province' : 'Nouvelle province', style: const TextStyle(fontWeight: FontWeight.w700)), backgroundColor: redThix, foregroundColor: Colors.white, elevation: 0),
      body: Stack(
        children: [
          // NOUVEAU : Affichage d'un loader pendant le téléchargement des relations
          if (_isLoadingFullData)
            const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: navyDeep), SizedBox(height: 16), Text("Récupération des données...", style: TextStyle(fontWeight: FontWeight.bold))]))
          else
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionCard(title: 'Identité de la province', icon: Icons.badge, children: [
                      _buildTextField(_nameController, 'Nom de la province *', Icons.map_outlined, validator: _requiredValidator), const SizedBox(height: 12),
                      Row(children: [ Expanded(child: _buildTextField(_codeController, 'Code (ex: KIN) *', Icons.tag, validator: _requiredValidator, isUppercase: true)), const SizedBox(width: 12), Expanded(child: _buildTextField(_capitalController, 'Capitale *', Icons.location_city, validator: _requiredValidator)) ]), const SizedBox(height: 12),
                      DropdownButtonFormField<String>(value: _regionController.text.isNotEmpty ? _regionController.text : 'Centre', decoration: _inputDecoration('Région géographique *', Icons.explore), items: const [DropdownMenuItem(value: 'Centre', child: Text('Centre')), DropdownMenuItem(value: 'Est', child: Text('Est')), DropdownMenuItem(value: 'Ouest', child: Text('Ouest')), DropdownMenuItem(value: 'Nord', child: Text('Nord')), DropdownMenuItem(value: 'Sud', child: Text('Sud'))], onChanged: (value) => _regionController.text = value ?? 'Centre', validator: (v) => v == null ? 'Champ requis' : null),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Histoire, Climat & Infrastructures', icon: Icons.history_edu, children: [
                      _buildTextField(_historyController, 'Historique complet & Origines', Icons.menu_book, maxLines: 4), const SizedBox(height: 12),
                      _buildTextField(_climateController, 'Climat, Relief & Environnement', Icons.wb_sunny, maxLines: 3), const SizedBox(height: 12),
                      _buildTextField(_infrastructureController, 'Infrastructures, Transports & Énergie', Icons.bolt, maxLines: 3), const SizedBox(height: 12),
                      _buildTextField(_educationController, 'Éducation, Recherche & Santé', Icons.school, maxLines: 3),
                    ]), const SizedBox(height: 16),
                    
                    _buildSectionCard(title: 'Gouvernance & Exécutif Provincial', icon: Icons.account_balance, children: [
                      _buildTextField(_governorController, 'Nom du Gouverneur', Icons.person), const SizedBox(height: 8),
                      _buildImagePickerRow('Photo du Gouverneur', _governorPhotoUrl, 'governors', (url) => setState(() => _governorPhotoUrl = url)), const SizedBox(height: 16),
                      _buildTextField(_viceGovernorController, 'Nom du Vice-Gouverneur', Icons.person_outline), const SizedBox(height: 8),
                      _buildImagePickerRow('Photo du Vice-Gouverneur', _viceGovernorPhotoUrl, 'governors', (url) => setState(() => _viceGovernorPhotoUrl = url)), const SizedBox(height: 16),
                      _buildTextField(_territoriesCountController, 'Nombre de territoires / Villes', Icons.format_list_numbered, isNumber: true),
                      const Divider(height: 32),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('Ministres', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyDeep)), ElevatedButton.icon(onPressed: () => setState(() => _ministers.add(<String, dynamic>{'_localKey': _newKey(), 'name': '', 'role': '', 'photo_url': ''})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white)) ]),
                      const SizedBox(height: 12),
                      ..._ministers.asMap().entries.map((entry) {
                        int index = entry.key; var minister = entry.value;
                        return Container(
                          key: ValueKey(minister['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(children: [
                            Row(children: [Text('Ministre #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.delete, color: redThix, size: 20), onPressed: () => setState(() => _ministers.removeAt(index)))]),
                            TextFormField(initialValue: minister['name'], onChanged: (v) => _ministers[index]['name'] = v, decoration: _inputDecoration('Nom complet', Icons.person)), const SizedBox(height: 8),
                            TextFormField(initialValue: minister['role'], onChanged: (v) => _ministers[index]['role'] = v, decoration: _inputDecoration('Portefeuille / Rôle', Icons.work)), const SizedBox(height: 8),
                            _buildImagePickerRow('Photo du Ministre', minister['photo_url'], 'ministers', (url) => setState(() => _ministers[index]['photo_url'] = url)),
                          ]),
                        );
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Culture, Langues & Peuples', icon: Icons.people, children: [
                      _buildTextField(_languagesController, 'Langues parlées', Icons.chat_bubble_outline), const SizedBox(height: 12),
                      _buildTextField(_resourcesController, 'Ressources principales', Icons.diamond), const SizedBox(height: 12),
                      _buildTextField(_descriptionController, 'Description générale & Traditions', Icons.description, maxLines: 3),
                      const Divider(height: 32),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('Peuples & Tribus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyDeep)), ElevatedButton.icon(onPressed: () => setState(() => _tribes.add(<String, dynamic>{'_localKey': _newKey(), 'name': '', 'zone': '', 'history': '', 'media': <Map<String, dynamic>>[]})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white)) ]),
                      const SizedBox(height: 12),
                      ..._tribes.asMap().entries.map((entry) {
                        int index = entry.key; var tribe = entry.value;
                        return Container(
                          key: ValueKey(tribe['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(children: [
                            Row(children: [Text('Tribu #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.delete, color: redThix, size: 20), onPressed: () => setState(() => _tribes.removeAt(index)))]),
                            TextFormField(initialValue: tribe['name'], onChanged: (v) => _tribes[index]['name'] = v, decoration: _inputDecoration('Nom de la tribu', Icons.group)), const SizedBox(height: 8),
                            TextFormField(initialValue: tribe['zone'], onChanged: (v) => _tribes[index]['zone'] = v, decoration: _inputDecoration('Zone / Territoire', Icons.place)), const SizedBox(height: 8),
                            TextFormField(initialValue: tribe['history'], onChanged: (v) => _tribes[index]['history'] = v, maxLines: 2, decoration: _inputDecoration('Histoire & coutumes', Icons.menu_book)), const SizedBox(height: 8),
                            _buildMultiMediaGallery('Galerie', tribe['media'], 'tribes', () => setState((){})),
                          ]),
                        );
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Villes Principales', icon: Icons.location_city, children: [
                      Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () => setState(() => _cities.add(<String, dynamic>{'_localKey': _newKey(), 'id': null, 'province_id': _provinceId, 'name': '', 'population': '', 'is_capital': false, 'mayor': '', 'mayor_photo_url': '', 'media': <Map<String, dynamic>>[]})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter une ville'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white))),
                      const SizedBox(height: 12),
                      ..._cities.asMap().entries.map((entry) {
                        int index = entry.key; var city = entry.value;
                        return Container(
                          key: ValueKey(city['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Text('Ville #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Switch(value: city['is_capital'] ?? false, onChanged: (v) => setState(() => _cities[index]['is_capital'] = v), activeColor: redThix), const Text('Chef-lieu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.delete, color: redThix, size: 20), onPressed: () => setState(() => _cities.removeAt(index)))]),
                            TextFormField(initialValue: city['name'], onChanged: (v) => _cities[index]['name'] = v, decoration: _inputDecoration('Nom de la ville', Icons.location_city)), const SizedBox(height: 8),
                            TextFormField(initialValue: city['population'], onChanged: (v) => _cities[index]['population'] = v, keyboardType: TextInputType.number, decoration: _inputDecoration('Population', Icons.groups)), const SizedBox(height: 8),
                            _buildMultiMediaGallery('Galerie', city['media'], 'cities', () => setState((){})), const Divider(height: 20),
                            TextFormField(initialValue: city['mayor'], onChanged: (v) => _cities[index]['mayor'] = v, decoration: _inputDecoration('Maire / Bourgmestre', Icons.person)), const SizedBox(height: 8),
                            _buildImagePickerRow('Photo de l\'autorité', city['mayor_photo_url'], 'mayors', (url) => setState(() => _cities[index]['mayor_photo_url'] = url)),
                          ]),
                        );
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Économie & Secteurs Clés', icon: Icons.monetization_on, children: [
                      Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () => setState(() => _economicSectors.add(<String, dynamic>{'_localKey': _newKey(), 'id': null, 'province_id': _provinceId, 'name': '', 'description': '', 'media': <Map<String, dynamic>>[]})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter un secteur'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white))),
                      const SizedBox(height: 12),
                      ..._economicSectors.asMap().entries.map((entry) {
                        int index = entry.key; var sector = entry.value;
                        return Container(
                          key: ValueKey(sector['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(children: [
                            Row(children: [Text('Secteur #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.delete, color: redThix, size: 20), onPressed: () => setState(() => _economicSectors.removeAt(index)))]),
                            TextFormField(initialValue: sector['name'], onChanged: (v) => _economicSectors[index]['name'] = v, decoration: _inputDecoration('Nom du secteur', Icons.business)), const SizedBox(height: 8),
                            TextFormField(initialValue: sector['description'], onChanged: (v) => _economicSectors[index]['description'] = v, maxLines: 2, decoration: _inputDecoration('Détails', Icons.notes)), const SizedBox(height: 8),
                            _buildMultiMediaGallery('Galerie', sector['media'], 'economy', () => setState((){})),
                          ]),
                        );
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Tourisme & Sites Remarquables', icon: Icons.landscape, children: [
                      Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () => setState(() => _tourismSites.add(<String, dynamic>{'_localKey': _newKey(), 'id': null, 'province_id': _provinceId, 'name': '', 'type': '', 'description': '', 'media': <Map<String, dynamic>>[]})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter un site'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white))),
                      const SizedBox(height: 12),
                      ..._tourismSites.asMap().entries.map((entry) {
                        int index = entry.key; var site = entry.value;
                        return Container(
                          key: ValueKey(site['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(children: [
                            Row(children: [Text('Site #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.delete, color: redThix, size: 20), onPressed: () => setState(() => _tourismSites.removeAt(index)))]),
                            TextFormField(initialValue: site['name'], onChanged: (v) => _tourismSites[index]['name'] = v, decoration: _inputDecoration('Nom du site', Icons.place)), const SizedBox(height: 8),
                            TextFormField(initialValue: site['type'], onChanged: (v) => _tourismSites[index]['type'] = v, decoration: _inputDecoration('Type (Parc, Cascade...)', Icons.category)), const SizedBox(height: 8),
                            TextFormField(initialValue: site['description'], onChanged: (v) => _tourismSites[index]['description'] = v, maxLines: 2, decoration: _inputDecoration('Description', Icons.description)), const SizedBox(height: 8),
                            _buildMultiMediaGallery('Galerie', site['media'], 'tourism', () => setState((){})),
                          ]),
                        );
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Découpage Administratif (Détaillé)', icon: Icons.dashboard_customize, children: [
                      Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () => setState(() => _administrativeDivisions.add(<String, dynamic>{'_localKey': _newKey(), 'id': null, 'province_id': _provinceId, 'type': 'Territoire', 'name': '', 'capital': '', 'population': '', 'area': '', 'administrator': '', 'media': <Map<String, dynamic>>[]})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter une division'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white))),
                      const SizedBox(height: 12),
                      ..._administrativeDivisions.asMap().entries.map((entry) {
                        int index = entry.key; var div = entry.value;
                        return Container(
                          key: ValueKey(div['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(children: [
                            Row(children: [Text('Division #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.delete, color: redThix, size: 20), onPressed: () => setState(() => _administrativeDivisions.removeAt(index)))]),
                            Row(children: [Expanded(child: TextFormField(initialValue: div['type'], onChanged: (v) => _administrativeDivisions[index]['type'] = v, decoration: _inputDecoration('Type', Icons.category))), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: div['name'], onChanged: (v) => _administrativeDivisions[index]['name'] = v, decoration: _inputDecoration('Nom', Icons.place)))]), const SizedBox(height: 8),
                            TextFormField(initialValue: div['capital'], onChanged: (v) => _administrativeDivisions[index]['capital'] = v, decoration: _inputDecoration('Chef-lieu', Icons.star)), const SizedBox(height: 8),
                            Row(children: [Expanded(child: TextFormField(initialValue: div['population'], onChanged: (v) => _administrativeDivisions[index]['population'] = v, keyboardType: TextInputType.number, decoration: _inputDecoration('Population', Icons.groups))), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: div['area'], onChanged: (v) => _administrativeDivisions[index]['area'] = v, keyboardType: TextInputType.number, decoration: _inputDecoration('Superficie', Icons.map)))]), const SizedBox(height: 8),
                            TextFormField(initialValue: div['administrator'], onChanged: (v) => _administrativeDivisions[index]['administrator'] = v, decoration: _inputDecoration('Administrateur', Icons.person)), const SizedBox(height: 8),
                            _buildMultiMediaGallery('Galerie', div['media'], 'admin_divisions', () => setState((){})),
                          ]),
                        );
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Réalisations Majeures', icon: Icons.emoji_events, children: [
                      Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () => setState(() => _achievements.add(<String, dynamic>{'_localKey': _newKey(), 'title': '', 'description': '', 'date': '', 'location': '', 'media': <Map<String, dynamic>>[]})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white))),
                      const SizedBox(height: 12),
                      ..._achievements.asMap().entries.map((entry) {
                        int index = entry.key; var ach = entry.value;
                        return Container(
                          key: ValueKey(ach['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(children: [
                            Row(children: [Text('Projet #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.delete, color: redThix, size: 20), onPressed: () => setState(() => _achievements.removeAt(index)))]),
                            TextFormField(initialValue: ach['title'], onChanged: (v) => _achievements[index]['title'] = v, decoration: _inputDecoration('Titre du projet', Icons.title)), const SizedBox(height: 8),
                            Row(children: [Expanded(child: TextFormField(initialValue: ach['date'], onChanged: (v) => _achievements[index]['date'] = v, decoration: _inputDecoration('Date', Icons.calendar_today))), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: ach['location'], onChanged: (v) => _achievements[index]['location'] = v, decoration: _inputDecoration('Lieu', Icons.location_on)))]), const SizedBox(height: 8),
                            TextFormField(initialValue: ach['description'], onChanged: (v) => _achievements[index]['description'] = v, maxLines: 2, decoration: _inputDecoration('Description', Icons.description)), const SizedBox(height: 8),
                            _buildMultiMediaGallery('Galerie', ach['media'], 'achievements', () => setState((){})),
                          ]),
                        );
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Urgences & Contacts', icon: Icons.emergency, children: [
                      Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () => setState(() => _emergencyContacts.add(<String, dynamic>{'_localKey': _newKey(), 'id': null, 'province_id': _provinceId, 'service': '', 'phone': ''})), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white))),
                      const SizedBox(height: 12),
                      ..._emergencyContacts.asMap().entries.map((entry) {
                        int index = entry.key; var emergency = entry.value;
                        return Container(
                          key: ValueKey(emergency['_localKey'] ?? index),
                          margin: const EdgeInsets.only(bottom: 8), child: Row(children: [
                          Expanded(child: TextFormField(initialValue: emergency['service'], onChanged: (v) => _emergencyContacts[index]['service'] = v, decoration: _inputDecoration('Service', Icons.local_hospital))), const SizedBox(width: 8),
                          Expanded(child: TextFormField(initialValue: emergency['phone'], onChanged: (v) => _emergencyContacts[index]['phone'] = v, decoration: _inputDecoration('Numéro', Icons.phone))),
                          IconButton(icon: const Icon(Icons.delete, color: redThix), onPressed: () => setState(() => _emergencyContacts.removeAt(index))),
                        ]));
                      }),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Galerie Média Globale', icon: Icons.perm_media, children: [
                      _buildMultiMediaGallery('Tous les médias', _galleryMedia, 'gallery', () => setState((){})),
                    ]), const SizedBox(height: 16),

                    _buildSectionCard(title: 'Identité Visuelle Officielle', icon: Icons.image, children: [
                      _buildImagePickerRow('Photo de couverture', _coverImageUrl, 'covers', (url) => setState(() => _coverImageUrl = url)), const SizedBox(height: 12),
                      _buildImagePickerRow('Blason / Armoiries', _coatOfArmsUrl, 'emblems', (url) => setState(() => _coatOfArmsUrl = url)), const SizedBox(height: 12),
                      _buildImagePickerRow('Carte géographique', _mapUrl, 'maps', (url) => setState(() => _mapUrl = url)), const SizedBox(height: 12),
                      _buildTextField(_websiteController, 'Site Web officiel', Icons.language),
                    ]), const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isBusy ? null : _save,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: navyDeep, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                      child: Text(_isEditing ? 'Enregistrer les modifications' : 'Créer la province', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          
          if (_isBusy) Container(color: Colors.black.withOpacity(0.4), child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildMultiMediaGallery(String label, List<dynamic> mediaList, String folder, VoidCallback onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyDeep)), const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ...mediaList.asMap().entries.map((entry) {
              int idx = entry.key; var m = entry.value;
              bool isVideo = m['type'] == 'video';
              return Stack(
                children: [
                  Container(
                    width: 70, height: 70, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isVideo
                          ? const Icon(Icons.videocam, color: Colors.grey, size: 30)
                          : Image.network(
                              m['url'],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                              },
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 24),
                            ),
                    ),
                  ),
                  Positioned(right: 0, top: 0, child: GestureDetector(onTap: () { mediaList.removeAt(idx); onUpdate(); }, child: Container(decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, size: 12, color: Colors.white)))),
                ],
              );
            }),
            InkWell(
              onTap: () => _uploadMultiFiles(folder, (url, type) { mediaList.add(<String, dynamic>{'url': url, 'type': type}); onUpdate(); }),
              child: Container(width: 70, height: 70, decoration: BoxDecoration(color: navyDeep.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: navyDeep.withOpacity(0.3), style: BorderStyle.solid)), child: const Icon(Icons.add_a_photo, color: navyDeep)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePickerRow(String label, String? currentUrl, String folderName, Function(String url) onUpdated) {
    final hasImg = currentUrl != null && currentUrl.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: hasImg
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    currentUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                    },
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                  ),
                )
              : const Icon(Icons.image_outlined, color: Colors.grey, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyDeep)), Text(hasImg ? 'Image chargée' : 'Aucune image', style: TextStyle(fontSize: 11, color: hasImg ? Colors.green.shade700 : Colors.grey))])),
        ElevatedButton.icon(onPressed: () => _uploadSingleFile(folderName, onUpdated), icon: const Icon(Icons.upload, size: 16), label: const Text('Choisir'), style: ElevatedButton.styleFrom(backgroundColor: navyDeep, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
      ]),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: navyDeep, size: 22), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navyDeep))]), const Divider(height: 24, thickness: 1), ...children]));
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {String? Function(String?)? validator, bool isNumber = false, bool isUppercase = false, int maxLines = 1}) {
    return TextFormField(controller: controller, decoration: _inputDecoration(label, icon), validator: validator, maxLines: maxLines, keyboardType: isNumber ? TextInputType.number : TextInputType.text, inputFormatters: [if (isNumber) FilteringTextInputFormatter.digitsOnly, if (isUppercase) TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()))]);
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navyDeep, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
  }

  String? _requiredValidator(String? value) => (value == null || value.trim().isEmpty) ? 'Requis' : null;
  
  void _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez remplir les champs obligatoires (avec *).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);

    try {
      // === Mapping des listes ===
      List<City> mappedCities = _cities.map((c) {
        final popStr = c['population']?.toString().trim() ?? '';
        return City.fromJson({
          'id': c['id']?.toString().isNotEmpty == true ? c['id'] : null,
          'province_id': _provinceId,
          'name': c['name'] ?? '',
          'population': popStr.isNotEmpty ? popStr : null,
          'is_capital': c['is_capital'] ?? false,
          'mayor': c['mayor'],
          'mayor_photo_url': c['mayor_photo_url'],
          'media': c['media'] ?? [],
        });
      }).toList();

      List<ProvinceEconomicResource> mappedEconomy = _economicSectors.map((e) {
        return ProvinceEconomicResource.fromJson({
          'id': e['id']?.toString().isNotEmpty == true ? e['id'] : null,
          'province_id': _provinceId,
          'name': e['name'] ?? '',
          'description': e['description'],
          'media': e['media'] ?? [],
        });
      }).toList();

      List<ProvinceTourism> mappedTourism = _tourismSites.map((t) {
        return ProvinceTourism.fromJson({
          'id': t['id']?.toString().isNotEmpty == true ? t['id'] : null,
          'province_id': _provinceId,
          'name': t['name'] ?? '',
          'type': t['type'] ?? '',
          'description': t['description'],
          'media': t['media'] ?? [],
        });
      }).toList();

      List<ProvinceAdministrativeDivision> mappedAdmin = _administrativeDivisions.map((a) {
        final popStr = a['population']?.toString().trim() ?? '';
        final areaStr = a['area']?.toString().trim() ?? '';
        return ProvinceAdministrativeDivision.fromJson({
          'id': a['id']?.toString().isNotEmpty == true ? a['id'] : null,
          'province_id': _provinceId,
          'type': a['type'] ?? 'Territoire',
          'name': a['name'] ?? '',
          'capital': a['capital'],
          'population': popStr.isNotEmpty ? int.tryParse(popStr) : null,
          'area': areaStr.isNotEmpty ? num.tryParse(areaStr) : null,
          'administrator': a['administrator'],
          'media': a['media'] ?? [],
        });
      }).toList();

      List<ProvinceEmergencyContact> mappedEmergency = _emergencyContacts.map((e) {
        return ProvinceEmergencyContact.fromJson({
          'id': e['id']?.toString().isNotEmpty == true ? e['id'] : null,
          'province_id': _provinceId,
          'service': e['service'],
          'phone': e['phone'],
        });
      }).toList();

      // === Construction de la Province ===
      final province = Province(
        id: _provinceId ?? '',
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        capital: _capitalController.text.trim(),
        region: _regionController.text.trim(),
        area: int.tryParse(_areaController.text.trim()),
        population: int.tryParse(_populationController.text.trim()),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        history: _historyController.text.trim().isEmpty ? null : _historyController.text.trim(),
        climate: _climateController.text.trim().isEmpty ? null : _climateController.text.trim(),
        infrastructure: _infrastructureController.text.trim().isEmpty ? null : _infrastructureController.text.trim(),
        education: _educationController.text.trim().isEmpty ? null : _educationController.text.trim(),
        coverImageUrl: _coverImageUrl,
        coatOfArmsUrl: _coatOfArmsUrl,
        mapUrl: _mapUrl,
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        governor: _governorController.text.trim().isEmpty ? null : _governorController.text.trim(),
        governorPhotoUrl: _governorPhotoUrl,
        viceGovernor: _viceGovernorController.text.trim().isEmpty ? null : _viceGovernorController.text.trim(),
        viceGovernorPhotoUrl: _viceGovernorPhotoUrl,
        government: _government,
        ministers: _ministers.where((m) => (m['name'] ?? '').trim().isNotEmpty).toList(),
        cities: mappedCities,
        economicResources: mappedEconomy,
        tourismSites: mappedTourism,
        emergencyContacts: mappedEmergency,
        administrativeDivisions: mappedAdmin,
        achievements: _achievements.where((a) => (a['title'] ?? '').trim().isNotEmpty).toList(),
        tribes: _tribes.where((t) => (t['name'] ?? '').trim().isNotEmpty).toList(),
        galleryMedia: _galleryMedia,
        languages: _languagesController.text.trim().isEmpty ? null : _languagesController.text.trim(),
        resources: _resourcesController.text.trim().isEmpty ? null : _resourcesController.text.trim(),
        territoriesCount: int.tryParse(_territoriesCountController.text.trim()),
      );

      // === Sauvegarde complète (Gérée par le provider) ===
      final service = ref.read(provincesServiceProvider);
      await service.saveProvinceWithRelations(province);

      // Rafraîchir les providers pour que les modifications apparaissent
      ref.invalidate(provincesProvider);
      ref.invalidate(adminProvincesProvider);
      if (_provinceId != null) {
        ref.invalidate(provinceWithAllRelationsProvider(_provinceId!));
      }

      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Province et toutes les données enregistrées avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 12),
            action: SnackBarAction(
              label: 'Fermer',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }
}
