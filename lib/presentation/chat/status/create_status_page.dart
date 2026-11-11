// lib/presentation/chat/status/create_status_page.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image_cropper/image_cropper.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/status/providers/status_upload_manager.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxStatusLength = 200;
const int _kMaxImageSizeBytes = 5 * 1024 * 1024; // 5MB
const int _kMaxVideoDurationSeconds = 120; // 2 minutes
const double _kColorPickerSize = 36.0;
const double _kColorPickerBorderSelected = 3.0;
const double _kColorPickerBorderDefault = 1.0;
const double _kFontSizeStatus = 26.0;
const double _kFontSizeHint = 24.0;

const List<Color> _kStatusColors = [
  ThixPolicy.primary,
  Color(0xFF0F172A),
  Color(0xFF7C3AED),
  ThixPolicy.success,
  ThixPolicy.danger,
  ThixPolicy.warning,
  Color(0xFF0891B2),
  Color(0xFFBE185D),
];

// ============================================================================
// VALIDATORS
// ============================================================================
class _StatusValidators {
  _StatusValidators._();

  static String sanitizeText(String? input, {int maxLength = _kMaxStatusLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidImageSize(int bytes) {
    return bytes > 0 && bytes <= _kMaxImageSizeBytes;
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('file') || msg.contains('image')) return "Format ou taille d'image invalide.";
    return 'Une erreur est survenue lors de la publication.';
  }
}

// ============================================================================
// CREATE STATUS PAGE
// ============================================================================
class CreateStatusPage extends ConsumerStatefulWidget {
  const CreateStatusPage({super.key});

  @override
  ConsumerState<CreateStatusPage> createState() => _CreateStatusPageState();
}

class _CreateStatusPageState extends ConsumerState<CreateStatusPage> {
  final _textCtrl = TextEditingController();
  bool _sending = false;
  Color _bg = _kStatusColors.first;

  File? _selectedImage;
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  Duration _videoDuration = Duration.zero;

  @override
  void dispose() {
    _textCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ TEXT
  Future<void> _publishText() async {
    final l10n = AppLocalizations.of(context);
    final rawText = _textCtrl.text.trim();
    if (rawText.isEmpty || _sending) return;

    final sanitizedText = _StatusValidators.sanitizeText(rawText);
    if (sanitizedText.isEmpty) {
      _showError(l10n.t('status_empty_error'));
      return;
    }

    HapticFeedback.mediumImpact();

    final hexColor = '#${_bg.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    // Mise en file d'attente : l'upload continue en arrière-plan
    ref.read(statusUploadManagerProvider.notifier).enqueueText(
          sanitizedText,
          background: hexColor,
        );

    debugPrint('[CreateStatus] 📝 Text status queued (background upload)');

    if (!mounted) return;
    _showQueuedSnackBar();
    Navigator.pop(context);
  }

  // ------------------------------------------------------------------ PICK
  Future<void> _pickMedia() async {
    final l10n = AppLocalizations.of(context);
    if (_sending) return;

    HapticFeedback.selectionClick();

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('status_choose_media')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.t('status_add_image')),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text('${l10n.t('status_add_video')} (max 2 min)'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: choice == 'image' ? FileType.image : FileType.video,
      withData: false,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      debugPrint('[CreateStatus] ⚠️ No file selected');
      return;
    }

    final file = File(result.files.single.path!);

    if (choice == 'image') {
      await _processImage(file, l10n);
    } else {
      await _processVideo(file, l10n);
    }
  }

  Future<void> _processImage(File file, AppLocalizations l10n) async {
    try {
      setState(() => _sending = true);

      final bytes = await file.length();
      if (!_StatusValidators.isValidImageSize(bytes)) {
        _showError('${l10n.t('status_file_too_big')} (max 5MB)');
        return;
      }

      setState(() => _sending = false);

      // Ouvre le cropper natif (rognage, rotation, ajustement)
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Modifier',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Modifier',
            cancelButtonTitle: 'Annuler',
            doneButtonTitle: 'OK',
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() {
          _selectedImage = File(croppedFile.path);
          _selectedVideo = null;
          _videoController?.dispose();
          _videoController = null;
        });
        debugPrint('[CreateStatus] ✓ Image rognée: ${croppedFile.path}');
      }
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Erreur image: $e');
      if (mounted) {
        setState(() => _sending = false);
        _showError(_StatusValidators.friendlyError(e));
      }
    }
  }

  Future<void> _processVideo(File file, AppLocalizations l10n) async {
    try {
      setState(() => _sending = true);

      // Compresse la vidéo pour l'upload en arrière-plan
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.Res720p,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info?.file == null) {
        if (mounted) setState(() => _sending = false);
        return;
      }

      final compressedFile = info!.file!;
      final controller = VideoPlayerController.file(compressedFile);
      await controller.initialize();
      _videoDuration = controller.value.duration;

      if (_videoDuration.inSeconds > _kMaxVideoDurationSeconds) {
        controller.dispose();
        _showError('${l10n.t('status_video_too_long')} (max 2 min)');
        if (mounted) setState(() => _sending = false);
        return;
      }

      await controller.setLooping(true);

      if (!mounted) return;
      setState(() {
        _selectedVideo = compressedFile;
        _selectedImage = null;
        _videoController?.dispose();
        _videoController = controller;
        _sending = false;
      });

      await controller.play();
      debugPrint('[CreateStatus] ✓ Vidéo compressée et prête: ${compressedFile.path}');
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Erreur vidéo: $e');
      if (mounted) {
        setState(() => _sending = false);
        _showError(_StatusValidators.friendlyError(e));
      }
    }
  }

  // ----------------------------------------------------------------- MEDIA
  Future<void> _publishMedia() async {
    final l10n = AppLocalizations.of(context);
    if (_sending) return;
    if (_selectedImage == null && _selectedVideo == null) return;

    final sanitizedCaption = _StatusValidators.sanitizeText(
      _textCtrl.text.trim(),
      maxLength: 100,
    );
    final caption = sanitizedCaption.isEmpty ? null : sanitizedCaption;

    HapticFeedback.mediumImpact();

    // Mise en file d'attente : lecture des octets + upload en arrière-plan
    if (_selectedImage != null) {
      ref.read(statusUploadManagerProvider.notifier).enqueueImage(
            _selectedImage!.path,
            caption: caption,
          );
      debugPrint('[CreateStatus] 🖼️ Image queued (background upload)');
    } else {
      ref.read(statusUploadManagerProvider.notifier).enqueueVideo(
            _selectedVideo!.path,
            caption: caption,
          );
      debugPrint('[CreateStatus] 🎥 Video queued (background upload)');
    }

    if (!mounted) return;
    _showQueuedSnackBar();
    Navigator.pop(context);
  }

  // ------------------------------------------------------------------ UI
  void _showQueuedSnackBar() {
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
            const Expanded(child: Text('Publication en arrière-plan…')),
          ]),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearMedia() {
    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasMedia = _selectedImage != null || _selectedVideo != null;

    return Scaffold(
      backgroundColor: hasMedia ? Colors.black : _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_close'),
          child: IconButton(
            icon: Icon(hasMedia ? Icons.arrow_back : Icons.close, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              if (hasMedia) {
                _clearMedia();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        actions: [
          if (hasMedia)
            Semantics(
              button: true,
              label: l10n.t('status_publish'),
              child: TextButton(
                onPressed: _publishMedia,
                child: Text(
                  l10n.t('status_publish'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: hasMedia ? _buildMediaView(l10n) : _buildTextView(l10n),
      ),
    );
  }

  Widget _buildTextView(AppLocalizations l10n) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Semantics(
                  label: l10n.t('status_text_input'),
                  textField: true,
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    maxLength: _kMaxStatusLength,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: _kFontSizeStatus,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: l10n.t('status_hint'),
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: _kFontSizeHint,
                        fontWeight: FontWeight.w600,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _kStatusColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = _kStatusColors[i];
              final sel = c == _bg;

              return Semantics(
                button: true,
                label: '${l10n.t('status_color')} ${i + 1}',
                selected: sel,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _bg = c);
                  },
                  child: Container(
                    width: _kColorPickerSize,
                    height: _kColorPickerSize,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: sel ? _kColorPickerBorderSelected : _kColorPickerBorderDefault,
                      ),
                      boxShadow: sel
                          ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionChip(
                l10n: l10n,
                icon: Icons.add_photo_alternate_outlined,
                label: l10n.t('status_add_media'),
                onTap: _sending ? null : _pickMedia,
              ),
              const SizedBox(width: 12),
              if (!_sending && _textCtrl.text.trim().isNotEmpty)
                _ActionChip(
                  l10n: l10n,
                  icon: Icons.send_outlined,
                  label: l10n.t('status_publish'),
                  onTap: _publishText,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaView(AppLocalizations l10n) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_selectedImage != null)
                InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.file(_selectedImage!, fit: BoxFit.contain),
                )
              else if (_selectedVideo != null && _videoController != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: 2,
                    maxLength: 100,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: l10n.t('status_add_caption'),
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: _clearMedia,
              ),
              _ActionChip(
                l10n: l10n,
                icon: Icons.send_outlined,
                label: l10n.t('status_publish'),
                onTap: _sending ? null : _publishMedia,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ACTION CHIP
// ============================================================================
class _ActionChip extends StatelessWidget {
  final AppLocalizations l10n;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.l10n,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Material(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
