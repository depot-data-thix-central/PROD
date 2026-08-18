// ============================================================
// 📁 lib/presentation/chat/profile/edit_chat_profile_page.dart
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/chat/chat_user.dart';
import '../../../providers/chat/chat_settings_provider.dart';

class EditChatProfilePage extends StatefulWidget {
  final ChatUser user;

  const EditChatProfilePage({super.key, required this.user});

  @override
  State<EditChatProfilePage> createState() => _EditChatProfilePageState();
}

class _EditChatProfilePageState extends State<EditChatProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _statusController;
  File? _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _statusController = TextEditingController(text: widget.user.status ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => _selectedImage = File(result.path));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom est requis')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<ChatSettingsProvider>();

    String? avatarUrl = widget.user.avatarUrl;
    if (_selectedImage != null) {
      final url = await provider.uploadAvatar(_selectedImage!);
      if (url != null) avatarUrl = url;
    }

    final updatedUser = widget.user.copyWith(
      displayName: _nameController.text.trim(),
      status: _statusController.text.trim().isEmpty ? null : _statusController.text.trim(),
      avatarUrl: avatarUrl,
    );

    final success = await provider.updateChatUser(updatedUser);

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour ✅'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${provider.error}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (widget.user.avatarUrl != null
                            ? NetworkImage(widget.user.avatarUrl!)
                            : null),
                    child: _selectedImage == null && widget.user.avatarUrl == null
                        ? Text(
                            widget.user.displayName.isNotEmpty
                                ? widget.user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom d\'affichage',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _statusController,
              decoration: const InputDecoration(
                labelText: 'Statut / Bio',
                hintText: 'Ex: En ligne, Au travail...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.user.username != null)
              ListTile(
                title: const Text('THIX ID'),
                subtitle: Text('@${widget.user.username}'),
                leading: const Icon(Icons.alternate_email_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
