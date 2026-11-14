// lib/presentation/network/widgets/create_story_dialog.dart
// ============================================================================
// CRÉATEUR DE STORY — PLEIN ÉCRAN
// • Modes : Texte • Média (photos/vidéos, jusqu'à 10) • Audio
// • Photo : rogner/pivoter, filtres, dessin, texte, emojis
// • Vidéo : choix du passage (max 60 s), son coupable
// • Sélection multiple : chaque média devient une story distincte
// • Upload en arrière-plan (file d'attente globale)
// ============================================================================
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:html/parser.dart' as html_parser;
import 'package:cross_file/cross_file.dart';

import 'package:thix_id/core/media/thix_media_editor.dart';
import 'package:thix_id/core/media/thix_photo_editor.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/presentation/network/providers/story_upload_manager.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _StoryValidators {
  _StoryValidators._();

  static const int maxTextLength = 300;
  static const int maxImageSizeMB = 10;
  static const int maxAudioSizeMB = 20;
  static const int maxVideoSizeMB = 50;
  static const int maxAudioDurationSeconds = 60;
  static const int maxVideoDurationSeconds = 60;
  static const int maxDrafts = 10;

  static String sanitizeText(String? input, {int maxLength = maxTextLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static bool validateFileSize(int bytes, int maxMB) => bytes <= maxMB * 1024 * 1024;

  static String fmtDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Compression légère (appel plateforme asynchrone, ne bloque pas l'UI).
/// Retourne aussi la bonne extension (jpg après compression).
Future<({Uint8List bytes, String ext})> _compressImage(Uint8List bytes, String ext) async {
  if (kIsWeb) return (bytes: bytes, ext: ext);
  if (bytes.length < 800 * 1024 && (ext == 'jpg' || ext == 'jpeg')) {
    return (bytes: bytes, ext: ext);
  }
  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minHeight: 1080,
      minWidth: 1080,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    if (out.isEmpty) return (bytes: bytes, ext: ext);
    return (bytes: out, ext: 'jpg');
  } catch (e) {
    debugPrint('[Story] Compression error: $e');
    return (bytes: bytes, ext: ext);
  }
}

// ============================================================================
// POINT D'ENTRÉE
// ============================================================================
class CreateStoryDialog {
  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CreateStoryPage()),
    );
  }
}

// ============================================================================
// MODÈLES LOCAUX
// ============================================================================
enum _StoryMode { text, media, audio }
enum _MediaChoice { gallery, cameraPhoto, cameraVideo }

class _StoryDraft {
  _StoryDraft.image({required this.bytes, required this.ext})
      : isVideo = false,
        videoPath = null;

  _StoryDraft.video({required this.bytes, required this.ext, required this.videoPath})
      : isVideo = true;

  final bool isVideo;
  Uint8List bytes;
  String ext;
  final String? videoPath;
}

// ============================================================================
// PAGE PLEIN ÉCRAN
// ============================================================================
class CreateStoryPage extends ConsumerStatefulWidget {
  const CreateStoryPage({super.key});
  @override
  ConsumerState<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends ConsumerState<CreateStoryPage>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();

  _StoryMode _mode = _StoryMode.text;

  // Média (photos / vidéos)
  final List<_StoryDraft> _drafts = [];
  int _index = 0;
  VideoPlayerController? _videoController;

  // Audio
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  Uint8List? _audioBytes;
  String? _audioPath;

  // UI
  bool _isUploading = false;
  bool _isProcessing = false;
  Color _bgColor = Colors.transparent;
  late final AnimationController _pulseCtrl;

  static const List<Color> _bgColors = [
    Colors.transparent,
    Color(0xFF00A4FF),
    ThixPolicy.danger,
    ThixPolicy.success,
    ThixPolicy.gold,
    Color(0xFF8B5CF6),
    ThixPolicy.inkDeep,
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  bool get _hasBgColor => _bgColor != Colors.transparent;
  bool get _isBusy => _isUploading || _isRecording || _isProcessing;
  bool get _needsConfirm => _drafts.isNotEmpty || _audioBytes != null;
  _StoryDraft? get _current => _drafts.isEmpty ? null : _drafts[_index];

  bool get _hasContent {
    switch (_mode) {
      case _StoryMode.text:
        return _textController.text.trim().isNotEmpty;
      case _StoryMode.media:
        return _drafts.isNotEmpty;
      case _StoryMode.audio:
        return _audioBytes != null;
    }
  }

  String _colorToHex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  void _releaseController() {
    final old = _videoController;
    _videoController = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // MÉDIA : choix, brouillons, édition
  // ════════════════════════════════════════════════════════════════════════
  Future<_MediaChoice?> _askChoice({bool cameraOnly = false}) {
    Widget tile(BuildContext ctx, IconData icon, String label, _MediaChoice v) {
      return ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: () => Navigator.pop(ctx, v),
      );
    }

    return showModalBottomSheet<_MediaChoice>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (!cameraOnly)
              tile(ctx, Icons.photo_library_outlined,
                  'Galerie (photos et vidéos, jusqu\'à ${_StoryValidators.maxDrafts})',
                  _MediaChoice.gallery),
            if (!kIsWeb) ...[
              tile(ctx, Icons.photo_camera_outlined, 'Prendre une photo', _MediaChoice.cameraPhoto),
              tile(ctx, Icons.video_camera_back_outlined, 'Filmer une vidéo', _MediaChoice.cameraVideo),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromSheet({bool cameraOnly = false}) async {
    if (_isBusy) return;
    final choice = await _askChoice(cameraOnly: cameraOnly);
    if (choice == null || !mounted) return;
    await _runChoice(choice);
  }

  Future<void> _runChoice(_MediaChoice choice) async {
    if (_isBusy) return;
    if (_drafts.length >= _StoryValidators.maxDrafts) {
      _showError('Maximum ${_StoryValidators.maxDrafts} médias');
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isProcessing = true);
    try {
      switch (choice) {
        case _MediaChoice.gallery:
          await _fromGallery();
          break;
        case _MediaChoice.cameraPhoto:
          await _fromCameraPhoto();
          break;
        case _MediaChoice.cameraVideo:
          await _fromCameraVideo();
          break;
      }
    } on MediaEditorException catch (e) {
      _showError(e.message);
    } catch (e) {
      debugPrint('[Story] media: $e');
      _showError('Erreur lors de la sélection');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _fromGallery() async {
    final res = await ThixMediaEditor.pickMultiple(
      context,
      limit: _StoryValidators.maxDrafts - _drafts.length,
      maxVideoSeconds: _StoryValidators.maxVideoDurationSeconds,
      maxImageMB: _StoryValidators.maxImageSizeMB,
      maxVideoMB: _StoryValidators.maxVideoSizeMB,
    );
    if (!mounted) return;

    final list = res.items.map((m) {
      if (m.isVideo) {
        final v = m.video!;
        return _StoryDraft.video(bytes: v.bytes, ext: v.ext, videoPath: v.path);
      }
      final i = m.image!;
      return _StoryDraft.image(bytes: i.bytes, ext: i.ext);
    }).toList();

    await _addDrafts(list);

    if (res.skipped > 0 && mounted) {
      _showError(res.firstError ?? '${res.skipped} média(s) ignoré(s)');
    }
  }

  Future<void> _fromCameraPhoto() async {
    final img = await ThixMediaEditor.pickImage(
      context,
      source: ImageSource.camera,
      crop: false,
      maxMB: _StoryValidators.maxImageSizeMB,
    );
    if (img == null || !mounted) return;
    await _addDrafts([_StoryDraft.image(bytes: img.bytes, ext: img.ext)]);
  }

  Future<void> _fromCameraVideo() async {
    final v = await ThixMediaEditor.pickVideo(
      context,
      maxSeconds: _StoryValidators.maxVideoDurationSeconds,
      maxMB: _StoryValidators.maxVideoSizeMB,
      source: ImageSource.camera,
    );
    if (v == null || !mounted) return;
    await _addDrafts([_StoryDraft.video(bytes: v.bytes, ext: v.ext, videoPath: v.path)]);
  }

  Future<void> _addDrafts(List<_StoryDraft> list) async {
    if (list.isEmpty) return;
    final first = _drafts.length;
    _drafts.addAll(list);
    await _activate(first);
    HapticFeedback.lightImpact();
  }

  Future<void> _activate(int i) async {
    if (i < 0 || i >= _drafts.length) return;

    setState(() {
      _index = i;
      _mode = _StoryMode.media;
      _audioBytes = null;
      _audioPath = null;
      _releaseController();
    });

    final d = _drafts[i];
    if (d.isVideo && d.videoPath != null) {
      final c = ThixMediaEditor.controllerFor(d.videoPath!);
      try {
        await c.initialize();
        await c.setLooping(true);
      } catch (e) {
        debugPrint('[Story] preview vidéo: $e');
        c.dispose();
        return;
      }
      if (!mounted || _index != i || i >= _drafts.length || !identical(_drafts[i], d)) {
        c.dispose();
        return;
      }
      setState(() => _videoController = c);
      await c.play();
    }
  }

  void _removeCurrent() {
    final d = _current;
    if (d == null) return;
    final removedIndex = _index;
    _drafts.removeAt(removedIndex);

    if (_drafts.isEmpty) {
      setState(() {
        _index = 0;
        _mode = _StoryMode.text;
        _releaseController();
      });
      return;
    }
    _activate(removedIndex.clamp(0, _drafts.length - 1));
  }

  Future<void> _cropCurrent() async {
    final d = _current;
    if (d == null || d.isVideo || _isBusy) return;
    setState(() => _isProcessing = true);
    try {
      final path = await ThixMediaEditor.persistTemp(d.bytes, d.ext);
      if (!mounted) return;
      final img = await ThixMediaEditor.editImage(
        context,
        path,
        maxMB: _StoryValidators.maxImageSizeMB,
      );
      if (img != null && mounted) {
        setState(() {
          d.bytes = img.bytes;
          d.ext = img.ext;
        });
      }
    } on MediaEditorException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erreur lors de la modification');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _openEditor(EditorTool tool) async {
    final d = _current;
    if (d == null || d.isVideo || _isBusy) return;

    final res = await Navigator.of(context).push<EditedPhoto>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ThixPhotoEditorPage(bytes: d.bytes, initialTool: tool),
      ),
    );
    if (res == null || !mounted) return;

    if (!_StoryValidators.validateFileSize(res.bytes.length, _StoryValidators.maxImageSizeMB)) {
      _showError('Image trop volumineuse (max ${_StoryValidators.maxImageSizeMB}MB)');
      return;
    }
    setState(() {
      d.bytes = res.bytes;
      d.ext = res.ext;
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // AUDIO
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _startRecording() async {
    if (_isBusy) return;

    final ok = await _checkPermission(
      Permission.microphone,
      'Pour enregistrer un message vocal dans votre story, THIX ID a besoin d\'accéder à votre microphone.',
    );
    if (!ok) return;

    try {
      if (await _recorder.hasPermission() != true) {
        return _showError('Permission microphone refusée');
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = kIsWeb
          ? 'story_audio_$ts.m4a'
          : p.join((await getTemporaryDirectory()).path, 'story_audio_$ts.m4a');

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _audioBytes = null;
        _audioPath = null;
        _mode = _StoryMode.audio;
        _drafts.clear();
        _index = 0;
        _releaseController();
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _recordDuration++);
        if (_recordDuration >= _StoryValidators.maxAudioDurationSeconds) {
          _stopRecording();
          _showError('Durée maximale atteinte (60 s)');
        }
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[Story] record start: $e');
      if (mounted) setState(() => _isRecording = false);
      _showError('Enregistrement impossible : $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);

      if (path == null || path.isEmpty) {
        return _showError('Enregistrement vide');
      }

      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) return _showError('Enregistrement vide');

      if (!_StoryValidators.validateFileSize(bytes.length, _StoryValidators.maxAudioSizeMB)) {
        return _showError('Audio trop volumineux (max ${_StoryValidators.maxAudioSizeMB}MB)');
      }

      setState(() {
        _audioBytes = bytes;
        _audioPath = path;
        _mode = _StoryMode.audio;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[Story] record stop: $e');
      if (mounted) setState(() => _isRecording = false);
      _showError('Erreur à l\'arrêt de l\'enregistrement');
    }
  }

  void _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
        _mode = _StoryMode.text;
      });
    }
  }

  void _clearAudio() => setState(() {
        _audioBytes = null;
        _audioPath = null;
        _mode = _StoryMode.text;
      });

  // ════════════════════════════════════════════════════════════════════════
  // PERMISSIONS
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> _checkPermission(Permission permission, String message) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          title: Text('Permission requise', style: ThixPolicy.titleStyle),
          content: Text('Activez cette permission dans les paramètres de l\'application.', style: ThixPolicy.bodySmallStyle),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Paramètres')),
          ],
        ),
      );
      if (open == true) await openAppSettings();
      return false;
    }

    if (!mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Autorisation requise', style: ThixPolicy.titleStyle),
        content: Text(message, style: ThixPolicy.bodySmallStyle.copyWith(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: ThixPolicy.onBrand),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
    if (agreed != true) return false;
    return (await permission.request()).isGranted;
  }

  // ════════════════════════════════════════════════════════════════════════
  // PUBLICATION — EN FILE D'ATTENTE (arrière-plan)
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _createStory() async {
    if (_isBusy) return;
    if (!_hasContent) {
      return _showError('Ajoutez du texte, une photo, un audio ou une vidéo');
    }

    final manager = ref.read(storyUploadManagerProvider.notifier);
    var count = 1;

    if (_mode == _StoryMode.text) {
      final text = _StoryValidators.sanitizeText(_textController.text.trim());
      if (text.isEmpty) return _showError('Ajoutez du texte');
      final bgColor = _hasBgColor ? _colorToHex(_bgColor) : null;
      HapticFeedback.mediumImpact();
      manager.enqueueText(text, bgColor: bgColor);
    } else if (_mode == _StoryMode.audio && _audioBytes != null) {
      HapticFeedback.mediumImpact();
      manager.enqueueAudio(_audioBytes!);
    } else if (_mode == _StoryMode.media && _drafts.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _isUploading = true);
      try {
        count = _drafts.length;
        for (final d in _drafts) {
          if (d.isVideo) {
            manager.enqueueVideo(d.bytes, d.ext);
          } else {
            final c = await _compressImage(d.bytes, d.ext);
            manager.enqueueImage(c.bytes, c.ext);
          }
        }
      } catch (e) {
        debugPrint('[Story] enqueue: $e');
        if (mounted) setState(() => _isUploading = false);
        return _showError('Erreur lors de la publication');
      }
    } else {
      return _showError('Ajoutez du texte, une photo, un audio ou une vidéo');
    }

    if (!mounted) return;
    _showQueuedSnackBar(count);
    Navigator.pop(context, true);
  }

  Future<void> _confirmClose() async {
    if (_isBusy) return;
    if (!_needsConfirm) {
      Navigator.pop(context, false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner cette story ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, false);
  }

  void _showQueuedSnackBar(int count) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(count > 1
                  ? 'Publication de $count stories en arrière-plan…'
                  : 'Publication en arrière-plan…'),
            ),
          ]),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(m, style: ThixPolicy.labelStyle.copyWith(color: Colors.white)),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      ));
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final canPublish = !_isBusy && _hasContent;
    final isMedia = _mode == _StoryMode.media && _drafts.isNotEmpty;

    final publishLabel = (isMedia && _drafts.length > 1) ? 'Publier (${_drafts.length})' : 'Publier';

    return PopScope(
      canPop: !_needsConfirm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (isMedia)
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(child: _mediaPreview(top)),
                    _bottomPanel(),
                  ],
                ),
              )
            else ...[
              Positioned.fill(child: _previewBackground()),

              if (_mode == _StoryMode.text)
                Positioned.fill(
                  top: top + 70,
                  bottom: 190,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        maxLength: _StoryValidators.maxTextLength,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          color: _hasBgColor ? Colors.white : ThixPolicy.textMain,
                          fontSize: _hasBgColor ? 26 : 20,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          counterText: '',
                          hintText: 'Quoi de neuf ?',
                          hintStyle: TextStyle(
                            color: _hasBgColor ? Colors.white70 : ThixPolicy.textSecondary,
                            fontSize: _hasBgColor ? 26 : 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned(left: 0, right: 0, bottom: 0, child: _bottomPanel()),
            ],

            // Barre haute
            Positioned(
              top: top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _glassBtn(
                    icon: Icons.close_rounded,
                    onTap: _isBusy ? null : _confirmClose,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: canPublish ? _createStory : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: canPublish
                            ? const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)])
                            : null,
                        color: canPublish ? null : Colors.white24,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: _isUploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(publishLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),

            // Chargement (lecture de la galerie, rognage…)
            if (_isProcessing && !isMedia)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator(color: ThixPolicy.gold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glassBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Aperçu média (photo / vidéo) ─────────────────────────────────────────
  Widget _mediaPreview(double top) {
    final d = _current;
    if (d == null) return const SizedBox.shrink();
    final vc = _videoController;

    Widget content;
    if (!d.isVideo) {
      content = Image.memory(d.bytes, fit: BoxFit.contain, gaplessPlayback: true);
    } else if (vc != null && vc.value.isInitialized) {
      content = GestureDetector(
        onTap: () {
          vc.value.isPlaying ? vc.pause() : vc.play();
          setState(() {});
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: vc.value.aspectRatio, child: VideoPlayer(vc)),
            if (!vc.value.isPlaying)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
              ),
          ],
        ),
      );
    } else {
      content = const CircularProgressIndicator(color: Colors.white);
    }

    return Padding(
      padding: EdgeInsets.only(top: top + 56),
      child: Stack(
        children: [
          Positioned.fill(child: Center(child: content)),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Fond (texte / audio) ─────────────────────────────────────────────────
  Widget _previewBackground() {
    if (_mode == _StoryMode.audio) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1F2E), Color(0xFF0A0E1A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: ThixPolicy.gold.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.gold.withOpacity(0.4), width: 2),
                ),
                child: Icon(_isRecording ? Icons.mic_rounded : Icons.headphones_rounded, color: ThixPolicy.gold, size: 54),
              ),
              const SizedBox(height: 16),
              Text(
                _isRecording ? 'Enregistrement...' : 'Message vocal',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _StoryValidators.fmtDuration(_recordDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
    }
    if (_hasBgColor) return Container(color: _bgColor);
    return Container(color: ThixPolicy.surfaceSoft);
  }

  // ── Panneau bas ──────────────────────────────────────────────────────────
  Widget _bottomPanel() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isRecording
          ? _recordingPanel()
          : (_mode == _StoryMode.audio && _audioBytes != null)
              ? _audioPreviewPanel()
              : (_mode == _StoryMode.media && _drafts.isNotEmpty)
                  ? _mediaPanel()
                  : _defaultPanel(),
    );
  }

  Widget _defaultPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mode == _StoryMode.text) ...[
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _bgColors.map((c) {
                final sel = _bgColor == c;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _bgColor = c);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: c == Colors.transparent ? Colors.white10 : c,
                      shape: BoxShape.circle,
                      border: Border.all(color: sel ? Colors.white : Colors.white38, width: sel ? 2.4 : 1.2),
                    ),
                    child: c == Colors.transparent ? const Icon(Icons.format_color_reset_rounded, size: 14, color: Colors.white70) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            _actionTile(Icons.photo_library_rounded, 'Galerie', ThixPolicy.success,
                () => _runChoice(_MediaChoice.gallery)),
            if (!kIsWeb) ...[
              const SizedBox(width: 8),
              _actionTile(Icons.photo_camera_rounded, 'Caméra', const Color(0xFF00A4FF),
                  () => _pickFromSheet(cameraOnly: true)),
            ],
            const SizedBox(width: 8),
            _actionTile(Icons.mic_rounded, 'Audio', ThixPolicy.gold, _startRecording),
          ],
        ),
      ],
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null && !_isBusy;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white70 : Colors.white38,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(int i) {
    final d = _drafts[i];
    final sel = i == _index;
    return GestureDetector(
      onTap: () {
        if (!_isBusy && i != _index) _activate(i);
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? Colors.white : Colors.white24, width: sel ? 2.5 : 1),
          color: Colors.white10,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: d.isVideo
              ? const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26))
              : Image.memory(d.bytes, fit: BoxFit.cover, cacheWidth: 120, gaplessPlayback: true),
        ),
      ),
    );
  }

  Widget _mediaPanel() {
    final d = _current!;
    final canAdd = _drafts.length < _StoryValidators.maxDrafts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (!d.isVideo) ...[
              _toolBtn(Icons.crop_rotate_rounded, 'Rogner', _cropCurrent),
              _toolBtn(Icons.auto_fix_high_rounded, 'Filtres', () => _openEditor(EditorTool.filter)),
              _toolBtn(Icons.brush_rounded, 'Dessin', () => _openEditor(EditorTool.draw)),
              _toolBtn(Icons.title_rounded, 'Texte', () => _openEditor(EditorTool.text)),
              _toolBtn(Icons.emoji_emotions_outlined, 'Emoji', () => _openEditor(EditorTool.emoji)),
            ],
            _toolBtn(Icons.delete_outline_rounded, 'Supprimer', _removeCurrent),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _drafts.length + (canAdd ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == _drafts.length) {
                return GestureDetector(
                  onTap: _isBusy ? null : _pickFromSheet,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                );
              }
              return _thumb(i);
            },
          ),
        ),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: _isBusy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordingPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _recordDuration / _StoryValidators.maxAudioDurationSeconds,
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(ThixPolicy.danger),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: 1 + (_pulseCtrl.value * 0.12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              _StoryValidators.fmtDuration(_recordDuration),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 6),
            const Text('/ 01:00', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cancelRecording,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stopper'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _audioPreviewPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StoryAudioPreview(
          path: _audioPath!,
          bytes: _audioBytes!,
          onRetake: _startRecording,
          onRemove: _clearAudio,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _actionTile(Icons.mic_rounded, 'Réenregistrer', ThixPolicy.gold, _startRecording),
            const SizedBox(width: 8),
            _actionTile(Icons.photo_library_rounded, 'Galerie', ThixPolicy.success,
                () => _runChoice(_MediaChoice.gallery)),
            if (!kIsWeb) ...[
              const SizedBox(width: 8),
              _actionTile(Icons.photo_camera_rounded, 'Caméra', const Color(0xFF00A4FF),
                  () => _pickFromSheet(cameraOnly: true)),
            ],
            const SizedBox(width: 8),
            _actionTile(Icons.delete_outline_rounded, 'Supprimer', ThixPolicy.danger, _clearAudio),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// PRÉ-ÉCOUTE AUDIO
// ============================================================================
class _StoryAudioPreview extends StatefulWidget {
  final String path;
  final Uint8List bytes;
  final VoidCallback onRetake;
  final VoidCallback onRemove;

  const _StoryAudioPreview({
    required this.path,
    required this.bytes,
    required this.onRetake,
    required this.onRemove,
  });

  @override
  State<_StoryAudioPreview> createState() => _StoryAudioPreviewState();
}

class _StoryAudioPreviewState extends State<_StoryAudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (kIsWeb) {
        await _player.setSourceUrl(widget.path);
      } else {
        await _player.setSourceDeviceFile(widget.path);
      }
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = Duration.zero);
      });
    } catch (e) {
      debugPrint('[StoryPreview] init: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds > 0 ? _duration : Duration(seconds: widget.bytes.length ~/ 16000);
    final maxMs = total.inMilliseconds.toDouble() > 0 ? total.inMilliseconds.toDouble() : 1.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _player.pause();
              } else {
                await _player.resume();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pré-écoute', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: ThixPolicy.gold,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: ThixPolicy.gold,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs,
                    value: _position.inMilliseconds.toDouble().clamp(0.0, maxMs),
                    onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${_fmt(_position)} / ${_fmt(total)}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
