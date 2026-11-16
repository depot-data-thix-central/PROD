// lib/core/media/thix_media_editor.dart
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

class MediaEditorException implements Exception {
  MediaEditorException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PickedImage {
  const PickedImage({required this.bytes, required this.ext, required this.path});
  final Uint8List bytes;
  final String ext;
  final String path;
}

class PickedVideo {
  const PickedVideo({
    required this.bytes,
    required this.ext,
    required this.path,
    required this.duration,
  });
  final Uint8List bytes;
  final String ext;
  final String path;
  final Duration duration;
}

class PickedMedia {
  const PickedMedia.image(PickedImage this.image) : video = null;
  const PickedMedia.video(PickedVideo this.video) : image = null;
  final PickedImage? image;
  final PickedVideo? video;
  bool get isVideo => video != null;
}

class MultiPickResult {
  const MultiPickResult(this.items, this.skipped, this.firstError);
  final List<PickedMedia> items;
  final int skipped;
  final String? firstError;
}

class VideoTrimResult {
  const VideoTrimResult({required this.start, required this.end, required this.mute});
  final Duration start;
  final Duration end;
  final bool mute;
}

class ThixMediaEditor {
  ThixMediaEditor._();

  static final ImagePicker _picker = ImagePicker();
  static bool _busy = false;

  static String _extOf(String name, String fallback) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return fallback;
    final e = name.substring(i + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(e) ? e : fallback;
  }

  static bool _isVideo(XFile f) {
    final mime = f.mimeType ?? '';
    if (mime.startsWith('video/')) return true;
    const exts = {'mp4', 'mov', 'm4v', 'webm', '3gp', 'mkv', 'avi'};
    return exts.contains(_extOf(f.name, ''));
  }

  static VideoPlayerController controllerFor(String path) {
    return kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : VideoPlayerController.file(File(path));
  }

  /// Écrit des octets dans un fichier temporaire (ou blob sur web) pour le cropper.
  static Future<String> persistTemp(Uint8List bytes, String ext) async {
    if (kIsWeb) {
      return XFile.fromData(
        bytes,
        mimeType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
        name: 'edit.$ext',
      ).path;
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/thix_edit_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  /// Choix Galerie / Caméra (galerie seule sur web).
  static Future<ImageSource?> chooseSource(BuildContext context) async {
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
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('Galerie', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Colors.white),
              title: const Text('Caméra', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── IMAGE ─────────────────────────────
  static Future<PickedImage?> pickImage(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
    bool crop = true,
    int maxMB = 10,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      if (picked == null) return null;
      if (!context.mounted) return null;
      return await _cropAndRead(context, picked.path, picked.name, crop: crop, maxMB: maxMB);
    } on MediaEditorException {
      rethrow;
    } catch (e) {
      debugPrint('[MediaEditor] pickImage: $e');
      throw MediaEditorException('Impossible de charger la photo');
    } finally {
      _busy = false;
    }
  }

  /// Rogner / pivoter une image existante (chemin fichier ou blob).
  static Future<PickedImage?> editImage(
    BuildContext context,
    String path, {
    int maxMB = 10,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await _cropAndRead(context, path, path, crop: true, maxMB: maxMB);
    } on MediaEditorException {
      rethrow;
    } catch (e) {
      debugPrint('[MediaEditor] editImage: $e');
      throw MediaEditorException('Impossible de modifier la photo');
    } finally {
      _busy = false;
    }
  }

  static Future<PickedImage?> _cropAndRead(
    BuildContext context,
    String path,
    String name, {
    required bool crop,
    required int maxMB,
  }) async {
    var finalPath = path;
    var finalName = name;

    if (crop) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Rogner',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFF00A4FF),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Rogner',
            cancelButtonTitle: 'Annuler',
            doneButtonTitle: 'OK',
          ),
          if (kIsWeb) WebUiSettings(context: context),
        ],
      );
      if (cropped == null) return null;
      finalPath = cropped.path;
      finalName = cropped.path;
    }

    final bytes = await XFile(finalPath).readAsBytes();
    if (bytes.isEmpty) throw MediaEditorException('Image vide');
    if (bytes.length > maxMB * 1024 * 1024) {
      throw MediaEditorException('Image trop volumineuse (max ${maxMB}MB)');
    }
    return PickedImage(bytes: bytes, ext: _extOf(finalName, 'jpg'), path: finalPath);
  }

  // ───────────────────── SÉLECTION MULTIPLE (photos + vidéos) ─────────────────────
  static Future<MultiPickResult> pickMultiple(
    BuildContext context, {
    int limit = 10,
    required int maxVideoSeconds,
    int maxImageMB = 5,
    int maxVideoMB = 64,
  }) async {
    if (_busy) return const MultiPickResult([], 0, null);
    _busy = true;

    final items = <PickedMedia>[];
    var skipped = 0;
    String? firstError;

    try {
      final files = await _picker.pickMultipleMedia(
        imageQuality: 92,
        maxWidth: 2560,
        maxHeight: 2560,
      );

      for (final f in files.take(limit)) {
        if (!context.mounted) break;
        try {
          if (_isVideo(f)) {
            final v = await _processVideo(
              context,
              f,
              maxSeconds: maxVideoSeconds,
              maxMB: maxVideoMB,
            );
            if (v != null) {
              items.add(PickedMedia.video(v));
            } else {
              skipped++; // découpe annulée
            }
          } else {
            final bytes = await f.readAsBytes();
            if (bytes.isEmpty) throw MediaEditorException('Image vide');
            if (bytes.length > maxImageMB * 1024 * 1024) {
              throw MediaEditorException('Image trop volumineuse (max ${maxImageMB}MB)');
            }
            items.add(PickedMedia.image(
              PickedImage(bytes: bytes, ext: _extOf(f.name, 'jpg'), path: f.path),
            ));
          }
        } on MediaEditorException catch (e) {
          skipped++;
          firstError ??= e.message;
        }
      }

      if (files.length > limit) {
        skipped += files.length - limit;
        firstError ??= 'Maximum $limit médias à la fois';
      }
    } catch (e) {
      debugPrint('[MediaEditor] pickMultiple: $e');
      throw MediaEditorException('Erreur lors de la sélection');
    } finally {
      _busy = false;
    }
    return MultiPickResult(items, skipped, firstError);
  }

  // ───────────────────────────── VIDÉO ─────────────────────────────
  static Future<PickedVideo?> pickVideo(
    BuildContext context, {
    required int maxSeconds,
    int maxMB = 50,
    ImageSource source = ImageSource.gallery,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: Duration(seconds: maxSeconds),
      );
      if (picked == null) return null;
      if (!context.mounted) return null;
      return await _processVideo(context, picked, maxSeconds: maxSeconds, maxMB: maxMB);
    } on MediaEditorException {
      rethrow;
    } catch (e) {
      debugPrint('[MediaEditor] pickVideo: $e');
      throw MediaEditorException('Erreur lors de la sélection vidéo');
    } finally {
      _busy = false;
    }
  }

  static Future<PickedVideo?> _processVideo(
    BuildContext context,
    XFile picked, {
    required int maxSeconds,
    required int maxMB,
  }) async {
    if (kIsWeb) return _webVideo(picked, maxSeconds, maxMB);

    final probe = VideoPlayerController.file(File(picked.path));
    await probe.initialize();
    final total = probe.value.duration;
    await probe.dispose();

    if (!context.mounted) return null;
    final trim = await Navigator.of(context).push<VideoTrimResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoTrimPage(path: picked.path, maxSeconds: maxSeconds),
      ),
    );
    if (trim == null) return null;

    final needsTrim = trim.start > Duration.zero ||
        trim.end < total - const Duration(milliseconds: 500);
    final lenSec = math.max(1, (trim.end - trim.start).inSeconds);

    if (!context.mounted) return null;
    final nav = Navigator.of(context, rootNavigator: true);
    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF111827),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, v, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: v > 0 ? v : null),
                const SizedBox(height: 14),
                Text(
                  'Préparation de la vidéo… ${(v * 100).round()}%',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final sub = VideoCompress.compressProgress$.subscribe((p) {
      progress.value = (p / 100).clamp(0.0, 1.0);
    });

    try {
      final info = await VideoCompress.compressVideo(
        picked.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: !trim.mute,
        startTime: needsTrim ? trim.start.inSeconds : null,
        duration: needsTrim ? lenSec : null,
      );
      final f = info?.file;
      if (f == null) throw MediaEditorException('Compression impossible');

      final ms = (info?.duration ?? 0).round();
      if (ms > (maxSeconds * 1000) + 1500) {
        throw MediaEditorException('Vidéo trop longue (max $maxSeconds s)');
      }

      final bytes = await f.readAsBytes();
      if (bytes.length > maxMB * 1024 * 1024) {
        throw MediaEditorException('Vidéo trop volumineuse (max ${maxMB}MB)');
      }
      return PickedVideo(
        bytes: bytes,
        ext: 'mp4',
        path: f.path,
        duration: Duration(milliseconds: ms),
      );
    } finally {
      sub.unsubscribe();
      if (nav.canPop()) nav.pop();
      progress.dispose();
    }
  }

  static Future<PickedVideo> _webVideo(XFile picked, int maxSeconds, int maxMB) async {
    final bytes = await picked.readAsBytes();
    if (bytes.length > maxMB * 1024 * 1024) {
      throw MediaEditorException('Vidéo trop volumineuse (max ${maxMB}MB)');
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(picked.path));
    await c.initialize();
    final d = c.value.duration;
    await c.dispose();
    if (d.inSeconds > maxSeconds) {
      throw MediaEditorException(
        'Vidéo trop longue (max $maxSeconds s). Le découpage est disponible sur mobile.',
      );
    }
    return PickedVideo(
      bytes: bytes,
      ext: _extOf(picked.name, 'mp4'),
      path: picked.path,
      duration: d,
    );
  }
}

// ============================================================================
// ÉCRAN DE DÉCOUPE VIDÉO (choix du passage)
// ============================================================================
class VideoTrimPage extends StatefulWidget {
  const VideoTrimPage({super.key, required this.path, required this.maxSeconds});
  final String path;
  final int maxSeconds;

  @override
  State<VideoTrimPage> createState() => _VideoTrimPageState();
}

class _VideoTrimPageState extends State<VideoTrimPage> {
  VideoPlayerController? _c;
  double _total = 1;
  RangeValues _range = const RangeValues(0, 1);
  bool _ready = false;
  bool _mute = false;
  String? _error;

  static const double _minLen = 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = ThixMediaEditor.controllerFor(widget.path);
      await c.initialize();
      final total = math.max(1.0, c.value.duration.inMilliseconds / 1000.0);
      c.addListener(_onTick);
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _total = total;
        _range = RangeValues(0, math.min(total, widget.maxSeconds.toDouble()));
        _ready = true;
      });
      await c.play();
    } catch (e) {
      debugPrint('[Trim] init: $e');
      if (mounted) setState(() => _error = 'Lecture de la vidéo impossible');
    }
  }

  void _onTick() {
    final c = _c;
    if (c == null || !c.value.isInitialized || !c.value.isPlaying) return;
    final pos = c.value.position.inMilliseconds / 1000.0;
    if (pos >= _range.end - 0.05) {
      c.seekTo(Duration(milliseconds: (_range.start * 1000).round()));
    }
  }

  void _onRange(RangeValues v) {
    var s = v.start;
    var e = v.end;
    final max = widget.maxSeconds.toDouble();
    final startMoved = (s - _range.start).abs() > (e - _range.end).abs();

    if (e - s > max) {
      if (startMoved) {
        e = s + max;
      } else {
        s = e - max;
      }
    }
    if (e - s < _minLen) {
      if (startMoved) {
        s = e - _minLen;
      } else {
        e = s + _minLen;
      }
    }
    s = s.clamp(0.0, _total).toDouble();
    e = e.clamp(0.0, _total).toDouble();

    setState(() => _range = RangeValues(s, e));
    final seekTo = startMoved ? s : math.max(s, e - 0.5);
    _c?.seekTo(Duration(milliseconds: (seekTo * 1000).round()));
  }

  String _fmt(double sec) {
    final s = sec.round();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  void _done() {
    _c?.pause();
    Navigator.pop(
      context,
      VideoTrimResult(
        start: Duration(milliseconds: (_range.start * 1000).round()),
        end: Duration(milliseconds: (_range.end * 1000).round()),
        mute: _mute,
      ),
    );
  }

  @override
  void dispose() {
    _c?.removeListener(_onTick);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooLong = _total > widget.maxSeconds;
    final maxLabel = widget.maxSeconds % 60 == 0
        ? '${widget.maxSeconds ~/ 60} min'
        : '${widget.maxSeconds} s';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Découper la vidéo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _ready ? _done : null,
            child: const Text(
              'Terminé',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
            : !_ready
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final c = _c!;
                            c.value.isPlaying ? c.pause() : c.play();
                            setState(() {});
                          },
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _c!.value.aspectRatio,
                              child: VideoPlayer(_c!),
                            ),
                          ),
                        ),
                      ),
                      if (tooLong)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            'Vidéo trop longue : choisissez un passage de $maxLabel maximum.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: RangeSlider(
                          min: 0,
                          max: _total,
                          values: _range,
                          activeColor: const Color(0xFF00A4FF),
                          inactiveColor: Colors.white24,
                          onChanged: _onRange,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(_range.start), style: const TextStyle(color: Colors.white70)),
                            Text(
                              'Durée ${_fmt(_range.end - _range.start)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            Text(_fmt(_range.end), style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: IconButton(
                          tooltip: 'Couper le son',
                          icon: Icon(
                            _mute ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            setState(() => _mute = !_mute);
                            _c?.setVolume(_mute ? 0 : 1);
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
