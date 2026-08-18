// ============================================================
// FICHIER 26 : admin/admin_emergency_form_page.dart
// ============================================================
// lib/presentation/mon_pays/admin/admin_emergency_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/province_emergency.dart';
import '../providers/provinces_provider.dart';

class AdminEmergencyFormPage extends ConsumerStatefulWidget {
  final String provinceId;
  final ProvinceEmergencyContact? contact;
  const AdminEmergencyFormPage({required this.provinceId, this.contact, super.key});

  @override
  ConsumerState<AdminEmergencyFormPage> createState() => _AdminEmergencyFormPageState();
}

class _AdminEmergencyFormPageState extends ConsumerState<AdminEmergencyFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serviceController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isEditing = false;
  String? _contactId;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _isEditing = c != null;
    _contactId = c?.id;
    _serviceController = TextEditingController(text: c?.service ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le contact d\'urgence' : 'Ajouter un contact d\'urgence'),
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
                  value: _serviceController.text.isNotEmpty ? _serviceController.text : null,
                  decoration: const InputDecoration(labelText: 'Service *'),
                  items: const [
                    DropdownMenuItem(value: 'Police provinciale', child: Text('Police provinciale')),
                    DropdownMenuItem(value: 'Protection Civile', child: Text('Protection Civile')),
                    DropdownMenuItem(value: 'Hôpital de référence', child: Text('Hôpital de référence')),
                    DropdownMenuItem(value: 'Pompiers', child: Text('Pompiers')),
                    DropdownMenuItem(value: 'Ambulance', child: Text('Ambulance')),
                  ],
                  onChanged: (value) => _serviceController.text = value!,
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Numéro de téléphone *'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                  maxLines: 2,
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
    final contact = ProvinceEmergencyContact(
      id: _contactId ?? '',
      provinceId: widget.provinceId,
      service: _serviceController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
    );
    final service = ref.read(provincesServiceProvider);
    try {
      if (_isEditing) {
        await service.updateEmergencyContact(contact);
      } else {
        await service.addEmergencyContact(contact);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact d\'urgence enregistré'), backgroundColor: Colors.green),
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
