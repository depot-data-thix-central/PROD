// ============================================================
// FICHIER 23 : admin/admin_economic_form_page.dart
// ============================================================
// lib/presentation/mon_pays/admin/admin_economic_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/province_economic.dart';
import '../providers/provinces_provider.dart';

class AdminEconomicFormPage extends ConsumerStatefulWidget {
  final String provinceId;
  final ProvinceEconomicResource? resource;
  const AdminEconomicFormPage({required this.provinceId, this.resource, super.key});

  @override
  ConsumerState<AdminEconomicFormPage> createState() => _AdminEconomicFormPageState();
}

class _AdminEconomicFormPageState extends ConsumerState<AdminEconomicFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconUrlController;
  bool _isKeySector = false;
  bool _isEditing = false;
  String? _resourceId;

  @override
  void initState() {
    super.initState();
    final r = widget.resource;
    _isEditing = r != null;
    _resourceId = r?.id;
    _nameController = TextEditingController(text: r?.name ?? '');
    _categoryController = TextEditingController(text: r?.category ?? '');
    _descriptionController = TextEditingController(text: r?.description ?? '');
    _iconUrlController = TextEditingController(text: r?.iconUrl ?? '');
    _isKeySector = r?.isKeySector ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _iconUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la ressource' : 'Ajouter une ressource'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                  decoration: const InputDecoration(labelText: 'Catégorie *'),
                  items: const [
                    DropdownMenuItem(value: 'minerais', child: Text('Minerais')),
                    DropdownMenuItem(value: 'agriculture', child: Text('Agriculture')),
                    DropdownMenuItem(value: 'hydrographie', child: Text('Hydrographie')),
                    DropdownMenuItem(value: 'energie', child: Text('Énergie')),
                    DropdownMenuItem(value: 'industrie', child: Text('Industrie')),
                    DropdownMenuItem(value: 'services', child: Text('Services')),
                  ],
                  onChanged: (value) => _categoryController.text = value!,
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _iconUrlController,
                  decoration: const InputDecoration(labelText: 'URL de l\'icône'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Secteur clé pour l\'investissement'),
                  value: _isKeySector,
                  onChanged: (value) => setState(() => _isKeySector = value),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isEditing ? 'Modifier' : 'Ajouter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final resource = ProvinceEconomicResource(
      id: _resourceId ?? '',
      provinceId: widget.provinceId,
      category: _categoryController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      iconUrl: _iconUrlController.text.trim().isEmpty ? null : _iconUrlController.text.trim(),
      isKeySector: _isKeySector,
    );
    final service = ref.read(provincesServiceProvider);
    try {
      if (_isEditing) {
        await service.updateEconomicResource(resource);
      } else {
        await service.addEconomicResource(resource);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ressource enregistrée'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
