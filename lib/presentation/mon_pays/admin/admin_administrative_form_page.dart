// ============================================================
// FICHIER 27 : admin/admin_administrative_form_page.dart
// ============================================================
// lib/presentation/mon_pays/admin/admin_administrative_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/province_administrative.dart';
import '../providers/provinces_provider.dart';

class AdminAdministrativeFormPage extends ConsumerStatefulWidget {
  final String provinceId;
  final ProvinceAdministrativeDivision? division;
  const AdminAdministrativeFormPage({required this.provinceId, this.division, super.key});

  @override
  ConsumerState<AdminAdministrativeFormPage> createState() => _AdminAdministrativeFormPageState();
}

class _AdminAdministrativeFormPageState extends ConsumerState<AdminAdministrativeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _populationController;
  bool _isEditing = false;
  String? _divisionId;

  @override
  void initState() {
    super.initState();
    final d = widget.division;
    _isEditing = d != null;
    _divisionId = d?.id;
    _nameController = TextEditingController(text: d?.name ?? '');
    _typeController = TextEditingController(text: d?.type ?? '');
    _populationController = TextEditingController(text: d?.population?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _populationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la division' : 'Ajouter une division'),
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
                  value: _typeController.text.isNotEmpty ? _typeController.text : null,
                  decoration: const InputDecoration(labelText: 'Type *'),
                  items: const [
                    DropdownMenuItem(value: 'territoire', child: Text('Territoire')),
                    DropdownMenuItem(value: 'secteur', child: Text('Secteur')),
                    DropdownMenuItem(value: 'chefferie', child: Text('Chefferie')),
                  ],
                  onChanged: (value) => _typeController.text = value!,
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
                  controller: _populationController,
                  decoration: const InputDecoration(labelText: 'Population'),
                  keyboardType: TextInputType.number,
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
    final division = ProvinceAdministrativeDivision(
      id: _divisionId ?? '',
      provinceId: widget.provinceId,
      type: _typeController.text.trim(),
      name: _nameController.text.trim(),
      population: int.tryParse(_populationController.text.trim()),
    );
    final service = ref.read(provincesServiceProvider);
    try {
      if (_isEditing) {
        await service.updateAdministrativeDivision(division);
      } else {
        await service.addAdministrativeDivision(division);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Division administrative enregistrée'), backgroundColor: Colors.green),
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
