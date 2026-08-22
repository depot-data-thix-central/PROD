// lib/presentation/thix_media/create_post_page.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/media_service.dart';
import '../../models/media_content.dart';
import 'camera_capture_page.dart';
import 'video_preview_editor_page.dart';

// ============================================================================
// PALETTE — Charte Premium THIX / TDIA
// ============================================================================
class _CreateColors {
  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const primary = Color(0xFF2D6CDF);
  static const whiteAccent = Colors.white;
  static const whiteMuted = Color(0xFFE2E8F0);
  static const cardLight = Color(0xFF16294D);
  static const border = Color(0x1AFFFFFF);
  static const textMuted = Color(0xFFAEB9D4);
  static const danger = Color(0xFFE0453C);

  static const gradientWhite = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, whiteMuted],
  );
}

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  PlatformFile? _selectedVideo;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;

  // ── Épisodes (uniquement pour le format "Série") ──
  final List<PlatformFile> _episodeFiles = [];
  
  // Contrôleurs de preview pour les épisodes de séries
  final Map<int, VideoPlayerController> _episodeControllers = {};

  String _selectedContentType = 'Fil';
  bool _isPaid = false;
  String _selectedFilter = 'Normal';
  final List<String> _filters = ['Normal', 'Cinématique', 'Éclat', 'Vintage', 'Cyberpunk', 'Beauté Douce'];

  bool get _isSeries => _selectedContentType == 'Série';

  bool _isUploading = false;
  double _progress = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _priceController.dispose();
    _videoPlayerController?.dispose();
    for (var controller in _episodeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- GESTION VIDÉO & PRÉVISUALISATION ---
  Future<void> _initializeVideoPlayer() async {
    if (_selectedVideo == null) return;

    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }

    if (kIsWeb) {
      if (_selectedVideo!.bytes != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(_selectedVideo!.path ?? ''));
      }
    } else {
      if (_selectedVideo!.path != null) {
        _videoPlayerController = VideoPlayerController.file(File(_selectedVideo!.path!));
      }
    }

    if (_videoPlayerController != null) {
      try {
        await _videoPlayerController!.initialize();
        _videoPlayerController!.setLooping(true);
        _videoPlayerController!.play();
        setState(() => _isVideoInitialized = true);
      } catch (_) {
        setState(() => _isVideoInitialized = false);
      }
    }
  }

  /// Applique un fichier vidéo déjà traité (trim + filtre + audio)
  Future<void> _setProcessedVideo(String path) async {
    // ✅ CORRECTION : On lit les données brutes (bytes) pour l'upload
    final file = File(path);
    final bytes = await file.readAsBytes();

    setState(() {
      _selectedVideo = PlatformFile(
        name: path.split('/').last,
        size: file.lengthSync(),
        path: path,
        bytes: bytes, // ✅ AJOUT DES BYTES
      );
    });
    await _initializeVideoPlayer();
  }

  /// Import depuis la galerie avec passage par l'éditeur de preview
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: false);
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      final rawPath = result.files.first.path!;
      final edited = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => VideoPreviewEditorPage(videoPath: rawPath)),
      );
      if (edited != null) {
        await _setProcessedVideo(edited);
      }
    }
  }

  // ── Ajouter un ou plusieurs fichiers d'épisode avec initialisation du player ──
  Future<void> _pickEpisodes() async {
    // ✅ CORRECTION : withData passe à true
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video, 
      withData: true, 
      allowMultiple: true
    );
    
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (var file in result.files) {
          _episodeFiles.add(file);
          _initEpisodeController(_episodeFiles.length - 1, file);
        }
      });
    }
  }

  Future<void> _initEpisodeController(int index, PlatformFile file) async {
    if (file.path == null) return;
    final controller = VideoPlayerController.file(File(file.path!));
    _episodeControllers[index] = controller;
    try {
      await controller.initialize();
      setState(() {});
    } catch (_) {}
  }

  void _removeEpisode(int index) {
    setState(() {
      _episodeControllers[index]?.dispose();
      _episodeControllers.remove(index);
      _episodeFiles.removeAt(index);
    });
  }

  Future<void> _openCameraWithBeautyFilters() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );
    if (result != null) {
      await _setProcessedVideo(result);
    }
  }

  // --- PUBLICATION ---
  Future<void> _publishPost() async {
    if (_titleController.text.trim().isEmpty || _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter un titre et une vidéo.'), backgroundColor: _CreateColors.danger),
      );
      return;
    }

    double price = 0.0;
    if (_isPaid) {
      price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez indiquer un prix valide pour le contenu payant.'), backgroundColor: _CreateColors.danger),
        );
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _progress = 0.0;
    });

    try {
      final newContent = MediaContent(
        id: '',
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim().isEmpty ? null : _subtitleController.text.trim(),
        videoUrl: '',
        coverUrl: '',
        type: _selectedContentType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await MediaService().insertWithFiles(
        newContent,
        videoFile: _selectedVideo,
        coverFile: null,
        episodeFiles: _isSeries && _episodeFiles.isNotEmpty ? _episodeFiles : null,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication réussie !'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _CreateColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _CreateColors.textMuted, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CreateColors.navyDeep,
      appBar: AppBar(
        backgroundColor: _CreateColors.navyDeep,
        elevation: 0,
        title: const Text('Publier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. SECTION PREVIEW & CAMERA (Vidéo principale)
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: _CreateColors.cardLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: _isVideoInitialized && _videoPlayerController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoPlayerController!.value.size.width,
                              height: _videoPlayerController!.value.size.height,
                              child: VideoPlayer(_videoPlayerController!),
                            ),
                          ),
                          Center(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _videoPlayerController!.value.isPlaying
                                    ? _videoPlayerController!.pause()
                                    : _videoPlayerController!.play();
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _videoPlayerController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          if (_isSeries)
                            Positioned(
                              top: 12, left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: _CreateColors.primary, borderRadius: BorderRadius.circular(8)),
                                child: const Text('Partie 1', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: const Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSeries ? 'Aucune vidéo pour la Partie 1' : 'Sélectionnez une vidéo',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickVideo,
                              icon: const Icon(Icons.folder_outlined, size: 18),
                              label: const Text('Importer', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _openCameraWithBeautyFilters,
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Caméra', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _CreateColors.navyDeep,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // 2. FILTRES ESTHÉTIQUES
            if (_selectedVideo != null) ...[
              const Text('Filtre appliqué', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFilter = filter);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? _CreateColors.navyDeep : Colors.white70,
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 3. INFORMATIONS PRINCIPALES
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: _inputDecoration('Titre de la publication'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subtitleController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDecoration('Description / Synopsis'),
            ),

            const SizedBox(height: 24),

            // 4. CHOIX DU TYPE
            const Text('Format de diffusion', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedContentType,
                  dropdownColor: _CreateColors.cardLight,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  isExpanded: true,
                  items: ['Fil', 'Série', 'NOVA Originals', 'Musique', 'Gaming', 'Formation']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedContentType = val ?? 'Fil';
                      if (!_isSeries) {
                        _episodeFiles.clear();
                        for (var c in _episodeControllers.values) {
                          c.dispose();
                        }
                        _episodeControllers.clear();
                      }
                    });
                  },
                ),
              ),
            ),

            // 4bis. GESTION DES ÉPISODES (Série) AVEC PREVIEW VIDÉO INTÉGRÉE
            if (_isSeries) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Épisodes additionnels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(
                          '${_episodeFiles.length + (_selectedVideo != null ? 1 : 0)} partie(s)',
                          style: const TextStyle(color: _CreateColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'La vidéo importée ci-dessus est la Partie 1. Ajoutez les autres épisodes ci-dessous.',
                      style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    if (_episodeFiles.isNotEmpty)
                      Column(
                        children: List.generate(_episodeFiles.length, (i) {
                          final ep = _episodeFiles[i];
                          final controller = _episodeControllers[i];
                          final isInitialized = controller?.value.isInitialized ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                      alignment: Alignment.center,
                                      child: Text('${i + 2}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Partie ${i + 2}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 2),
                                          Text(ep.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _removeEpisode(i),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Aperçu mini de la vidéo de l'épisode
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 140,
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: isInitialized && controller != null
                                        ? Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.cover,
                                                child: SizedBox(
                                                  width: controller.value.size.width,
                                                  height: controller.value.size.height,
                                                  child: VideoPlayer(controller),
                                                ),
                                              ),
                                              Center(
                                                child: GestureDetector(
                                                  onTap: () => setState(() {
                                                    controller.value.isPlaying
                                                        ? controller.pause()
                                                        : controller.play();
                                                  }),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.5),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Center(
                                            child: SizedBox(
                                              width: 24, height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickEpisodes,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Ajouter une partie', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 5. MONÉTISATION
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          const Text('Contenu Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      Switch(
                        value: _isPaid,
                        activeColor: Colors.white,
                        activeTrackColor: _CreateColors.primary,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                        inactiveThumbColor: Colors.white54,
                        onChanged: (val) => setState(() => _isPaid = val),
                      ),
                    ],
                  ),
                  if (_isPaid) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      decoration: _inputDecoration('Prix en USD').copyWith(
                        prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.white54, size: 18),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 36),

            // 6. BOUTON PUBLIER
            if (_isUploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress, 
                  color: Colors.white, 
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Traitement en cours... ${(_progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ] else
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
                  ]
                ),
                child: ElevatedButton(
                  onPressed: _publishPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _CreateColors.navyDeep,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Publier la vidéo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
