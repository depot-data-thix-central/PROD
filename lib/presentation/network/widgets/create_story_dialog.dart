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

  static const int maxTextLength = 500;
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 50;
  static const int maxAudioSizeMB = 20;
  static const int maxAudioDurationSeconds = 60;
  static const Duration uploadTimeout = Duration(seconds: 30);

  static const Set<String> allowedImageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const Set<String> allowedVideoExts = {'mp4', 'mov', 'webm', 'm4v'};
  static const Set<String> allowedAudioExts = {'m4a', 'mp3', 'wav', 'aac'};

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

  static bool validateFileSize(int bytes, int maxMB) {
    return bytes <= maxMB * 1024 * 1024;
  }

  static bool validateFileExtension(String filename, Set<String> allowed) {
    final ext = filename.split('.').last.toLowerCase();
    return allowed.contains(ext);
  }

  static String? validateMime(Uint8List bytes) {
    if (bytes.length < 12) return 'Fichier trop petit';
    
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return null;
    // PNG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return null;
    // WebP
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return null;
    // MP4/MOV
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return null;
    // MP3
    if (bytes[0] == 0xFF && bytes[1] == 0xFB) return null;
    // M4A (même signature que MP4)
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return null;
    
    return 'Format de fichier non reconnu';
  }
}

// ============================================================================
// COMPRESSION ASYNCHRONE
// ============================================================================
Future<Uint8List> _compressImageAsync(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  try {
    return await compute((Uint8List input) async {
      return await FlutterImageCompress.compressWithList(
        input,
        minHeight: 1080,
        minWidth: 1080,
        quality: 85,
      );
    }, bytes);
  } catch (e) {
    debugPrint('[Story] Compression error: $e');
    return bytes;
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class CreateStoryDialog extends ConsumerStatefulWidget {
  const CreateStoryDialog({super.key});
  @override
  ConsumerState<CreateStoryDialog> createState() => _CreateStoryDialogState();
}

class _CreateStoryDialogState extends ConsumerState<CreateStoryDialog> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  
  Uint8List? _mediaBytes;
  String? _mediaExt;
  String? _mediaType; // image | video | audio
  String? _mediaName;
  bool _isUploading = false;
  bool _isRecording = false;
  
  final int _duration = 24;
  final _picker = ImagePicker();
  
  // Audio
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _recordTimer;
  int _recordDuration = 0;
  String? _localAudioPath;
  bool _isPlayingAudio = false;
  
  // Fond coloré
  Color _selectedBgColor = Colors.transparent;
  final List<Color> _bgColors = [
    Colors.transparent,
    const Color(0xFF00A4FF),
    ThixPolicy.danger,
    ThixPolicy.success,
    ThixPolicy.gold,
    const Color(0xFF8B5CF6),
    ThixPolicy.textMain,
  ];
  
  // Animations
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  // Mentions
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentions = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    
    // Détection mentions
    final lastAt = text.lastIndexOf('@');
    if (lastAt == -1) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    
    final query = text.substring(lastAt + 1);
    if (query.contains(' ') || query.contains('\n')) {
      if (_showMentions) setState(() => _showMentions = false);
    } else if (query.length >= 2) {
      setState(() => _showMentions = true);
      _searchUsers(query);
    }
  }

  Future<void> _searchUsers(String query) async {
    try {
      final users = await ref.read(networkServiceProvider).searchUsers(query);
      if (mounted) setState(() => _mentionSuggestions = users);
    } catch (e) {
      debugPrint('[Story] Search error: $e');
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final text = _textController.text;
    final lastAt = text.lastIndexOf('@');
    final before = text.substring(0, lastAt);
    final newText = '$before@${user['display_name']} ';
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    setState(() => _showMentions = false);
  }

  bool get _hasBgColor => _selectedBgColor != Colors.transparent;
  bool get _canHaveBgColor => _mediaBytes == null && _textController.text.length <= 150;
  bool get _hasContent => _textController.text.trim().isNotEmpty || _mediaBytes != null;

  // ─── PERMISSIONS ───
  Future<bool> _checkPermission(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    
    var status = await permission.status;
    if (status.isGranted) return true;
    
    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          title: const Text('Permission requise', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Vous avez précédemment refusé cette permission. Veuillez l\'activer dans les paramètres.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Paramètres')),
          ],
        ),
      );
      if (openSettings == true) await openAppSettings();
      return false;
    }
    
    if (!mounted) return false;
    
    final userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: ThixPolicy.primary, size: 28),
            const SizedBox(width: 10),
            const Text('Autorisation requise', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(explanation, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
    
    if (userAgreed != true) return false;
    
    final newStatus = await permission.request();
    return newStatus.isGranted;
  }

  // ─── PICKERS ───
  Future<void> _pickImage() async {
    if (_isUploading) return;
    
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      
      final f = result.files.first;
      if (f.bytes == null) {
        _showError('Impossible de lire le fichier');
        return;
      }
      
      // Validation taille
      if (!_StoryValidators.validateFileSize(f.bytes!.length, _StoryValidators.maxImageSizeMB)) {
        _showError('Image trop volumineuse (max ${_StoryValidators.maxImageSizeMB}MB)');
        return;
      }
      
      // Validation extension
      if (!_StoryValidators.validateFileExtension(f.name, _StoryValidators.allowedImageExts)) {
        _showError('Format non supporté');
        return;
      }
      
      // Validation MIME
      final mimeError = _StoryValidators.validateMime(f.bytes!);
      if (mimeError != null) {
        _showError(mimeError);
        return;
      }
      
      setState(() {
        _mediaBytes = f.bytes;
        _mediaExt = f.extension ?? 'jpg';
        _mediaType = 'image';
        _mediaName = f.name;
        if (_hasBgColor) _selectedBgColor = Colors.transparent;
      });
      
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[Story] Pick image error: $e');
      _showError('Erreur lors de la sélection');
    }
  }

  Future<void> _pickVideo() async {
    if (_isUploading) return;
    
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: !kIsWeb);
      if (result == null || result.files.isEmpty) return;
      
      final f = result.files.first;
      
      // Sur Web, les bytes peuvent être null pour les gros fichiers
      if (kIsWeb && f.bytes == null) {
        _showError('Vidéo trop volumineuse pour le Web');
        return;
      }
      
      if (f.bytes == null) {
        _showError('Impossible de lire la vidéo');
        return;
      }
      
      // Validation taille
      if (!_StoryValidators.validateFileSize(f.bytes!.length, _StoryValidators.maxVideoSizeMB)) {
        _showError('Vidéo trop volumineuse (max ${_StoryValidators.maxVideoSizeMB}MB)');
        return;
      }
      
      // Validation extension
      if (!_StoryValidators.validateFileExtension(f.name, _StoryValidators.allowedVideoExts)) {
        _showError('Format vidéo non supporté');
        return;
      }
      
      setState(() {
        _mediaBytes = f.bytes;
        _mediaExt = f.extension ?? 'mp4';
        _mediaType = 'video';
        _mediaName = f.name;
        if (_hasBgColor) _selectedBgColor = Colors.transparent;
      });
      
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[Story] Pick video error: $e');
      _showError('Erreur lors de la sélection vidéo');
    }
  }

  Future<void> _recordShortVideo() async {
    if (_isUploading || kIsWeb) {
      if (kIsWeb) _showError('Caméra non supportée sur Web');
      return;
    }
    
    final hasPerm = await _checkPermission(
      Permission.camera,
      'Pour enregistrer une vidéo story, THIX ID a besoin d\'accéder à votre caméra.',
    );
    if (!hasPerm) return;
    
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 45),
      );
      
      if (video == null) return;
      
      final bytes = await video.readAsBytes();
      
      if (!_StoryValidators.validateFileSize(bytes.length, _StoryValidators.maxVideoSizeMB)) {
        _showError('Vidéo trop volumineuse (max ${_StoryValidators.maxVideoSizeMB}MB)');
        return;
      }
      
      setState(() {
        _mediaBytes = bytes;
        _mediaExt = 'mp4';
        _mediaType = 'video';
        _mediaName = video.name;
        if (_hasBgColor) _selectedBgColor = Colors.transparent;
      });
      
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[Story] Record video error: $e');
      _showError('Caméra indisponible');
    }
  }

  // ─── AUDIO ───
  Future<void> _startRecording() async {
    if (_isUploading || _isRecording) return;
    
    final hasPerm = await _checkPermission(
      Permission.microphone,
      'Pour enregistrer un message vocal, THIX ID a besoin d\'accéder à votre microphone.',
    );
    if (!hasPerm) return;
    
    try {
      final recordPath = kIsWeb
          ? 'story_audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : p.join((await getTemporaryDirectory()).path, 'story_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: recordPath,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _mediaBytes = null;
        _localAudioPath = null;
        if (_hasBgColor) _selectedBgColor = Colors.transparent;
      });
      
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _recordDuration++);
        
        if (_recordDuration >= _StoryValidators.maxAudioDurationSeconds) {
          _stopRecording();
          _showInfo('Durée maximale atteinte (${_StoryValidators.maxAudioDurationSeconds}s)');
        }
      });
      
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[Story] Start recording error: $e');
      _showError('Impossible de démarrer l\'enregistrement');
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
          _showError('Audio trop volumineux');
          return;
        }
        
        setState(() {
          _mediaBytes = bytes;
          _mediaType = 'audio';
          _mediaExt = 'm4a';
          _mediaName = 'audio.m4a';
          _localAudioPath = path;
        });
      }
    } catch (e) {
      debugPrint('[Story] Stop recording error: $e');
      _showError('Erreur lors de l\'enregistrement');
    }
  }

  Future<void> _playAudioPreview() async {
    if (_localAudioPath == null) return;
    
    try {
      if (_isPlayingAudio) {
        await _audioPlayer.pause();
        setState(() => _isPlayingAudio = false);
      } else {
        if (kIsWeb) {
          await _audioPlayer.setSourceUrl(_localAudioPath!);
        } else {
          await _audioPlayer.setSourceDeviceFile(_localAudioPath!);
        }
        await _audioPlayer.resume();
        setState(() => _isPlayingAudio = true);
      }
    } catch (e) {
      debugPrint('[Story] Play audio error: $e');
    }
  }

  void _removeMedia() {
    setState(() {
      _mediaBytes = null;
      _mediaType = null;
      _mediaExt = null;
      _mediaName = null;
      _localAudioPath = null;
      _isPlayingAudio = false;
    });
    HapticFeedback.selectionClick();
  }

  // ─── PREVIEW PLEIN ÉCRAN ───
  Future<void> _previewFullScreen() async {
    if (_mediaBytes == null) return;
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StoryPreviewScreen(
          mediaBytes: _mediaBytes!,
          mediaType: _mediaType ?? 'image',
          text: _textController.text.trim(),
          bgColor: _selectedBgColor,
        ),
      ),
    );
  }

  // ─── PUBLICATION ───
  Future<void> _createStory() async {
    if (_isUploading || _isRecording) return;
    
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaBytes == null) {
      _showError('Ajoutez du texte ou un média');
      return;
    }
    
    setState(() => _isUploading = true);
    
    String? uploadedUrl;
    
    try {
      final service = ref.read(networkServiceProvider);
      String? mediaUrl;
      
      if (_mediaBytes != null) {
        Uint8List uploadBytes = _mediaBytes!;
        
        // Compression image asynchrone
        if (_mediaType == 'image' && !kIsWeb) {
          try {
            uploadBytes = await _compressImageAsync(_mediaBytes!);
          } catch (e) {
            debugPrint('[Story] Compression failed: $e');
          }
        }
        
        // Upload avec timeout
        mediaUrl = await service
            .uploadImageBytes(uploadBytes, fileExtension: _mediaExt ?? 'jpg', bucket: 'stories')
            .timeout(_StoryValidators.uploadTimeout);
        
        uploadedUrl = mediaUrl;
      }
      
      // Sanitize le texte
      final sanitizedText = _StoryValidators.sanitizeText(text);
      final sanitizedBgColor = _hasBgColor ? _colorToHex(_selectedBgColor) : null;
      
      await service.createStory(
        mediaUrl,
        text: sanitizedText,
        duration: _duration,
        mediaType: _mediaType ?? (_hasBgColor ? 'text' : 'image'),
      );
      
      if (!mounted) return;
      
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[Story] Create error: $e');
      
      // Rollback : supprimer le fichier uploadé si l'insertion a échoué
      if (uploadedUrl != null) {
        try {
          final uri = Uri.parse(uploadedUrl);
          final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
          final bucket = path.split('/').first;
          final filePath = path.replaceFirst('$bucket/', '');
          await Supabase.instance.client.storage.from(bucket).remove([filePath]);
        } catch (cleanupError) {
          debugPrint('[Story] Cleanup error: $cleanupError');
        }
      }
      
      _showError('Erreur de publication : ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _showError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(m, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfo(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
      backgroundColor: ThixPolicy.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: MediaQuery.of(context).size.width,
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
          padding: const EdgeInsets.all(ThixPolicy.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: ThixPolicy.s16),
              Expanded(child: _buildContentArea()),
              if (_showMentions && _mentionSuggestions.isNotEmpty) _buildMentionList(),
              if (_mediaBytes != null) _buildMediaPreview(),
              if (_canHaveBgColor) _buildBgColorPicker(),
              const SizedBox(height: ThixPolicy.s12),
              _buildActionBar(),
              const SizedBox(height: ThixPolicy.s16),
              _buildPublishButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Créer une Story',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
            ),
          ],
        ),
        GestureDetector(
          onTap: _isUploading ? null : () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThixPolicy.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: ThixPolicy.textMain, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildContentArea() {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: _hasBgColor ? _selectedBgColor : ThixPolicy.surface,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: _hasBgColor ? null : Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _textFocusNode,
              maxLines: null,
              maxLength: _StoryValidators.maxTextLength,
              keyboardType: TextInputType.multiline,
              textAlign: _hasBgColor ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: _hasBgColor ? Colors.white : ThixPolicy.textMain,
                fontSize: _hasBgColor ? 22 : 15,
                fontWeight: _hasBgColor ? FontWeight.bold : FontWeight.normal,
                height: 1.4,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _hasBgColor ? 'Votre message...' : 'Quoi de neuf dans votre monde pro ?',
                hintStyle: TextStyle(color: _hasBgColor ? Colors.white70 : ThixPolicy.textSecondary.withOpacity(0.6)),
                counterText: '',
              ),
            ),
          ),
          if (_textController.text.isNotEmpty)
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${_textController.text.length}/${_StoryValidators.maxTextLength}',
                style: TextStyle(
                  fontSize: 11,
                  color: _hasBgColor ? Colors.white70 : ThixPolicy.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMentionList() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _mentionSuggestions.take(5).map((u) {
          final name = u['display_name']?.toString() ?? '';
          final avatar = u['avatar_url']?.toString();
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: ThixPolicy.surfaceSoft,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null ? const Icon(Icons.person, size: 16) : null,
            ),
            title: Text(name, style: const TextStyle(fontSize: 13)),
            onTap: () => _insertMention(u),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _mediaType == 'image' ? _previewFullScreen : null,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                image: _mediaType == 'image'
                    ? DecorationImage(image: MemoryImage(_mediaBytes!), fit: BoxFit.cover)
                    : null,
              ),
              child: _mediaType == 'video'
                  ? const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36))
                  : _mediaType == 'audio'
                      ? GestureDetector(
                          onTap: _playAudioPreview,
                          child: Center(
                            child: Icon(
                              _isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        )
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _mediaType == 'image' ? 'Image' : _mediaType == 'video' ? 'Vidéo' : 'Audio',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(_mediaBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary),
                ),
                if (_mediaType == 'audio' && _recordDuration > 0)
                  Text(
                    'Durée : ${_recordDuration}s',
                    style: const TextStyle(fontSize: 11, color: ThixPolicy.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_rounded, color: ThixPolicy.textSecondary),
            onPressed: _removeMedia,
          ),
        ],
      ),
    );
  }

  Widget _buildBgColorPicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: _bgColors.map((c) {
          final sel = _selectedBgColor == c;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedBgColor = c);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 9),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c == Colors.transparent ? ThixPolicy.surface : c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? ThixPolicy.textMain : ThixPolicy.border,
                  width: sel ? 2.5 : 1.3,
                ),
              ),
              child: c == Colors.transparent
                  ? const Icon(Icons.format_color_reset_rounded, size: 16, color: ThixPolicy.textSecondary)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMediaButton(Icons.image_rounded, ThixPolicy.success, _pickImage, 'Photo'),
        _buildMediaButton(Icons.folder_shared_rounded, ThixPolicy.warning, _pickVideo, 'Vidéo'),
        _buildMediaButton(Icons.videocam_rounded, ThixPolicy.danger, _recordShortVideo, 'Caméra'),
        _buildMediaButton(
          _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
          ThixPolicy.gold,
          _isRecording ? _stopRecording : _startRecording,
          _isRecording ? 'Arrêter' : 'Audio',
        ),
      ],
    );
  }

  Widget _buildMediaButton(IconData icon, Color color, VoidCallback onTap, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: label,
          child: InkWell(
            onTap: _isUploading ? null : onTap,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_isUploading || _isRecording || !_hasContent) ? null : _createStory,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThixPolicy.gold,
          foregroundColor: ThixPolicy.inkDeep,
          disabledBackgroundColor: ThixPolicy.surfaceStrong,
          disabledForegroundColor: ThixPolicy.textSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        ),
        child: _isUploading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: ThixPolicy.inkDeep, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text('PUBLIER LA STORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                ],
              ),
      ),
    );
  }
}

// ============================================================================
// PREVIEW PLEIN ÉCRAN
// ============================================================================
class _StoryPreviewScreen extends StatelessWidget {
  final Uint8List mediaBytes;
  final String mediaType;
  final String text;
  final Color bgColor;

  const _StoryPreviewScreen({
    required this.mediaBytes,
    required this.mediaType,
    required this.text,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (mediaType == 'image')
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.memory(mediaBytes, fit: BoxFit.contain),
            ),
          if (text.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            top: 50,
            right: 20,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
