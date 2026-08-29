// lib/presentation/network/widgets/create_story_dialog.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _StoryValidators {
  _StoryValidators._();

  static const int maxTextLength = 300;
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 50;
  static const int maxAudioSizeMB = 20;
  static const int maxAudioDurationSeconds = 60;
  static const Duration uploadTimeout = Duration(seconds: 30);

  static const Set<String> allowedImageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const Set<String> allowedVideoExts = {'mp4', 'mov', 'webm', 'm4v'};

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

  static bool validateFileExtension(String name, Set<String> allowed) =>
      allowed.contains(name.split('.').last.toLowerCase());

  static String? validateMime(Uint8List bytes) {
    if (bytes.length < 12) return 'Fichier trop petit';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return null;
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return null;
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return null;
    return 'Format de fichier non reconnu';
  }
}

Future<Uint8List> _compressImageAsync(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  try {
    return await compute((Uint8List input) async {
      return await FlutterImageCompress.compressWithList(input, minHeight: 1080, minWidth: 1080, quality: 85);
    }, bytes);
  } catch (e) {
    debugPrint('[Story] Compression error: $e');
    return bytes;
  }
}

// ============================================================================
// DIALOG
// ============================================================================
class CreateStoryDialog extends ConsumerStatefulWidget {
  const CreateStoryDialog({super.key});
  @override
  ConsumerState<CreateStoryDialog> createState() => _CreateStoryDialogState();
}

class _CreateStoryDialogState extends ConsumerState<CreateStoryDialog> {
  final _textController = TextEditingController();
  Uint8List? _mediaBytes;
  String? _mediaExt;
  String? _mediaType;
  bool _isUploading = false;
  bool _isRecording = false;
  final int _duration = 24;
  final _picker = ImagePicker();

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  String? _localAudioPath;

  Color _selectedBgColor = Colors.transparent;
  final List<Color> _bgColors = const [
    Colors.transparent,
    Color(0xFF00A4FF),
    ThixPolicy.danger,
    ThixPolicy.success,
    ThixPolicy.gold,
    Color(0xFF8B5CF6),
    ThixPolicy.inkDeep,
  ];

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  bool get _hasBgColor => _selectedBgColor != Colors.transparent;
  bool get _canHaveBgColor => _mediaBytes == null && _textController.text.length <= 150;
  bool get _hasContent => _textController.text.trim().isNotEmpty || _mediaBytes != null;

  String _colorToHex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  // ─── PICKERS ───
  Future<void> _pickImage() async {
    if (_isUploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final f = result?.files.first;
      if (f?.bytes == null) return;

      if (!_StoryValidators.validateFileSize(f!.bytes!.length, _StoryValidators.maxImageSizeMB)) {
        return _showError('Image trop volumineuse (max ${_StoryValidators.maxImageSizeMB}MB)');
      }
      if (!_StoryValidators.validateFileExtension(f.name, _StoryValidators.allowedImageExts)) {
        return _showError('Format image non supporté');
      }
      final mime = _StoryValidators.validateMime(f.bytes!);
      if (mime != null) return _showError(mime);

      setState(() {
        _mediaBytes = f.bytes;
        _mediaExt = f.extension ?? 'jpg';
        _mediaType = 'image';
        _selectedBgColor = Colors.transparent;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[Story] pickImage: $e');
      _showError('Erreur lors de la sélection');
    }
  }

  Future<void> _pickVideo() async {
    if (_isUploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: !kIsWeb);
      final f = result?.files.first;
      if (f == null) return;
      if (kIsWeb && f.bytes == null) return _showError('Vidéo trop lourde pour le Web');
      if (f.bytes == null) return _showError('Impossible de lire la vidéo');

      if (!_StoryValidators.validateFileSize(f.bytes!.length, _StoryValidators.maxVideoSizeMB)) {
        return _showError('Vidéo trop volumineuse (max ${_StoryValidators.maxVideoSizeMB}MB)');
      }
      if (!_StoryValidators.validateFileExtension(f.name, _StoryValidators.allowedVideoExts)) {
        return _showError('Format vidéo non supporté');
      }

      setState(() {
        _mediaBytes = f.bytes;
        _mediaExt = f.extension ?? 'mp4';
        _mediaType = 'video';
        _selectedBgColor = Colors.transparent;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[Story] pickVideo: $e');
      _showError('Erreur vidéo');
    }
  }

  Future<void> _recordShortVideo() async {
    if (_isUploading || kIsWeb) return;
    final ok = await _checkPermission(Permission.camera,
        'Pour enregistrer une story vidéo, THIX ID a besoin d\'accéder à votre caméra.');
    if (!ok) return;

    try {
      final video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 45));
      if (video == null) return;
      final bytes = await video.readAsBytes();
      if (!_StoryValidators.validateFileSize(bytes.length, _StoryValidators.maxVideoSizeMB)) {
        return _showError('Vidéo trop volumineuse');
      }
      setState(() {
        _mediaBytes = bytes;
        _mediaExt = 'mp4';
        _mediaType = 'video';
        _selectedBgColor = Colors.transparent;
      });
    } catch (e) {
      debugPrint('[Story] camera: $e');
      _showError('Caméra indisponible');
    }
  }

  Future<void> _startRecording() async {
    if (_isUploading || _isRecording) return;
    final ok = await _checkPermission(Permission.microphone,
        'Pour enregistrer un message vocal, THIX ID a besoin d\'accéder à votre microphone.');
    if (!ok) return;

    try {
      final path = kIsWeb
          ? 'story_audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : p.join((await getTemporaryDirectory()).path, 'story_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');

      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), path: path);
      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _mediaBytes = null;
        _localAudioPath = null;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _recordDuration++);
        if (_recordDuration >= _StoryValidators.maxAudioDurationSeconds) {
          _stopRecording();
        }
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[Story] record: $e');
      _showError('Enregistrement impossible');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        if (!_StoryValidators.validateFileSize(bytes.length, _StoryValidators.maxAudioSizeMB)) {
          return _showError('Audio trop volumineux');
        }
        setState(() {
          _mediaBytes = bytes;
          _mediaType = 'audio';
          _mediaExt = 'm4a';
          _localAudioPath = path;
        });
      }
    } catch (e) {
      debugPrint('[Story] stopRecord: $e');
      _showError('Erreur enregistrement');
    }
  }

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

  // ─── PUBLICATION ───
  Future<void> _createStory() async {
    if (_isUploading || _isRecording) return;

    final text = _textController.text.trim();
    if (text.isEmpty && _mediaBytes == null) {
      return _showError('Ajoutez du texte ou un média');
    }

    setState(() => _isUploading = true);
    String? uploadedUrl;

    try {
      final service = ref.read(networkServiceProvider);
      String? mediaUrl;

      if (_mediaBytes != null) {
        var uploadBytes = _mediaBytes!;
        if (_mediaType == 'image' && !kIsWeb) {
          uploadBytes = await _compressImageAsync(_mediaBytes!);
        }
        mediaUrl = await service
            .uploadImageBytes(uploadBytes, fileExtension: _mediaExt ?? 'jpg', bucket: 'stories')
            .timeout(_StoryValidators.uploadTimeout);
        uploadedUrl = mediaUrl;
      }

      await service.createStory(
        mediaUrl,
        text: _StoryValidators.sanitizeText(text),
        duration: _duration,
        mediaType: _mediaType ?? (_hasBgColor ? 'text' : 'image'),
        bgColor: _hasBgColor ? _colorToHex(_selectedBgColor) : null,   // ✅ FOND ENVOYÉ
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[Story] create: $e');

      // Rollback storage si l'insert a échoué
      if (uploadedUrl != null) {
        try {
          final uri = Uri.parse(uploadedUrl);
          final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
          final bucket = path.split('/').first;
          await Supabase.instance.client.storage.from(bucket).remove([path.replaceFirst('$bucket/', '')]);
        } catch (clean) {
          debugPrint('[Story] cleanup: $clean');
        }
      }
      _showError('Erreur de publication');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: ThixPolicy.labelStyle.copyWith(color: Colors.white)),
      backgroundColor: ThixPolicy.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
    ));
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
      backgroundColor: ThixPolicy.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),   // ✅ COMPACT
        padding: const EdgeInsets.all(ThixPolicy.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: ThixPolicy.s12),
            _contentArea(),
            const SizedBox(height: ThixPolicy.s10),
            if (_mediaBytes != null) _mediaPreview(),
            if (_canHaveBgColor) _colorRow(),
            const SizedBox(height: ThixPolicy.s12),
            _actionRow(),
            const SizedBox(height: ThixPolicy.s12),
            _publishButton(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(ThixPolicy.s6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: ThixPolicy.onBrand, size: 16),
        ),
        const SizedBox(width: ThixPolicy.s8),
        Expanded(
          child: Text('Créer une Story', style: ThixPolicy.h3Style.copyWith(fontSize: 16)),
        ),
        InkWell(
          onTap: _isUploading ? null : () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s6),
            decoration: BoxDecoration(color: ThixPolicy.surface, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: ThixPolicy.textMain, size: 16),
          ),
        ),
      ],
    );
  }

  /// ✅ Zone de saisie : fond coloré SANS boîte blanche (filled: false)
  Widget _contentArea() {
    return Flexible(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 110, maxHeight: 200),
        padding: _hasBgColor
            ? const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s20)
            : const EdgeInsets.all(ThixPolicy.s12),
        decoration: BoxDecoration(
          color: _hasBgColor ? _selectedBgColor : ThixPolicy.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: _hasBgColor ? null : Border.all(color: ThixPolicy.border),
        ),
        alignment: _hasBgColor ? Alignment.center : Alignment.topLeft,
        child: TextField(
          controller: _textController,
          maxLines: null,
          maxLength: _StoryValidators.maxTextLength,
          keyboardType: TextInputType.multiline,
          textAlign: _hasBgColor ? TextAlign.center : TextAlign.start,
          onChanged: (_) => setState(() {}),
          style: (_hasBgColor ? ThixPolicy.h2Style : ThixPolicy.bodyStyle).copyWith(
            color: _hasBgColor ? Colors.white : ThixPolicy.textMain,   // ✅ texte lisible
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,                                  // ✅ TUE le fill blanc du thème
            fillColor: Colors.transparent,
            isCollapsed: true,
            counterText: '',
            hintText: _hasBgColor ? 'Votre message…' : 'Quoi de neuf ?',
            hintStyle: ThixPolicy.bodySmallStyle.copyWith(
              color: _hasBgColor ? Colors.white70 : ThixPolicy.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediaPreview() {
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s8),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              image: _mediaType == 'image'
                  ? DecorationImage(image: MemoryImage(_mediaBytes!), fit: BoxFit.cover)
                  : null,
            ),
            child: _mediaType == 'video'
                ? const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26)
                : _mediaType == 'audio'
                    ? const Icon(Icons.mic_rounded, color: Colors.white, size: 22)
                    : null,
          ),
          const SizedBox(width: ThixPolicy.s8),
          Expanded(
            child: Text(
              '${_mediaType == 'image' ? 'Image' : _mediaType == 'video' ? 'Vidéo' : 'Audio'} • ${(_mediaBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB',
              style: ThixPolicy.captionStyle,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.cancel_rounded, color: ThixPolicy.textSecondary, size: 20),
            onPressed: () => setState(() {
              _mediaBytes = null;
              _mediaType = null;
              _localAudioPath = null;
            }),
          ),
        ],
      ),
    );
  }

  /// ✅ Pastilles compactes (28px)
  Widget _colorRow() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _bgColors.map((c) {
          final sel = _selectedBgColor == c;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedBgColor = c);
            },
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: ThixPolicy.s8),
              decoration: BoxDecoration(
                color: c == Colors.transparent ? ThixPolicy.surface : c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? ThixPolicy.textMain : ThixPolicy.borderStrong,
                  width: sel ? 2.2 : 1.2,
                ),
              ),
              child: c == Colors.transparent
                  ? const Icon(Icons.format_color_reset_rounded, size: 14, color: ThixPolicy.textSecondary)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// ✅ Boutons média compacts
  Widget _actionRow() {
    return Row(
      children: [
        _mediaBtn(Icons.image_rounded, ThixPolicy.success, 'Photo', _pickImage),
        const SizedBox(width: ThixPolicy.s8),
        _mediaBtn(Icons.folder_shared_rounded, ThixPolicy.warning, 'Vidéo', _pickVideo),
        const SizedBox(width: ThixPolicy.s8),
        _mediaBtn(Icons.videocam_rounded, ThixPolicy.danger, 'Caméra', _recordShortVideo),
        const SizedBox(width: ThixPolicy.s8),
        _mediaBtn(
          _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
          ThixPolicy.gold,
          _isRecording ? 'Stop' : 'Audio',
          _isRecording ? _stopRecording : _startRecording,
        ),
      ],
    );
  }

  Widget _mediaBtn(IconData icon, Color color, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: (_isUploading || _isRecording) ? null : onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: ThixPolicy.s2),
              Text(label, style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _publishButton() {
    return SizedBox(
      width: double.infinity,
      height: ThixPolicy.buttonHeight,                       // ✅ 48px standard
      child: ElevatedButton(
        onPressed: (_isUploading || _isRecording || !_hasContent) ? null : _createStory,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThixPolicy.gold,
          foregroundColor: ThixPolicy.inkDeep,
          disabledBackgroundColor: ThixPolicy.surfaceStrong,
          disabledForegroundColor: ThixPolicy.textDisabled,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
        ),
        child: _isUploading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.inkDeep))
            : Text('PUBLIER LA STORY', style: ThixPolicy.buttonText.copyWith(color: ThixPolicy.inkDeep)),
      ),
    );
  }
}
