// ============================================================
// FICHIER 29 : admin/admin_media_form_page.dart
// ============================================================
// lib/presentation/mon_pays/admin/admin_media_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/province_media.dart';
import '../providers/media_provider.dart';

class AdminMediaFormPage extends ConsumerStatefulWidget {
  final String provinceId;
  final ProvinceMedia? media;
  const AdminMediaFormPage({required this.provinceId, this.media, super.key});

  @override
  ConsumerState<AdminMediaFormPage> createState() => _AdminMediaFormPageState();
}

class _AdminMediaFormPageState extends ConsumerState<AdminMediaFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _typeController;
  late TextEditingController _urlController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _achievementIdController;
  bool _isCover = false;
  bool _isEditing = false;
  String? _mediaId;

  @override
  void initState() {
    super.initState();
    final m = widget.media;
    _isEditing = m != null;
    _mediaId = m?.id;
    _typeController = TextEditingController(text: m?.type ?? 'photo');
    _urlController = TextEditingController(text: m?.url ?? '');
    _titleController = TextEditingController(text: m?.title ?? '');
    _descriptionController = TextEditingController(text: m?.description ?? '');
    _achievementIdController = TextEditingController(text: m?.achievementId ?? '');
    _isCover = m?.isCover ?? false;
  }

  @override
  void dispose() {
    _typeController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _achievementIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le média' : 'Ajouter un média'),
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
                  value: _typeController.text,
                  decoration: const InputDecoration(labelText: 'Type *'),
                  items: const [
                    DropdownMenuItem(value: 'photo', child: Text('Photo')),
                    DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                  ],
                  onChanged: (value) => _typeController.text = value!,
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'URL *'),
                  validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _achievementIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID de la réalisation associée (optionnel)',
                    hintText: 'UUID de la réalisation',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Photo de couverture'),
                  value: _isCover,
                  onChanged: (value) => setState(() => _isCover = value),
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
    final media = ProvinceMedia(
      id: _mediaId ?? '',
      provinceId: widget.provinceId,
      achievementId: _achievementIdController.text.trim().isEmpty ? null : _achievementIdController.text.trim(),
      type: _typeController.text.trim(),
      url: _urlController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      isCover: _isCover,
    );
    final notifier = ref.read(adminMediaProvider.notifier);
    try {
      if (_isEditing) {
        await notifier.updateMedia(media);
      } else {
        await notifier.createMedia(media);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Média enregistré'), backgroundColor: Colors.green),
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
