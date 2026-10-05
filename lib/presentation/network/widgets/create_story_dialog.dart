// lib/presentation/network/widgets/create_story_dialog.dart
// ============================================================================
// CRÉATEUR DE STORY — PLEIN ÉCRAN (design moderne type Instagram)
// • 3 modes : Texte (fonds colorés) • Photo • Audio (max 60 s)
// • Audio RÉPARÉ : upload storage direct avec contentType audio/mp4
// • Pré-écoute audio avant publication (play/pause/seek + re-record)
// • Rollback storage en cas d'échec
// ============================================================================
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
import 'package:uuid/uuid.dart';

import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _StoryValidators {
  _StoryValidators._();

  static const int maxTextLength = 300;
  static const int maxImageSizeMB = 10;
  static const int maxAudioSizeMB = 20;
  static const int maxAudioDurationSeconds = 60;
  static const Duration uploadTimeout = Duration(seconds: 30);

  static const Set<String> allowedImageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

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

  static String fmtDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
// POINT D'ENTRÉE (compatibilité ancien code)
// ============================================================================
class CreateStoryDialog {
  /// ✅ Ouvre le créateur de story PLEIN ÉCRAN.
  /// Remplace : showDialog(context, builder: (_) => const CreateStoryDialog())
  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CreateStoryPage()),
    );
  }
}

// ============================================================================
// PAGE PLEIN ÉCRAN
// ============================================================================
enum _StoryMode { text, photo, audio }

class CreateStoryPage extends ConsumerStatefulWidget {
  const CreateStoryPage({super.key});
  @override
  ConsumerState<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends ConsumerState<CreateStoryPage>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();

  _StoryMode _mode = _StoryMode.text;

  // Photo
  Uint8List? _imageBytes;
  String? _imageExt;

  // Audio
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  Uint8List? _audioBytes;
  String? _audioPath;

  // UI
  bool _isUploading = false;
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
    super.dispose();
  }

  bool get _hasBgColor => _bgColor != Colors.transparent;
  bool get _hasContent =>
      _textController.text.trim().isNotEmpty || _imageBytes != null || _audioBytes != null;

  String _colorToHex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  // ════════════════════════════════════════════════════════════════════════
  // PHOTO
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _pickImage() async {
    if (_isUploading || _isRecording) return;
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
        _mode = _StoryMode.photo;
        _imageBytes = f.bytes;
        _imageExt = f.extension ?? 'jpg';
        _audioBytes = null;
        _audioPath = null;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[Story] pickImage: $e');
      _showError('Erreur lors de la sélection');
    }
  }

  void _clearImage() => setState(() {
        _imageBytes = null;
        _imageExt = null;
        _mode = _StoryMode.text;
      });

  // ════════════════════════════════════════════════════════════════════════
  // AUDIO — ENREGISTREMENT RÉPARÉ
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _startRecording() async {
    if (_isUploading || _isRecording) return;

    final ok = await _checkPermission(
      Permission.microphone,
      'Pour enregistrer un message vocal dans votre story, THIX ID a besoin d\'accéder à votre microphone.',
    );
    if (!ok) return;

    try {
      // ✅ Vérifie dispo avant de démarrer
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
        _imageBytes = null;
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
  // PUBLICATION
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _createStory() async {
    if (_isUploading || _isRecording) return;

    final text = _textController.text.trim();
    if (!_hasContent) return _showError('Ajoutez du texte, une photo ou un audio');

    setState(() => _isUploading = true);
    String? uploadedUrl;
    String? uploadedPath; // pour rollback storage direct

    try {
      final service = ref.read(networkServiceProvider);
      String? mediaUrl;
      String mediaType = 'text';

      // ── PHOTO ──
      if (_mode == _StoryMode.photo && _imageBytes != null) {
        final compressed = await _compressImageAsync(_imageBytes!);
        mediaUrl = await service
            .uploadImageBytes(compressed, fileExtension: _imageExt ?? 'jpg', bucket: 'stories')
            .timeout(_StoryValidators.uploadTimeout);
        uploadedUrl = mediaUrl;
        mediaType = 'image';
      }

      // ── AUDIO : ✅ upload storage DIRECT avec bon contentType ──
      if (_mode == _StoryMode.audio && _audioBytes != null) {
        uploadedPath = 'audio/${const Uuid().v4()}.m4a';
        await Supabase.instance.client.storage
            .from('stories')
            .uploadBinary(
              uploadedPath!,
              _audioBytes!,
              fileOptions: const FileOptions(
                contentType: 'audio/mp4', // ✅ m4a/AAC = audio/mp4
                cacheControl: '31536000',
                upsert: false,
              ),
            )
            .timeout(_StoryValidators.uploadTimeout);
        mediaUrl = Supabase.instance.client.storage.from('stories').getPublicUrl(uploadedPath!);
        uploadedUrl = mediaUrl;
        mediaType = 'audio';
      }

      await service.createStory(
        mediaUrl,
        text: _StoryValidators.sanitizeText(text),
        duration: 24,
        mediaType: mediaType,
        bgColor: (_mode == _StoryMode.text && _hasBgColor) ? _colorToHex(_bgColor) : null,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[Story] create: $e');

      // Rollback storage
      try {
        if (uploadedPath != null) {
          await Supabase.instance.client.storage.from('stories').remove([uploadedPath]);
        } else if (uploadedUrl != null) {
          final uri = Uri.parse(uploadedUrl);
          final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
          final bucket = path.split('/').first;
          await Supabase.instance.client.storage.from(bucket).remove([path.replaceFirst('$bucket/', '')]);
        }
      } catch (clean) {
        debugPrint('[Story] cleanup: $clean');
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

  // ════════════════════════════════════════════════════════════════════════
  // BUILD — DESIGN PLEIN ÉCRAN
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── FOND / APERÇU ──
          Positioned.fill(child: _previewBackground()),

          // ── TEXTE CENTRÉ ──
          if (_mode != _StoryMode.audio)
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
                      color: _mode == _StoryMode.photo ? Colors.white : (_hasBgColor ? Colors.white : ThixPolicy.textMain),
                      fontSize: _hasBgColor || _mode == _StoryMode.photo ? 26 : 20,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      shadows: _mode == _StoryMode.photo
                          ? const [Shadow(color: Colors.black54, blurRadius: 8)]
                          : null,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                      hintText: 'Quoi de neuf ?',
                      hintStyle: TextStyle(
                        color: _mode == _StoryMode.photo
                            ? Colors.white70
                            : (_hasBgColor ? Colors.white70 : ThixPolicy.textSecondary),
                        fontSize: _hasBgColor || _mode == _StoryMode.photo ? 26 : 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── BARRE HAUTE ──
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _glassBtn(
                  icon: Icons.close_rounded,
                  onTap: _isUploading ? null : () => Navigator.pop(context, false),
                ),
                const Spacer(),
                // Bouton publier
                GestureDetector(
                  onTap: (_isUploading || _isRecording || !_hasContent) ? null : _createStory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: (_isUploading || _isRecording || !_hasContent)
                          ? null
                          : const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                      color: (_isUploading || _isRecording || !_hasContent) ? Colors.white24 : null,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),

          // ── PANNEAU BAS ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomPanel(),
          ),
        ],
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

  // ── Fond d'aperçu ──
  Widget _previewBackground() {
    if (_mode == _StoryMode.photo && _imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
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
                _isRecording
                    ? _StoryValidators.fmtDuration(_recordDuration)
                    : _StoryValidators.fmtDuration(_recordDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
    }
    // Texte
    if (_hasBgColor) return Container(color: _bgColor);
    return Container(color: ThixPolicy.surfaceSoft);
  }

  // ── Panneau bas contextuel ──
  Widget _bottomPanel() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isRecording ? _recordingPanel() : (_mode == _StoryMode.audio && _audioBytes != null) ? _audioPreviewPanel() : _defaultPanel(),
    );
  }

  // ── Panneau par défaut : couleurs + 3 actions ──
  Widget _defaultPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Couleurs (uniquement mode texte)
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
            _actionTile(Icons.image_rounded, 'Photo', ThixPolicy.success, _pickImage),
            const SizedBox(width: 10),
            _actionTile(Icons.mic_rounded, 'Audio', ThixPolicy.gold, _startRecording),
            const SizedBox(width: 10),
            _actionTile(Icons.format_size_rounded, 'Texte', ThixPolicy.primary, () {
              setState(() {
                _mode = _StoryMode.text;
                _imageBytes = null;
                _audioBytes = null;
                _audioPath = null;
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: (_isUploading || _isRecording) ? null : onTap,
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

  // ── Panneau d'enregistrement ──
  Widget _recordingPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Barre de progression 60 s
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
            // Mic pulsant
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: 1 + (_pulseCtrl.value * 0.12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
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

  // ── Panneau de pré-écoute audio ──
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
            const SizedBox(width: 10),
            _actionTile(Icons.image_rounded, 'Photo', ThixPolicy.success, _pickImage),
            const SizedBox(width: 10),
            _actionTile(Icons.delete_outline_rounded, 'Supprimer', ThixPolicy.danger, _clearAudio),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// PRÉ-ÉCOUTE AUDIO (play / pause / seek / durée)
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
                    max: total.inMilliseconds.toDouble() > 0 ? total.inMilliseconds.toDouble() : 1,
                    value: _position.inMilliseconds.toDouble().clamp(0, total.inMilliseconds.toDouble() > 0 ? total.inMilliseconds.toDouble() : 1),
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
