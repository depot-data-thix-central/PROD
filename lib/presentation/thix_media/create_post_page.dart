import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/media_service.dart';
import '../../models/media_content.dart';
import 'camera_capture_page.dart';
import 'video_preview_editor_page.dart';
import 'create_post/utils/validators.dart';
import 'create_post/utils/create_post_constants.dart';
import 'create_post/widgets/video_preview_widget.dart';
import 'create_post/widgets/episode_list_widget.dart';
import 'create_post/widgets/monetization_widget.dart';
import 'create_post/widgets/filter_selector_widget.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();

  PlatformFile? _selectedVideo;
  final List<PlatformFile> _episodeFiles = [];
  String _selectedContentType = 'Fil';
  bool _isPaid = false;
  String _priceText = '';
  String _selectedFilter = 'Normal';
  bool _isUploading = false;
  double _progress = 0.0;

  String? _titleError;
  String? _subtitleError;

  bool get _isSeries => _selectedContentType == 'Série';

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  void _validateTitle(String value) {
    final error = CreatePostValidators.validateTitle(value);
    setState(() => _titleError = error);
  }

  void _validateSubtitle(String value) {
    final error = CreatePostValidators.validateSubtitle(value);
    setState(() => _subtitleError = error);
  }

  Future<void> _setProcessedVideo(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();

    final platformFile = PlatformFile(
      name: path.split('/').last,
      size: file.lengthSync(),
      path: path,
      bytes: bytes,
    );

    final error = CreatePostValidators.validateVideoFile(platformFile);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: CreatePostColors.danger),
      );
      return;
    }

    setState(() => _selectedVideo = platformFile);
  }

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

  Future<void> _pickEpisodes() async {
    final validationError = CreatePostValidators.validateEpisodeCount(_episodeFiles.length);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: CreatePostColors.danger),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final validFiles = <PlatformFile>[];
      for (var file in result.files) {
        final error = CreatePostValidators.validateVideoFile(file);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name}: $error'), backgroundColor: CreatePostColors.danger),
          );
          continue;
        }
        validFiles.add(file);
      }

      if (validFiles.isNotEmpty) {
        setState(() => _episodeFiles.addAll(validFiles));
      }
    }
  }

  void _removeEpisode(int index) {
    setState(() => _episodeFiles.removeAt(index));
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

  Future<void> _publishPost() async {
    // Validation globale
    final titleError = CreatePostValidators.validateTitle(_titleController.text);
    final subtitleError = CreatePostValidators.validateSubtitle(_subtitleController.text);
    final videoError = CreatePostValidators.validateVideoFile(_selectedVideo);
    final priceError = CreatePostValidators.validatePrice(_priceText, _isPaid);

    setState(() {
      _titleError = titleError;
      _subtitleError = subtitleError;
    });

    if (titleError != null || subtitleError != null || videoError != null || priceError != null) {
      final errorMessage = titleError ?? subtitleError ?? videoError ?? priceError ?? 'Erreur de validation';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: CreatePostColors.danger),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0.0;
    });

    try {
      final sanitizedTitle = CreatePostValidators.sanitize(_titleController.text);
      final sanitizedSubtitle = CreatePostValidators.sanitize(_subtitleController.text);

      final newContent = MediaContent(
        id: '',
        title: sanitizedTitle,
        subtitle: sanitizedSubtitle.isEmpty ? null : sanitizedSubtitle,
        videoUrl: '',
        coverUrl: '',
        type: _selectedContentType,
        isPaid: _isPaid,
        price: _isPaid ? double.parse(_priceText) : 0.0,
        filterApplied: _selectedFilter,
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
        const SnackBar(
          content: Text('Publication réussie !'),
          backgroundColor: CreatePostColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: CreatePostColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  InputDecoration _inputDecoration(String label, String? errorText) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: CreatePostColors.textMuted, fontSize: 14),
      errorText: errorText,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CreatePostColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CreatePostColors.navyDeep,
      appBar: AppBar(
        backgroundColor: CreatePostColors.navyDeep,
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
            VideoPreviewWidget(
              selectedVideo: _selectedVideo,
              isSeries: _isSeries,
              onPickVideo: _pickVideo,
              onOpenCamera: _openCameraWithBeautyFilters,
            ),
            const SizedBox(height: 24),

            if (_selectedVideo != null) ...[
              FilterSelectorWidget(
                selectedFilter: _selectedFilter,
                onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
              ),
              const SizedBox(height: 24),
            ],

            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              onChanged: _validateTitle,
              maxLength: CreatePostValidators.maxTitleLength,
              decoration: _inputDecoration('Titre de la publication', _titleError),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subtitleController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              onChanged: _validateSubtitle,
              maxLength: CreatePostValidators.maxSubtitleLength,
              decoration: _inputDecoration('Description / Synopsis', _subtitleError),
            ),
            const SizedBox(height: 24),

            const Text(
              'Format de diffusion',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
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
                  dropdownColor: CreatePostColors.cardLight,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  isExpanded: true,
                  items: CreatePostConstants.contentTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedContentType = val ?? 'Fil';
                      if (!_isSeries) {
                        _episodeFiles.clear();
                      }
                    });
                  },
                ),
              ),
            ),

            if (_isSeries) ...[
              const SizedBox(height: 20),
              EpisodeListWidget(
                episodes: _episodeFiles,
                mainVideo: _selectedVideo,
                onPickEpisodes: _pickEpisodes,
                onRemoveEpisode: _removeEpisode,
              ),
            ],

            const SizedBox(height: 24),

            MonetizationWidget(
              isPaid: _isPaid,
              priceText: _priceText,
              onPaidChanged: (val) => setState(() => _isPaid = val),
              onPriceChanged: (val) => setState(() => _priceText = val),
            ),

            const SizedBox(height: 36),

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
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _publishPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CreatePostColors.navyDeep,
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
