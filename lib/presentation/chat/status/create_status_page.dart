import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/media/thix_media_editor.dart';
import 'package:thix_id/core/media/thix_media_optimizer.dart';
import 'package:thix_id/core/media/thix_photo_editor.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/status/providers/status_upload_manager.dart';
import 'package:thix_id/presentation/chat/status/video_trim_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxStatusLength = 200;
const int _kMaxImageMB = 5;
const int _kMaxVideoMB = 64;
const int _kMaxVideoDurationSeconds = 120; // 2 minutes
const int _kMaxDrafts = 10;
const double _kColorPickerSize = 36.0;
const double _kColorPickerBorderSelected = 3.0;
const double _kColorPickerBorderDefault = 1.0;
const double _kFontSizeStatus = 26.0;
const double _kFontSizeHint = 24.0;

const Set<String> _kVideoExts = {
  'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp', 'hevc', 'mpg', 'mpeg',
};

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

enum _MediaChoice { gallery, cameraPhoto, cameraVideo }

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

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already submitted')) return 'Sélecteur occupé, réessayez.';
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('file') || msg.contains('image')) return "Format ou taille d'image invalide.";
    return 'Une erreur est survenue lors de la sélection.';
  }
}

// ============================================================================
// BROUILLON (un média en cours de préparation)
// ============================================================================
class _Draft {
  _Draft.image({required this.bytes, required this.ext})
      : isVideo = false,
        videoPath = null;

  _Draft.video({required this.bytes, required this.ext, required this.videoPath})
      : isVideo = true;

  final bool isVideo;
  Uint8List bytes;
  String ext;
  final String? videoPath;
  final TextEditingController caption = TextEditingController();
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
  final _picker = ImagePicker();
  bool _busy = false;
  String? _busyMessage;      // message de l'overlay de traitement
  double? _videoProgress;    // 0–100 pendant la compression vidéo
  Color _bg = _kStatusColors.first;

  final List<_Draft> _drafts = [];
  int _index = 0;
  VideoPlayerController? _videoController;

  bool get _hasMedia => _drafts.isNotEmpty;
  _Draft? get _current => _drafts.isEmpty ? null : _drafts[_index];

  @override
  void dispose() {
    _textCtrl.dispose();
    for (final d in _drafts) {
      d.caption.dispose();
    }
    _videoController?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ TEXT
  Future<void> _publishText() async {
    final l10n = AppLocalizations.of(context);
    final rawText = _textCtrl.text.trim();
    if (rawText.isEmpty || _busy) return;

    final sanitizedText = _StatusValidators.sanitizeText(rawText);
    if (sanitizedText.isEmpty) {
      _showError(l10n.t('status_empty_error'));
      return;
    }

    HapticFeedback.mediumImpact();

    final hexColor =
        '#${_bg.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

    ref.read(statusUploadManagerProvider.notifier).enqueueText(
          sanitizedText,
          background: hexColor,
        );

    debugPrint('[CreateStatus] 📝 Text status queued (background upload)');

    if (!mounted) return;
    _showQueuedSnackBar(1);
    Navigator.pop(context);
  }

  // ------------------------------------------------------------------ BROUILLONS
  Future<void> _activate(int i) async {
    if (i < 0 || i >= _drafts.length) return;

    final old = _videoController;
    setState(() {
      _index = i;
      _videoController = null;
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }

    final d = _drafts[i];
    if (d.isVideo && d.videoPath != null) {
      final c = ThixMediaOptimizer.controllerFor(d.videoPath!);
      try {
        await c.initialize();
        await c.setLooping(true);
      } catch (e) {
        debugPrint('[CreateStatus] ❌ preview vidéo: $e');
        c.dispose();
        return;
      }
      if (!mounted || _index != i || i >= _drafts.length || _drafts[i] != d) {
        c.dispose();
        return;
      }
      setState(() => _videoController = c);
      await c.play();
    }
  }

  Future<void> _addDrafts(List<_Draft> list) async {
    if (list.isEmpty) return;
    final first = _drafts.length;
    _drafts.addAll(list);
    await _activate(first);
  }

  void _removeCurrent() {
    final d = _current;
    if (d == null) return;
    final removedIndex = _index;
    _drafts.removeAt(removedIndex);
    d.caption.dispose();

    if (_drafts.isEmpty) {
      final old = _videoController;
      setState(() {
        _videoController = null;
        _index = 0;
      });
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      return;
    }
    _activate(removedIndex.clamp(0, _drafts.length - 1).toInt());
  }

  Future<void> _discard() async {
    if (_drafts.length > 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Abandonner ces ${_drafts.length} médias ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    for (final d in _drafts) {
      d.caption.dispose();
    }
    final old = _videoController;
    setState(() {
      _drafts.clear();
      _index = 0;
      _videoController = null;
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  // ------------------------------------------------------------------ PICK
  Future<void> _pickMedia() async {
    if (_busy) return;
    if (_drafts.length >= _kMaxDrafts) {
      _showError('Maximum $_kMaxDrafts médias');
      return;
    }

    HapticFeedback.selectionClick();

    final choice = await showModalBottomSheet<_MediaChoice>(
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
            _sheetTile(ctx, Icons.photo_library_outlined,
                'Galerie (photos et vidéos, jusqu\'à $_kMaxDrafts)', _MediaChoice.gallery),
            if (!kIsWeb) ...[
              _sheetTile(ctx, Icons.photo_camera_outlined, 'Prendre une photo', _MediaChoice.cameraPhoto),
              _sheetTile(ctx, Icons.video_camera_back_outlined, 'Filmer une vidéo', _MediaChoice.cameraVideo),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    setState(() => _busy = true);
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
    } on MediaOptimizeException catch (e) {
      _showError(e.message);
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Erreur média: $e');
      _showError(_StatusValidators.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _videoProgress = null;
        });
      }
    }
  }

  Widget _sheetTile(BuildContext ctx, IconData icon, String label, _MediaChoice value) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  // Sélection brute (sans rejet) → le pipeline _processFiles optimise ensuite.
  Future<void> _fromGallery() async {
    final remaining = _kMaxDrafts - _drafts.length;
    final files = await _picker.pickMultipleMedia(requestFullMetadata: false);
    if (!mounted || files.isEmpty) return;

    final kept = files.length > remaining ? files.sublist(0, remaining) : files;
    await _processFiles(kept);

    if (files.length > remaining && mounted) {
      _showError('Maximum $_kMaxDrafts médias — ${files.length - remaining} ignoré(s)');
    }
  }

  Future<void> _fromCameraPhoto() async {
    final f = await _picker.pickImage(source: ImageSource.camera);
    if (f == null || !mounted) return;
    await _processFiles([f]);
  }

  Future<void> _fromCameraVideo() async {
    // Pas de maxDuration : si > 2 min, le trimmer s'ouvre.
    final f = await _picker.pickVideo(source: ImageSource.camera);
    if (f == null || !mounted) return;
    await _processFiles([f]);
  }

  // ------------------------------------------------------------------ PIPELINE
  String _extOf(XFile f, {String fallback = 'jpg'}) {
    final name = f.name;
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) return name.substring(dot + 1).toLowerCase();
    final mime = f.mimeType;
    if (mime != null && mime.contains('/')) return mime.split('/').last.toLowerCase();
    return fallback;
  }

  bool _isVideo(XFile f) {
    if (f.mimeType?.startsWith('video/') ?? false) return true;
    return _kVideoExts.contains(_extOf(f, fallback: ''));
  }

  /// Au lieu de rejeter : photo > 5MB → compression ; vidéo > 64MB →
  /// compression ; vidéo > 2min → sélection d'extrait puis découpage.
  Future<void> _processFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    final maxImgBytes = _kMaxImageMB * 1024 * 1024;
    final maxVidBytes = _kMaxVideoMB * 1024 * 1024;
    final added = <_Draft>[];
    final errors = <String>[];

    for (var i = 0; i < files.length; i++) {
      if (!mounted) return;
      final f = files[i];
      final tag = files.length > 1 ? ' (${i + 1}/${files.length})' : '';

      try {
        // ---------------- PHOTO ----------------
        if (!_isVideo(f)) {
          setState(() {
            _busyMessage = 'Préparation de la photo$tag…';
            _videoProgress = null;
          });
          var bytes = await f.readAsBytes();
          var ext = _extOf(f);
          if (bytes.length > maxImgBytes) {
            setState(() => _busyMessage = 'Compression de la photo$tag…');
            bytes = await ThixMediaOptimizer.compressImage(bytes, maxMB: _kMaxImageMB);
            ext = 'jpg';
          }
          added.add(_Draft.image(bytes: bytes, ext: ext));
          continue;
        }

        // ---------------- VIDÉO ----------------
        final path = f.path;
        final ext = _extOf(f, fallback: 'mp4');
        setState(() {
          _busyMessage = 'Analyse de la vidéo$tag…';
          _videoProgress = null;
        });

        if (kIsWeb) {
          // Pas de compression/découpage natif sur le web → limites conservées.
          final bytes = await f.readAsBytes();
          if (bytes.length > maxVidBytes) {
            errors.add('Vidéo trop volumineuse (max $_kMaxVideoMB MB). '
                'Compression disponible sur mobile uniquement.');
            continue;
          }
          final dur = await ThixMediaOptimizer.videoDuration(path);
          if (dur.inSeconds > _kMaxVideoDurationSeconds) {
            errors.add('Vidéo trop longue (max 2 min). '
                'Découpage disponible sur mobile uniquement.');
            continue;
          }
          added.add(_Draft.video(bytes: bytes, ext: ext, videoPath: path));
          continue;
        }

        final duration = await ThixMediaOptimizer.videoDuration(path);
        VideoTrimRange? trim;
        if (duration.inMilliseconds > _kMaxVideoDurationSeconds * 1000) {
          if (!mounted) return;
          trim = await Navigator.of(context).push<VideoTrimRange>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => StatusVideoTrimPage(
                videoPath: path,
                maxSeconds: _kMaxVideoDurationSeconds,
              ),
            ),
          );
          if (!mounted) return;
          if (trim == null) continue; // découpage annulé → vidéo ignorée
        }

        final size = await ThixMediaOptimizer.fileSize(path);
        if (trim != null || size > maxVidBytes) {
          setState(() {
            _busyMessage = size > maxVidBytes
                ? 'Compression de la vidéo$tag…'
                : 'Découpage de la vidéo$tag…';
            _videoProgress = 0;
          });
          final out = await ThixMediaOptimizer.processVideo(
            path,
            maxMB: _kMaxVideoMB,
            trim: trim,
            onProgress: (p) {
              if (mounted) setState(() => _videoProgress = p);
            },
          );
          added.add(_Draft.video(bytes: out.bytes, ext: out.ext, videoPath: out.path));
        } else {
          added.add(_Draft.video(bytes: await f.readAsBytes(), ext: ext, videoPath: path));
        }
      } on MediaOptimizeException catch (e) {
        errors.add(e.message);
      } catch (e) {
        debugPrint('[CreateStatus] ❌ traitement média: $e');
        errors.add(_StatusValidators.friendlyError(e));
      }
    }

    if (!mounted) return;
    setState(() {
      _busyMessage = null;
      _videoProgress = null;
    });
    if (added.isNotEmpty) await _addDrafts(added);
    if (errors.isNotEmpty && mounted) _showError(errors.first);
  }

  // ------------------------------------------------------------------ ÉDITION
  Future<void> _cropCurrent() async {
    final d = _current;
    if (d == null || d.isVideo || _busy) return;
    setState(() => _busy = true);
    try {
      final path = await ThixMediaEditor.persistTemp(d.bytes, d.ext);
      if (!mounted) return;
      // Limite large côté éditeur : on compresse nous-mêmes ensuite.
      final img = await ThixMediaEditor.editImage(context, path, maxMB: 50);
      if (img != null && mounted) {
        var bytes = img.bytes;
        var ext = img.ext;
        if (bytes.length > _kMaxImageMB * 1024 * 1024) {
          setState(() => _busyMessage = 'Compression de la photo…');
          bytes = await ThixMediaOptimizer.compressImage(bytes, maxMB: _kMaxImageMB);
          ext = 'jpg';
        }
        setState(() {
          d.bytes = bytes;
          d.ext = ext;
        });
      }
    } on MediaEditorException catch (e) {
      _showError(e.message);
    } on MediaOptimizeException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(_StatusValidators.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _openEditor(EditorTool tool) async {
    final d = _current;
    if (d == null || d.isVideo || _busy) return;

    final res = await Navigator.of(context).push<EditedPhoto>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ThixPhotoEditorPage(bytes: d.bytes, initialTool: tool),
      ),
    );
    if (res == null || !mounted) return;

    var bytes = res.bytes;
    var ext = res.ext;

    // Au lieu de rejeter : on compresse si l'édition a dépassé 5MB.
    if (bytes.length > _kMaxImageMB * 1024 * 1024) {
      setState(() {
        _busy = true;
        _busyMessage = 'Compression de la photo…';
      });
      try {
        bytes = await ThixMediaOptimizer.compressImage(bytes, maxMB: _kMaxImageMB);
        ext = 'jpg';
      } on MediaOptimizeException catch (e) {
        _showError(e.message);
        return;
      } finally {
        if (mounted) {
          setState(() {
            _busy = false;
            _busyMessage = null;
          });
        }
      }
    }
    if (!mounted) return;
    setState(() {
      d.bytes = bytes;
      d.ext = ext;
    });
  }

  // ----------------------------------------------------------------- PUBLICATION
  Future<void> _publishMedia() async {
    if (_busy || !_hasMedia) return;

    HapticFeedback.mediumImpact();

    final manager = ref.read(statusUploadManagerProvider.notifier);
    final count = _drafts.length;

    for (final d in _drafts) {
      final sanitized = _StatusValidators.sanitizeText(d.caption.text.trim(), maxLength: 100);
      final caption = sanitized.isEmpty ? null : sanitized;

      if (d.isVideo) {
        manager.enqueueVideo(d.bytes, d.ext, caption: caption);
      } else {
        manager.enqueueImage(d.bytes, d.ext, caption: caption);
      }
    }
    debugPrint('[CreateStatus] 📤 $count média(s) en file d\'attente');

    if (!mounted) return;
    _showQueuedSnackBar(count);
    Navigator.pop(context);
  }

  // ------------------------------------------------------------------ UI
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
                  ? 'Publication de $count statuts en arrière-plan…'
                  : 'Publication en arrière-plan…'),
            ),
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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasMedia = _hasMedia;

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
                _discard();
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
                onPressed: _busy ? null : _publishMedia,
                child: Text(
                  _drafts.length > 1
                      ? '${l10n.t('status_publish')} (${_drafts.length})'
                      : l10n.t('status_publish'),
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
      body: Stack(
        children: [
          SafeArea(
            child: hasMedia ? _buildMediaView(l10n) : _buildTextView(l10n),
          ),
          if (_busyMessage != null) _processingOverlay(),
        ],
      ),
    );
  }

  Widget _processingOverlay() {
    final p = _videoProgress;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.65),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    value: p == null ? null : (p / 100).clamp(0.0, 1.0).toDouble(),
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _busyMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (p != null) ...[
                  const SizedBox(height: 6),
                  Text('${p.round()}%',
                      style: const TextStyle(color: Colors.white54)),
                ],
              ],
            ),
          ),
        ),
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
                    onChanged: (_) => setState(() {}),
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
                onTap: _busy ? null : _pickMedia,
              ),
              const SizedBox(width: 12),
              if (!_busy && _textCtrl.text.trim().isNotEmpty)
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

  Widget _toolBtn(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : Colors.white70,
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
        if (i != _index) _activate(i);
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? Colors.white : Colors.white24,
            width: sel ? 2.5 : 1,
          ),
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

  Widget _buildMediaView(AppLocalizations l10n) {
    final d = _current!;
    final vc = _videoController;

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!d.isVideo)
                Image.memory(d.bytes, fit: BoxFit.contain, gaplessPlayback: true)
              else if (vc != null && vc.value.isInitialized)
                GestureDetector(
                  onTap: () {
                    vc.value.isPlaying ? vc.pause() : vc.play();
                    setState(() {});
                  },
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: vc.value.aspectRatio,
                      child: VideoPlayer(vc),
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                    key: ObjectKey(d),
                    controller: d.caption,
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (!d.isVideo) ...[
                    _toolBtn(Icons.crop_rotate_rounded, 'Rogner', _busy ? null : _cropCurrent),
                    _toolBtn(Icons.auto_fix_high_rounded, 'Filtres',
                        _busy ? null : () => _openEditor(EditorTool.filter)),
                    _toolBtn(Icons.brush_rounded, 'Dessin',
                        _busy ? null : () => _openEditor(EditorTool.draw)),
                    _toolBtn(Icons.title_rounded, 'Texte',
                        _busy ? null : () => _openEditor(EditorTool.text)),
                    _toolBtn(Icons.emoji_emotions_outlined, 'Emoji',
                        _busy ? null : () => _openEditor(EditorTool.emoji)),
                  ],
                  _toolBtn(Icons.delete_outline_rounded, 'Supprimer', _busy ? null : _removeCurrent),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _drafts.length + (_drafts.length < _kMaxDrafts ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == _drafts.length) {
                            return GestureDetector(
                              onTap: _busy ? null : _pickMedia,
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
                  ),
                  const SizedBox(width: 10),
                  _ActionChip(
                    l10n: l10n,
                    icon: Icons.send_outlined,
                    label: _drafts.length > 1
                        ? '${l10n.t('status_publish')} (${_drafts.length})'
                        : l10n.t('status_publish'),
                    onTap: _busy ? null : _publishMedia,
                  ),
                ],
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
