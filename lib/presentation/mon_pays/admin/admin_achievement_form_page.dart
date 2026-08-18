// lib/presentation/mon_pays/admin/admin_achievement_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/provincial_achievement.dart'; // Import correct
import '../providers/achievements_provider.dart';

class AdminAchievementFormPage extends ConsumerStatefulWidget {
  final String provinceId;
  final ProvincialAchievement? achievement; // <--- Changé
  const AdminAchievementFormPage({required this.provinceId, this.achievement, super.key});

  @override
  ConsumerState<AdminAchievementFormPage> createState() => _AdminAchievementFormPageState();
}

class _AdminAchievementFormPageState extends ConsumerState<AdminAchievementFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _dateController;
  late TextEditingController _coverImageUrlController;
  bool _isEditing = false;
  String? _achievementId;

  @override
  void initState() {
    super.initState();
    final a = widget.achievement;
    _isEditing = a != null;
    _achievementId = a?.id;
    _titleController = TextEditingController(text: a?.title ?? '');
    _categoryController = TextEditingController(text: a?.category ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _dateController = TextEditingController(
      text: a?.date != null ? a!.date!.toLocal().toString().split(' ')[0] : '',
    );
    _coverImageUrlController = TextEditingController(text: a?.coverImageUrl ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _coverImageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la réalisation' : 'Ajouter une réalisation'),
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
                    DropdownMenuItem(value: 'Infrastructure', child: Text('Infrastructure')),
                    DropdownMenuItem(value: 'Santé', child: Text('Santé')),
                    DropdownMenuItem(value: 'Éducation', child: Text('Éducation')),
                    DropdownMenuItem(value: 'Agriculture', child: Text('Agriculture')),
                    DropdownMenuItem(value: 'Économie', child: Text('Économie')),
                    DropdownMenuItem(value: 'Tourisme', child: Text('Tourisme')),
                    DropdownMenuItem(value: 'Culture', child: Text('Culture')),
                    DropdownMenuItem(value: 'Sport', child: Text('Sport')),
                    DropdownMenuItem(value: 'Environnement', child: Text('Environnement')),
                    DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                  ],
                  onChanged: (value) => _categoryController.text = value!,
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titre *'),
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
                  controller: _dateController,
                  decoration: const InputDecoration(labelText: 'Date (AAAA-MM-JJ)'),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coverImageUrlController,
                  decoration: const InputDecoration(labelText: 'URL de la couverture'),
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
    DateTime? date;
    try {
      if (_dateController.text.trim().isNotEmpty) {
        date = DateTime.parse(_dateController.text.trim());
      }
    } catch (_) {}

    // Remplacement ici aussi
    final achievement = ProvincialAchievement(
      id: _achievementId ?? '',
      provinceId: widget.provinceId,
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      date: date,
      coverImageUrl: _coverImageUrlController.text.trim().isEmpty ? null : _coverImageUrlController.text.trim(),
    );
    
    final notifier = ref.read(adminAchievementsProvider.notifier);
    try {
      if (_isEditing) {
        await notifier.updateAchievement(achievement);
      } else {
        await notifier.createAchievement(achievement);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réalisation enregistrée'), backgroundColor: Colors.green),
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
