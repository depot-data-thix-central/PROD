// lib/presentation/mon_pays/admin/admin_news_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thix_id/models/news_article.dart';
import '../providers/news_provider.dart';

class AdminNewsFormPage extends ConsumerStatefulWidget {
  final NewsArticle? article; // Null si c'est un nouvel article
  const AdminNewsFormPage({super.key, this.article});

  @override
  ConsumerState<AdminNewsFormPage> createState() => _AdminNewsFormPageState();
}

class _AdminNewsFormPageState extends ConsumerState<AdminNewsFormPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _contentController;
  late TextEditingController _authorController;
  
  String _category = 'Général';
  String? _coverImageUrl;
  
  bool _isEditing = false;
  String? _articleId;
  bool _isBusy = false;

  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color redThix = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _isEditing = a != null;
    _articleId = a?.id;

    _titleController = TextEditingController(text: a?.title ?? '');
    _summaryController = TextEditingController(text: a?.summary ?? '');
    _contentController = TextEditingController(text: a?.content ?? '');
    _authorController = TextEditingController(text: a?.author ?? '');
    
    if (a != null && a.category.isNotEmpty) {
      _category = a.category;
    }
    _coverImageUrl = a?.coverImageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // Fonction pour uploader l'image de couverture
  Future<void> _uploadCoverImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.first.bytes != null) {
        setState(() => _isBusy = true);
        final file = result.files.first;
        final fileName = 'news_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final path = 'covers/$fileName';
        
        // ⚠️ Assurez-vous d'avoir créé un bucket 'news_media' dans Supabase
        await Supabase.instance.client.storage.from('news_media').uploadBinary(path, file.bytes!, fileOptions: const FileOptions(upsert: true));
        final url = Supabase.instance.client.storage.from('news_media').getPublicUrl(path);
        
        setState(() {
          _coverImageUrl = url;
          _isBusy = false;
        });
      }
    } catch (e) {
      setState(() => _isBusy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur Image : $e'), backgroundColor: Colors.red));
    }
  }

    void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);

    try {
      final article = NewsArticle(
        id: _articleId ?? '',
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim().isEmpty ? null : _summaryController.text.trim(),
        content: _contentController.text.trim(),
        category: _category,
        // ✅ On utilise les bons noms attendus par le constructeur :
        createdBy: _authorController.text.trim().isEmpty ? null : _authorController.text.trim(),
        imageUrl: _coverImageUrl,
        publishedAt: _isEditing ? (widget.article?.publishedAt ?? DateTime.now()) : DateTime.now(),
        createdAt: _isEditing ? (widget.article?.createdAt ?? DateTime.now()) : DateTime.now(), // ✅ createdAt est obligatoire !
      );

      await ref.read(newsServiceProvider).saveNews(article);
      ref.invalidate(newsProvider); // Met à jour la liste

      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Actualité publiée !'), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur : $e'), backgroundColor: Colors.red));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier l\'actualité' : 'Rédiger une actualité', style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: navyDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- IMAGE DE COUVERTURE ---
                  const Text('Image de couverture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyDeep)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _uploadCoverImage,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _coverImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(imageUrl: _coverImageUrl!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text('Ajouter une image', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CONTENU ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: _inputDecoration('Catégorie', Icons.category),
                          items: const [
                            DropdownMenuItem(value: 'Général', child: Text('Général')),
                            DropdownMenuItem(value: 'Politique', child: Text('Politique')),
                            DropdownMenuItem(value: 'Économie', child: Text('Économie')),
                            DropdownMenuItem(value: 'Société', child: Text('Société')),
                            DropdownMenuItem(value: 'Infrastructures', child: Text('Infrastructures')),
                          ],
                          onChanged: (v) => setState(() => _category = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration('Titre de l\'article *', Icons.title),
                          validator: (v) => v == null || v.isEmpty ? 'Titre requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _summaryController,
                          decoration: _inputDecoration('Résumé (Optionnel)', Icons.short_text),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contentController,
                          decoration: _inputDecoration('Contenu de l\'article *', Icons.article),
                          maxLines: 8,
                          validator: (v) => v == null || v.isEmpty ? 'Contenu requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _authorController,
                          decoration: _inputDecoration('Auteur (ex: Gouvernement RDC)', Icons.person),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isBusy ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: navyDeep,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isEditing ? 'Mettre à jour' : 'Publier', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navyDeep, width: 2)),
    );
  }
}
