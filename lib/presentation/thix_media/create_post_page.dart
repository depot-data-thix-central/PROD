import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/media_service.dart';
import '../../models/media_content.dart';

const Color kBg = Color(0xFF050507);
const Color kSurface = Color(0xFF121214);
const Color kSurfaceLight = Color(0xFF1E1E28);
const Color kRed = Color(0xFFFF1A1A);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextGrey = Color(0xFF9CA3AF);
const Color kTdiaBlue = Color(0xFF2D6CDF);

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

  String _selectedContentType = 'Fil'; // 'Fil', 'Série', 'NOVA Originals', etc.
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

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedVideo = result.files.first);
      await _initializeVideoPlayer();
    }
  }

  // ── Ajouter un ou plusieurs fichiers d'épisode ──
  Future<void> _pickEpisodes() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true, allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _episodeFiles.addAll(result.files));
    }
  }

  void _removeEpisode(int index) {
    setState(() => _episodeFiles.removeAt(index));
  }

  // Simulation ouverture caméra avec filtres beauté
  void _openCameraWithBeautyFilters() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Module Caméra & Filtres Beauté natifs (Intégrer package 'camera' ici)"),
        backgroundColor: kTdiaBlue,
      ),
    );
  }

  // --- PUBLICATION ---
  Future<void> _publishPost() async {
    if (_titleController.text.trim().isEmpty || _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter un titre et une vidéo.'), backgroundColor: kRed),
      );
      return;
    }

    double price = 0.0;
    if (_isPaid) {
      price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez indiquer un prix valide pour le contenu payant.'), backgroundColor: kRed),
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

      // Note: la couverture n'est plus fournie manuellement — MediaService
      // génère une miniature automatiquement depuis la vidéo principale.
      // Les épisodes additionnels (format Série) sont uploadés et stockés
      // dans episodesUrls. Tu peux stocker _isPaid et price dans ta table
      // Supabase si tu as ajouté les colonnes correspondantes.
      await MediaService().insertWithFiles(
        newContent,
        videoFile: _selectedVideo,
        coverFile: null,
        episodeFiles: _isSeries && _episodeFiles.isNotEmpty ? _episodeFiles : null,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication réussie !'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Studio de Publication', style: TextStyle(color: kTextWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: kTextWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. SECTION PREVIEW & CAMERA (vidéo principale / épisode 1)
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: _isVideoInitialized && _videoPlayerController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                            child: IconButton(
                              icon: Icon(
                                _videoPlayerController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.white70,
                                size: 50,
                              ),
                              onPressed: () => setState(() {
                                _videoPlayerController!.value.isPlaying
                                    ? _videoPlayerController!.pause()
                                    : _videoPlayerController!.play();
                              }),
                            ),
                          ),
                          if (_isSeries)
                            Positioned(
                              top: 10, left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: kTdiaBlue, borderRadius: BorderRadius.circular(6)),
                                child: const Text('Partie 1', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.movie_creation_outlined, color: kTextGrey, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _isSeries ? 'Aucune vidéo pour la Partie 1' : 'Aucune vidéo sélectionnée',
                          style: const TextStyle(color: kTextGrey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickVideo,
                              icon: const Icon(Icons.folder_open, size: 16),
                              label: const Text('Importer'),
                              style: ElevatedButton.styleFrom(backgroundColor: kSurfaceLight, foregroundColor: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _openCameraWithBeautyFilters,
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Caméra & Beauté'),
                              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
                            ),
                          ],
                        )
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // 2. FILTRES ESTHÉTIQUES DE RETRAVAIL VIDÉO
            if (_selectedVideo != null) ...[
              const Text('Filtre esthétique appliqué', style: TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedFilter = filter),
                        selectedColor: kTdiaBlue,
                        backgroundColor: kSurfaceLight,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : kTextGrey, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 3. INFORMATIONS PRINCIPALES
            TextField(
              controller: _titleController,
              style: const TextStyle(color: kTextWhite),
              decoration: InputDecoration(
                labelText: 'Titre de la publication / Série',
                labelStyle: const TextStyle(color: kTextGrey),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _subtitleController,
              style: const TextStyle(color: kTextWhite),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description / Synopsis',
                labelStyle: const TextStyle(color: kTextGrey),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 20),

            // 4. CHOIX DU TYPE (Fil, Série, etc.)
            DropdownButtonFormField<String>(
              value: _selectedContentType,
              dropdownColor: kSurfaceLight,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Format de diffusion',
                labelStyle: const TextStyle(color: kTextGrey),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: ['Fil', 'Série', 'NOVA Originals', 'Musique', 'Gaming', 'Formation']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedContentType = val ?? 'Fil';
                  if (!_isSeries) _episodeFiles.clear();
                });
              },
            ),

            // 4bis. GESTION DES ÉPISODES — visible uniquement si "Série"
            if (_isSeries) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kTdiaBlue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Épisodes de la série', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '${_episodeFiles.length + (_selectedVideo != null ? 1 : 0)} partie(s)',
                          style: const TextStyle(color: kTextGrey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'La vidéo importée ci-dessus est la Partie 1. Ajoutez les parties suivantes ici.',
                      style: TextStyle(color: kTextGrey, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 14),

                    if (_episodeFiles.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(color: kSurfaceLight, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Text('Aucun épisode additionnel', style: TextStyle(color: kTextGrey, fontSize: 12.5)),
                      )
                    else
                      Column(
                        children: List.generate(_episodeFiles.length, (i) {
                          final ep = _episodeFiles[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: kSurfaceLight, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: kTdiaBlue, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text('${i + 2}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Partie ${i + 2}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(ep.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextGrey, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeEpisode(i),
                                  child: const Icon(Icons.close_rounded, color: kTextGrey, size: 18),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),

                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickEpisodes,
                        icon: const Icon(Icons.add_rounded, size: 18, color: kTdiaBlue),
                        label: const Text('Ajouter un épisode', style: TextStyle(color: kTdiaBlue, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kTdiaBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 5. GRATUIT OU PAYANT (MONÉTISATION)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Contenu Payant (Verrouillé)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Switch(
                        value: _isPaid,
                        activeColor: kRed,
                        onChanged: (val) => setState(() => _isPaid = val),
                      ),
                    ],
                  ),
                  if (_isPaid) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Prix en USD / Équivalent',
                        labelStyle: const TextStyle(color: kTextGrey),
                        filled: true,
                        fillColor: kSurfaceLight,
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 6. BOUTON DE PUBLICATION OU PROGRESSION
            if (_isUploading) ...[
              LinearProgressIndicator(value: _progress, color: kRed, backgroundColor: kSurfaceLight),
              const SizedBox(height: 12),
              Text(
                'Publication en cours... ${(_progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextGrey, fontSize: 13),
              ),
            ] else
              ElevatedButton(
                onPressed: _publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Publier maintenant', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
