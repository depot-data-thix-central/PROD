// lib/presentation/admin/pages/create_news_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../providers/news_provider.dart';
import '../../../models/news_article.dart';

class CreateNewsPage extends StatefulWidget {
  final NewsArticle? article;

  const CreateNewsPage({super.key, this.article});

  @override
  State<CreateNewsPage> createState() => _CreateNewsPageState();
}

class _CreateNewsPageState extends State<CreateNewsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  
  String _selectedCategory = 'politique';
  bool _isFeatured = false;
  bool _isBreaking = false;
  DateTime _publishDate = DateTime.now();
  String? _imageUrl;
  String? _videoUrl;
  File? _imageFile;
  File? _videoFile;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isUploadingVideo = false;

  final List<Map<String, String>> _categories = [
    {'value': 'featured', 'label': 'À la une'},
    {'value': 'politique', 'label': 'Politique'},
    {'value': 'economie', 'label': 'Économie'},
    {'value': 'societe', 'label': 'Société'},
    {'value': 'tech', 'label': 'Tech'},
    {'value': 'sport', 'label': 'Sport'},
    {'value': 'culture', 'label': 'Culture'},
    {'value': 'international', 'label': 'International'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.article != null) {
      _titleController.text = widget.article!.title;
      _summaryController.text = widget.article!.summary ?? '';
      _contentController.text = widget.article!.content;
      _selectedCategory = widget.article!.category;
      _isFeatured = widget.article!.isFeatured;
      _isBreaking = widget.article!.isBreaking;
      _publishDate = widget.article!.publishedAt;
      _imageUrl = widget.article!.imageUrl;
      _videoUrl = widget.article!.videoUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() => _imageFile = File(result.files.first.path!));
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        setState(() => _videoFile = File(result.files.first.path!));
        _showSuccess('Vidéo sélectionnée : ${result.files.first.name}');
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de la vidéo');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;
    
    setState(() => _isUploadingImage = true);
    final provider = context.read<NewsProvider>();
    final url = await provider.uploadImage(_imageFile!.path);
    setState(() => _isUploadingImage = false);
    
    return url;
  }

  Future<String?> _uploadVideo() async {
    if (_videoFile == null) return _videoUrl;
    
    setState(() => _isUploadingVideo = true);
    final provider = context.read<NewsProvider>();
    final url = await provider.uploadVideo(_videoFile!.path);
    setState(() => _isUploadingVideo = false);
    
    return url;
  }

  Future<void> _saveArticle() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uploadedImageUrl = await _uploadImage();
      final uploadedVideoUrl = await _uploadVideo();
      
      final provider = context.read<NewsProvider>();
      
      if (widget.article != null) {
        await provider.updateArticle(widget.article!.id, {
          'title': _titleController.text.trim(),
          'summary': _summaryController.text.trim(),
          'content': _contentController.text.trim(),
          'category': _selectedCategory,
          'image_url': uploadedImageUrl,
          'video_url': uploadedVideoUrl,
          'is_featured': _isFeatured,
          'is_breaking': _isBreaking,
          'published_at': _publishDate.toIso8601String(),
        });
        _showSuccess('Article modifié avec succès');
      } else {
        await provider.createArticle(
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          imageUrl: uploadedImageUrl,
          videoUrl: uploadedVideoUrl,
          isFeatured: _isFeatured,
          isBreaking: _isBreaking,
        );
        _showSuccess('Article créé avec succès');
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectPublishDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _publishDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_publishDate),
      );
      if (time != null) {
        setState(() {
          _publishDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B3D),
        elevation: 0,
        title: Text(
          widget.article != null ? 'Modifier l\'article' : 'Nouvel article',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveArticle,
            child: Text(
              widget.article != null ? 'MODIFIER' : 'PUBLIER',
              style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: 16),
                    _buildVideoSection(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Titre de l\'article',
                        hintText: 'Titre accrocheur...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.trim().isEmpty == true ? 'Titre requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _summaryController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Résumé (optionnel)',
                        hintText: 'Court résumé de l\'article...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contentController,
                      maxLines: 15,
                      decoration: const InputDecoration(
                        labelText: 'Contenu',
                        hintText: 'Contenu complet de l\'article...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => v?.trim().isEmpty == true ? 'Contenu requis' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat['value'],
                          child: Text(cat['label']!, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            value: _isFeatured,
                            onChanged: (v) => setState(() => _isFeatured = v),
                            title: const Text('À la une', style: TextStyle(fontSize: 13)),
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFFD4AF37),
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            value: _isBreaking,
                            onChanged: (v) => setState(() => _isBreaking = v),
                            title: const Text('Breaking', style: TextStyle(fontSize: 13)),
                            contentPadding: EdgeInsets.zero,
                            activeColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date de publication', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${_publishDate.day}/${_publishDate.month}/${_publishDate.year} ${_publishDate.hour}:${_publishDate.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: _selectPublishDate,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image à la une', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickImage,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _isUploadingImage
                ? const Center(child: CircularProgressIndicator())
                : _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : _imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_imageUrl!, fit: BoxFit.cover, width: double.infinity),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('Ajouter une image', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
          ),
        ),
        if (_imageFile != null || _imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => setState(() {
                _imageFile = null;
                _imageUrl = null;
              }),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Supprimer l\'image', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vidéo (optionnel)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploadingVideo ? null : _pickVideo,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _isUploadingVideo
                ? const Center(child: CircularProgressIndicator())
                : _videoFile != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam, size: 40, color: Colors.green),
                            const SizedBox(height: 8),
                            Text('Vidéo prête', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                          ],
                        ),
                      )
                    : _videoUrl != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle, size: 40, color: Color(0xFFD4AF37)),
                                const SizedBox(height: 8),
                                Text('Vidéo existante', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('Ajouter une vidéo', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Text('MP4, MOV, AVI', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
          ),
        ),
        if (_videoFile != null || _videoUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => setState(() {
                _videoFile = null;
                _videoUrl = null;
              }),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Supprimer la vidéo', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}
