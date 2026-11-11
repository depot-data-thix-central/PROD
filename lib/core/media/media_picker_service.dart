// lib/core/media/media_picker_service.dart
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

// ============================================================================
// MODELES
// ============================================================================
class MediaException implements Exception {
  final String message;
  MediaException(this.message);
  @override
  String toString() => message;
}

class PickedMedia {
  final Uint8List bytes;
  final String ext;
  final String path;
  final bool isVideo;

  const PickedMedia({
    required this.bytes,
    required this.ext,
    required this.path,
    this.isVideo = false,
  });
}

class TrimResult {
  final int startMs;
  final int endMs;
  final bool mute;
  const TrimResult(this.startMs, this.endMs, this.mute);
}

// ============================================================================
// SERVICE
// ============================================================================
class MediaPickerService {
  MediaPickerService._();

  static final ImagePicker _picker = ImagePicker();
  static bool _busy = false;

  // ---------------------------------------------------------------- SOURCE
  static Future<ImageSource?> askSource(BuildContext context, {bool video = false}) async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Galerie', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                video ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                color: Colors.white,
              ),
              title: Text(
                video ? 'Filmer une vidéo' : 'Prendre une photo',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- IMAGE
  static Future<PickedMedia?> pickImage(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
    int maxBytes = 10 * 1024 * 1024,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final XFile? x = await _picker.pickImage(source: source);
      if (x == null) return null;
      if (!context.mounted) return null;
      return await _cropToMedia(context, x.path, maxBytes);
    } on MediaException {
      rethrow;
    } catch (e) {
      debugPrint('[MediaPicker] pickImage: $e');
      throw MediaException("Impossible de charger l'image.");
    } finally {
      _busy = false;
    }
  }

  /// Re-ouvre l'éditeur (rognage / rotation) sur une image déjà choisie.
  static Future<PickedMedia?> editImage(
    BuildContext context,
    PickedMedia media, {
    int maxBytes = 10 * 1024 * 1024,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await _cropToMedia(context, media.path, maxBytes);
    } on MediaException {
      rethrow;
    } catch (e) {
      debugPrint('[MediaPicker] editImage: $e');
      throw MediaException("Impossible de modifier l'image.");
    } finally {
      _busy = false;
    }
  }

  static Future<PickedMedia?> _cropToMedia(
    BuildContext context,
    String sourcePath,
    int maxBytes,
  ) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      maxWidth: 1920,
      maxHeight: 1920,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Modifier la photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: const Color(0xFF00A4FF),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Modifier la photo',
          cancelButtonTitle: 'Annuler',
          doneButtonTitle: 'OK',
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        if (kIsWeb && context.mounted)
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
          ),
      ],
    );

    if (cropped == null) return null;

    final bytes = await XFile(cropped.path).readAsBytes();
    if (bytes.isEmpty) throw MediaException('Image vide.');
    if (bytes.length > maxBytes) {
      throw MediaException('Image trop volumineuse (max ${maxBytes ~/ (1024 * 1024)} Mo)');
    }
    return PickedMedia(bytes: bytes, ext: 'jpg', path: cropped.path);
  }

  // ----------------------------------------------------------------- VIDEO
  static VideoPlayerController controllerFor(String path) {
    if (kIsWeb) return VideoPlayerController.networkUrl(Uri.parse(path));
    return VideoPlayerController.file(File(path));
  }

  static Future<PickedMedia?> pickVideo(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
    required int maxSeconds,
    int maxBytes = 50 * 1024 * 1024,
  }) async {
    if (_busy) return null;
    _busy = true;
    VideoPlayerController? ctrl;
    try {
      final XFile? x = await _picker.pickVideo(source: source);
      if (x == null) return null;
      if (!context.mounted) return null;

      ctrl = controllerFor(x.path);
      await ctrl.initialize();
      final durMs = ctrl.value.duration.inMilliseconds;

      // ------------------------------------------------------------- WEB
      if (kIsWeb) {
        if (durMs > maxSeconds * 1000 + 500) {
          throw MediaException(
            'Vidéo trop longue (max $maxSeconds s). Le découpage est disponible sur mobile.',
          );
        }
        final bytes = await x.readAsBytes();
        if (bytes.length > maxBytes) {
          throw MediaException('Vidéo trop volumineuse (max ${maxBytes ~/ (1024 * 1024)} Mo)');
        }
        final name = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'mp4';
        return PickedMedia(bytes: bytes, ext: name, path: x.path, isVideo: true);
      }

      // ---------------------------------------------------------- MOBILE
      if (!context.mounted) return null;
      final TrimResult? trim = await Navigator.of(context).push<TrimResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VideoTrimPage(controller: ctrl!, maxSeconds: maxSeconds),
        ),
      );
      await ctrl.pause();
      if (trim == null) return null;
      if (!context.mounted) return null;

      final bool trimmed = trim.startMs > 300 || trim.endMs < durMs - 300;
      int? startSec;
      int? durSec;
      if (trimmed) {
        startSec = (trim.startMs / 1000).floor();
        durSec = ((trim.endMs - trim.startMs) / 1000).round().clamp(1, maxSeconds);
      }

      final close = _showBlocking(context, 'Préparation de la vidéo…');
      MediaInfo? info;
      try {
        info = await VideoCompress.compressVideo(
          x.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          startTime: startSec,
          duration: durSec,
          includeAudio: !trim.mute,
        );
      } finally {
        close();
      }

      final file = info?.file;
      if (file == null) throw MediaException('Compression de la vidéo impossible.');

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw MediaException('Vidéo vide.');
      if (bytes.length > maxBytes) {
        throw MediaException('Vidéo trop volumineuse (max ${maxBytes ~/ (1024 * 1024)} Mo)');
      }

      return PickedMedia(bytes: bytes, ext: 'mp4', path: file.path, isVideo: true);
    } on MediaException {
      rethrow;
    } catch (e) {
      debugPrint('[MediaPicker] pickVideo: $e');
      throw MediaException('Impossible de charger la vidéo.');
    } finally {
      try {
        await ctrl?.dispose();
      } catch (_) {}
      _busy = false;
    }
  }

  // --------------------------------------------------------------- DIALOG
  static void Function() _showBlocking(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    var closed = false;
    return () {
      if (closed) return;
      closed = true;
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }
}

// ============================================================================
// PAGE DE DECOUPAGE VIDEO (type WhatsApp)
// ============================================================================
class VideoTrimPage extends StatefulWidget {
  final VideoPlayerController controller;
  final int maxSeconds;

  const VideoTrimPage({
    super.key,
    required this.controller,
    required this.maxSeconds,
  });

  @override
  State<VideoTrimPage> createState() => _VideoTrimPageState();
}

class _VideoTrimPageState extends State<VideoTrimPage> {
  late final int _durMs;
  late RangeValues _range;
  bool _mute = false;

  VideoPlayerController get _c => widget.controller;
  double get _maxMs => widget.maxSeconds * 1000.0;

  @override
  void initState() {
    super.initState();
    _durMs = math.max(_c.value.duration.inMilliseconds, 1);
    _range = RangeValues(0, math.min(_durMs.toDouble(), _maxMs));
    _c.setLooping(false);
    _c.setVolume(1);
    _c.addListener(_tick);
    _c.seekTo(Duration.zero);
    _c.play();
  }

  @override
  void dispose() {
    _c.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final pos = _c.value.position.inMilliseconds;
    if (_c.value.isPlaying && pos >= _range.end) {
      _c.seekTo(Duration(milliseconds: _range.start.toInt()));
    }
    setState(() {});
  }

  void _onRange(RangeValues v) {
    const minMs = 1000.0;
    var s = v.start;
    var e = v.end;
    final startMoved = (s - _range.start).abs() > (e - _range.end).abs();

    if (e - s > _maxMs) {
      if (startMoved) {
        e = s + _maxMs;
      } else {
        s = e - _maxMs;
      }
    }
    if (e - s < minMs) {
      if (startMoved) {
        s = e - minMs;
      } else {
        e = s + minMs;
      }
    }
    s = s.clamp(0.0, _durMs.toDouble());
    e = e.clamp(0.0, _durMs.toDouble());

    setState(() => _range = RangeValues(s, e));
    final target = startMoved ? s : math.max(s, e - 800);
    _c.seekTo(Duration(milliseconds: target.toInt()));
  }

  String _fmt(num ms) {
    final total = (ms / 1000).round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay() {
    if (_c.value.isPlaying) {
      _c.pause();
    } else {
      final pos = _c.value.position.inMilliseconds;
      if (pos < _range.start || pos >= _range.end) {
        _c.seekTo(Duration(milliseconds: _range.start.toInt()));
      }
      _c.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    setState(() => _mute = !_mute);
    _c.setVolume(_mute ? 0 : 1);
  }

  void _done() {
    _c.pause();
    Navigator.pop(
      context,
      TrimResult(_range.start.toInt(), _range.end.toInt(), _mute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tooLong = _durMs > _maxMs + 500;
    final selected = _range.end - _range.start;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Couper la vidéo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _done,
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF00A4FF), fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _c.value.aspectRatio == 0 ? 9 / 16 : _c.value.aspectRatio,
                        child: VideoPlayer(_c),
                      ),
                    ),
                    if (!_c.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: const Color(0xFF0B0F19),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tooLong)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'La vidéo dépasse ${widget.maxSeconds} s : choisissez la partie à garder.',
                        style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      activeTrackColor: const Color(0xFFFACC15),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFFFACC15),
                      overlayColor: const Color(0x33FACC15),
                      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: RangeSlider(
                      min: 0,
                      max: _durMs.toDouble(),
                      values: _range,
                      onChanged: _onRange,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_range.start), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        'Durée : ${_fmt(selected)} / max ${_fmt(_maxMs)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      Text(_fmt(_range.end), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _togglePlay,
                        icon: Icon(
                          _c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: _toggleMute,
                        icon: Icon(
                          _mute ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: _mute ? const Color(0xFFEF4444) : Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
