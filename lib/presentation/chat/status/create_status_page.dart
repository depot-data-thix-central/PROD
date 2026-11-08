// lib/presentation/chat/status/create_status_page.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/services/chat/status_service.dart';

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
const double _kLoaderSize = 18.0;

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

  /// Détecte si c'est une vidéo par l'extension
  static bool isVideoFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi');
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
    setState(() => _sending = true);
    debugPrint('[CreateStatus] 📝 Publishing text status...');

    try {
      final hexColor = '#${_bg.value.toRadixString(16).padLeft(8, '0').substring(2)}';

      final ok = await ref.read(statusProvider.notifier).createText(
            sanitizedText,
            background: hexColor,
          );

      if (!mounted) return;
      setState(() => _sending = false);

      if (ok) {
        debugPrint('[CreateStatus] ✓ Text status published');
        Navigator.pop(context);
      } else {
        _showError(l10n.t('status_publish_error'));
      }
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Publish error: $e');
      if (mounted) {
        setState(() => _sending = false);
        _showError(_StatusValidators.friendlyError(e));
      }
    }
  }

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

    debugPrint('[CreateStatus] 📁 Picking $choice...');

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

      if (!mounted) return;
      setState(() {
        _selectedImage = file;
        _selectedVideo = null;
        _videoController?.dispose();
        _videoController = null;
        _sending = false;
      });

      debugPrint('[CreateStatus] ✓ Image processed: ${file.path}');
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Image processing error: $e');
      if (mounted) {
        setState(() => _sending = false);
        _showError(_StatusValidators.friendlyError(e));
      }
    }
  }

  Future<void> _processVideo(File file, AppLocalizations l10n) async {
    try {
      setState(() => _sending = true);

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      _videoDuration = controller.value.duration;

      if (_videoDuration.inSeconds > _kMaxVideoDurationSeconds) {
        controller.dispose();
        _showError('${l10n.t('status_video_too_long')} (max 2 min)');
        return;
      }

      await controller.setLooping(true);

      if (!mounted) return;

      setState(() {
        _selectedVideo = file;
        _selectedImage = null;
        _videoController?.dispose();
        _videoController = controller;
        _sending = false;
      });

      await controller.play();
      debugPrint('[CreateStatus] ✓ Video loaded: ${file.path}, duration: $_videoDuration');
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Video processing error: $e');
      if (mounted) {
        setState(() => _sending = false);
        _showError(_StatusValidators.friendlyError(e));
      }
    }
  }

  Future<void> _publishMedia() async {
    final l10n = AppLocalizations.of(context);
    if (_sending) return;

    setState(() => _sending = true);

    try {
      final service = ref.read(statusServiceProvider);
      final sanitizedCaption = _StatusValidators.sanitizeText(
        _textCtrl.text.trim(),
        maxLength: 100,
      );

      String? id;

      if (_selectedImage != null) {
        debugPrint('[CreateStatus] ⬆️ Uploading image status...');
        final bytes = await _selectedImage!.readAsBytes();

        id = await service.createImageStatus(
          bytes: Uint8List.fromList(bytes),
          extension: _selectedImage!.path.split('.').last,
          caption: sanitizedCaption.isEmpty ? null : sanitizedCaption,
        );
      } else if (_selectedVideo != null) {
        debugPrint('[CreateStatus] ⬆️ Uploading video status...');

        final bytes = await _selectedVideo!.readAsBytes();

        id = await service.createVideoStatus(
          bytes: Uint8List.fromList(bytes),
          extension: _selectedVideo!.path.split('.').last,
          caption: sanitizedCaption.isEmpty ? null : sanitizedCaption,
        );
      }

      await ref.read(statusProvider.notifier).refresh();

      if (!mounted) return;

      if (id != null) {
        debugPrint('[CreateStatus] ✓ Media status published: $id');
        Navigator.pop(context);
      } else {
        _showError(l10n.t('status_publish_error'));
      }
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Upload error: $e');
      if (mounted) {
        _showError(_StatusValidators.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
              enabled: !_sending,
              child: TextButton(
                onPressed: _sending ? null : _publishMedia,
                child: _sending
                    ? const SizedBox(
                        width: _kLoaderSize,
                        height: _kLoaderSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
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
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
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
