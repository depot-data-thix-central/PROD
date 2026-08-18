import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../models/media_content.dart';
import '../../../services/media_service.dart';

class AdminMediaPage extends StatefulWidget {
  const AdminMediaPage({super.key});

  @override
  State<AdminMediaPage> createState() => _AdminMediaPageState();
}

class _AdminMediaPageState extends State<AdminMediaPage> {
  late MediaService _mediaService;
  List<MediaContent> _media = [];
  bool _isLoading = true;
  String? _error;

  bool _isEditing = false;
  MediaContent? _editingItem;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _typeController = TextEditingController();
  final _yearController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _viewCountController = TextEditingController();
  final _rankPositionController = TextEditingController();
  bool _isTrending = false;
  bool _isNewRelease = false;
  bool _isRecommended = false;
  bool _isPublished = true;

  // Fichiers sélectionnés (PlatformFile pour file_picker)
  PlatformFile? _selectedCoverFile;
  PlatformFile? _selectedVideoFile;

  // Prévisualisation
  String? _previewCoverUrl;
  String? _previewVideoUrl;

  @override
  void initState() {
    super.initState();
    _mediaService = MediaService(client: Supabase.instance.client);
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    try {
      final all = await _mediaService.fetchAllMedia();
      setState(() {
        _media = all;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _previewCover(PlatformFile? file) {
    if (file == null) {
      setState(() => _previewCoverUrl = null);
      return;
    }

    if (kIsWeb && file.bytes != null) {
      final url = Uri.dataFromBytes(file.bytes!, mimeType: 'image/jpeg').toString();
      setState(() => _previewCoverUrl = url);
    } else if (file.path != null) {
      setState(() => _previewCoverUrl = file.path);
    }
  }

  void _previewVideo(PlatformFile? file) {
    if (file == null) {
      setState(() => _previewVideoUrl = null);
      return;
    }

    if (kIsWeb && file.bytes != null) {
      final url = Uri.dataFromBytes(file.bytes!, mimeType: 'video/mp4').toString();
      setState(() => _previewVideoUrl = url);
    } else if (file.path != null) {
      setState(() => _previewVideoUrl = file.path);
    }
  }

  Future<void> _pickCoverFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedCoverFile = file;
        _coverUrlController.text = file.name;
      });
      _previewCover(file);
    }
  }

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedVideoFile = file;
        _videoUrlController.text = file.name;
      });
      _previewVideo(file);
    }
  }

  Future<void> _saveMedia() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing && _editingItem != null) {
        // ✅ On passe directement les PlatformFile (le service gère l'upload)
        await _mediaService.updateWithFiles(
          _editingItem!,
          newCoverFile: _selectedCoverFile,
          newVideoFile: _selectedVideoFile,
        );
      } else {
        final newItem = MediaContent(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          title: _titleController.text,
          subtitle: _subtitleController.text,
          type: _typeController.text,
          year: _yearController.text,
          coverUrl: _coverUrlController.text,
          videoUrl: _videoUrlController.text,
          viewCount: int.tryParse(_viewCountController.text) ?? 0,
          rankPosition: _rankPositionController.text.isNotEmpty
              ? int.parse(_rankPositionController.text)
              : null,
          isTrending: _isTrending,
          isNewRelease: _isNewRelease,
          isRecommended: _isRecommended,
          isPublished: _isPublished,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _mediaService.insertWithFiles(
          newItem,
          coverFile: _selectedCoverFile,
          videoFile: _selectedVideoFile,
        );
      }

      _resetForm();
      await _loadMedia();

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Média sauvegardé avec succès !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMedia(MediaContent item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Voulez-vous vraiment supprimer "${item.title}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _mediaService.deleteMedia(item);
      await _loadMedia();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Média supprimé avec succès !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur suppression : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editMedia(MediaContent item) {
    _isEditing = true;
    _editingItem = item;
    _titleController.text = item.title;
    _subtitleController.text = item.subtitle ?? '';
    _typeController.text = item.type;
    _yearController.text = item.year ?? '';
    _coverUrlController.text = item.coverUrl;
    _videoUrlController.text = item.videoUrl;
    _viewCountController.text = item.viewCount.toString();
    _rankPositionController.text = item.rankPosition?.toString() ?? '';
    _isTrending = item.isTrending;
    _isNewRelease = item.isNewRelease;
    _isRecommended = item.isRecommended;
    _isPublished = item.isPublished;
    _selectedCoverFile = null;
    _selectedVideoFile = null;
    _previewCoverUrl = null;
    _previewVideoUrl = null;
    _showForm();
  }

  void _resetForm() {
    _isEditing = false;
    _editingItem = null;
    _titleController.clear();
    _subtitleController.clear();
    _typeController.clear();
    _yearController.clear();
    _coverUrlController.clear();
    _videoUrlController.clear();
    _viewCountController.clear();
    _rankPositionController.clear();
    _isTrending = false;
    _isNewRelease = false;
    _isRecommended = false;
    _isPublished = true;
    _selectedCoverFile = null;
    _selectedVideoFile = null;
    _previewCoverUrl = null;
    _previewVideoUrl = null;
  }

  void _showForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing ? 'Modifier le média' : 'Ajouter un média',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Titre *'),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _subtitleController,
                      decoration: const InputDecoration(labelText: 'Sous-titre'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _typeController,
                      decoration: const InputDecoration(labelText: 'Type (Musique, Film...) *'),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(labelText: 'Année'),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.image),
                        title: Text(
                          _selectedCoverFile == null
                              ? 'Aucun fichier image'
                              : _selectedCoverFile!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: kIsWeb,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              final file = result.files.first;
                              setModalState(() {
                                _selectedCoverFile = file;
                                _coverUrlController.text = file.name;
                              });
                              _previewCover(file);
                            }
                          },
                          child: const Text('Choisir'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _coverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL de couverture (si pas de fichier)',
                        hintText: 'https://...',
                      ),
                    ),

                    // Preview Cover
                    if (_previewCoverUrl != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _previewCoverUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.video_file),
                        title: Text(
                          _selectedVideoFile == null
                              ? 'Aucun fichier vidéo'
                              : _selectedVideoFile!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.video,
                              withData: kIsWeb,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              final file = result.files.first;
                              setModalState(() {
                                _selectedVideoFile = file;
                                _videoUrlController.text = file.name;
                              });
                              _previewVideo(file);
                            }
                          },
                          child: const Text('Choisir'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _videoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL vidéo (si pas de fichier)',
                        hintText: 'https://...',
                      ),
                      validator: (v) => (v == null || v.isEmpty) && _selectedVideoFile == null
                          ? 'Fichier ou URL requis'
                          : null,
                    ),

                    // Preview Video
                    if (_previewVideoUrl != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: VideoPlayerPreview(videoUrl: _previewVideoUrl!),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _viewCountController,
                      decoration: const InputDecoration(labelText: 'Nombre de vues'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _rankPositionController,
                      decoration: const InputDecoration(labelText: 'Position dans tendances (1,2,3...)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      title: const Text('Tendance'),
                      value: _isTrending,
                      onChanged: (v) => setModalState(() => _isTrending = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Nouveauté'),
                      value: _isNewRelease,
                      onChanged: (v) => setModalState(() => _isNewRelease = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Recommandé'),
                      value: _isRecommended,
                      onChanged: (v) => setModalState(() => _isRecommended = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Publié'),
                      value: _isPublished,
                      onChanged: (v) => setModalState(() => _isPublished = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: _saveMedia,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_isEditing ? 'Mettre à jour' : 'Ajouter'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur : $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMedia,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration THIX MEDIA'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _resetForm();
              _showForm();
            },
            tooltip: 'Ajouter un média',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMedia,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _media.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucun média disponible'),
                  SizedBox(height: 8),
                  Text('Appuyez sur + pour ajouter un média'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _media.length,
              itemBuilder: (context, index) {
                final item = _media[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.coverUrl.isNotEmpty
                          ? Image.network(
                              item.coverUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.movie, color: Colors.grey),
                            ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${item.type} • ${item.year ?? 'Année inconnue'} • ${item.isPublished ? 'Publié' : 'Brouillon'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editMedia(item),
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Modifier',
                        ),
                        IconButton(
                          onPressed: () => _deleteMedia(item),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _resetForm();
          _showForm();
        },
        child: const Icon(Icons.add),
        tooltip: 'Ajouter un média',
      ),
    );
  }
}

// Widget de prévisualisation vidéo
class VideoPlayerPreview extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerPreview({super.key, required this.videoUrl});

  @override
  State<VideoPlayerPreview> createState() => _VideoPlayerPreviewState();
}

class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      setState(() => _isInitialized = true);
      await _controller.play();
    } catch (e) {
      print('Erreur preview vidéo: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(_controller),
        IconButton(
          icon: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 40,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
        ),
      ],
    );
  }
}
