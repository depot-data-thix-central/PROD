import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/presentation/network/communities_list_page.dart';

class CreateCommunityPage extends ConsumerStatefulWidget {
  const CreateCommunityPage({super.key});
  @override
  ConsumerState<CreateCommunityPage> createState() => _CreateCommunityPageState();
}

class _CreateCommunityPageState extends ConsumerState<CreateCommunityPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  Uint8List? _selectedLogoBytes;
  String? _selectedLogoExtension;
  bool _isUploading = false;
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final size = file.bytes?.length ?? file.size;
      if (size > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('L\'image ne doit pas dépasser 5MB'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      setState(() {
        _selectedLogoBytes = file.bytes;
        _selectedLogoExtension = file.extension ?? 'jpg';
      });
    }
  }

  Future<void> _createCommunity() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nom'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      String? bannerUrl;
      if (_selectedLogoBytes != null) {
        setState(() => _isUploading = true);
        bannerUrl = await ref.read(networkServiceProvider).uploadImageBytes(
              _selectedLogoBytes!,
              fileExtension: _selectedLogoExtension!,
            );
        setState(() => _isUploading = false);
      }

      await ref.read(networkServiceProvider).createCommunity(
            name: name,
            description: _descriptionController.text.trim(),
            bannerUrl: bannerUrl,
          );

      // scalable : invalide AVANT pop
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(allCommunitiesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Communauté créée !'), backgroundColor: Colors.green),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isCreating = false;
          _isUploading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCreating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isCreating) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Création en cours...')));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text('Créer une communauté', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A2E))),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: _isCreating ? null : () => context.pop()),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createCommunity,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: _isCreating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Stack(children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                    color: Colors.white,
                    image: _selectedLogoBytes != null ? DecorationImage(image: MemoryImage(_selectedLogoBytes!), fit: BoxFit.cover) : null,
                  ),
                  child: _selectedLogoBytes == null ? const Center(child: Icon(Icons.groups, size: 50, color: Color(0xFFD4AF37))) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isCreating ? null : _pickLogo,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _isCreating ? Colors.grey : const Color(0xFFD4AF37), shape: BoxShape.circle),
                      child: _isUploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('Nom *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(controller: _nameController, enabled: !_isCreating, decoration: const InputDecoration(hintText: 'Ex: THIX Innovators', border: OutlineInputBorder(), prefixIcon: Icon(Icons.groups))),
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(controller: _descriptionController, maxLines: 4, enabled: !_isCreating, decoration: const InputDecoration(hintText: 'Objectif...', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ),
          ]),
        ),
      ),
    );
  }
}
