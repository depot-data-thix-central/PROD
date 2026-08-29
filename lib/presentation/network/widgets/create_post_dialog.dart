// lib/presentation/network/widgets/create_post_dialog.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/presentation/certification/certification_tiers_page.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATIONS CENTRALISÉES
// ============================================================================
class _PostValidators {
  _PostValidators._();

  static String sanitizeText(String? input, {int maxLength = 5000}) {
    if (input == null || input.trim().isEmpty) return '';
    final document = html_parser.parse(input);
    var sanitized = document.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static bool validateFileSize(int bytes, {int maxSizeMB = 50}) {
    return bytes <= maxSizeMB * 1024 * 1024;
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
    // Audio (M4A/MP3)
    if (bytes[0] == 0xFF && bytes[1] == 0xFB) return null; // MP3
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return null; // M4A
    
    return 'Format de fichier non reconnu';
  }
}

// ============================================================================
// COMPRESSION ASYNCHRONE
// ============================================================================
Future<Uint8List> _compressImageBytes(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  try {
    return await compute((Uint8List input) async {
      return await FlutterImageCompress.compressWithList(input, minHeight: 1080, minWidth: 1080, quality: 85);
    }, bytes);
  } catch (e) {
    debugPrint('[Compression] Error: $e');
    return bytes;
  }
}

class _MediaItem {
  final Uint8List bytes;
  final String name;
  final bool isVideo;
  const _MediaItem(this.bytes, this.name, {this.isVideo = false});
}

class CreatePostDialog extends ConsumerStatefulWidget {
  final String? communityId;
  final VoidCallback? onPostCreated;
  const CreatePostDialog({super.key, this.communityId, this.onPostCreated});

  @override
  ConsumerState<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends ConsumerState<CreatePostDialog> with SingleTickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();

  final List<TextEditingController> _pollOptionControllers = [TextEditingController(), TextEditingController()];
  int _pollDurationDays = 1;
  final _challengeDescController = TextEditingController();
  final _challengeRewardController = TextEditingController();
  DateTime? _challengeEndDate;

  int _postTypeMode = 0;

  Color _selectedBgColor = Colors.transparent;
  final List<Color> _bgColors = const [
    Colors.transparent,
    Color(0xFF00A4FF),
    ThixPolicy.danger,
    ThixPolicy.success,
    ThixPolicy.gold,
    Color(0xFF8B5CF6),
    ThixPolicy.textMain
  ];

  final List<_MediaItem> _images = [];
  final List<_MediaItem> _videos = [];
  bool _isUploading = false;
  String? _errorMessage;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  Uint8List? _audioBytes;
  String? _localAudioPath;

  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentions = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Color> _textColors = const [
    ThixPolicy.textMain,
    ThixPolicy.primary,
    ThixPolicy.gold,
    ThixPolicy.danger,
    ThixPolicy.success
  ];

  static const int _maxCharsForBgColor = 150;
  int _previousTextLength = 0;

  // ─── LOGIQUE DE COMPTE (SÉCURITÉ & LIMITES) ───
  bool _isLoadingLimits = true;
  String _userTier = 'gratuit';
  int _audioPostsToday = 0;

  bool get _isFree => _userTier == 'gratuit' || _userTier == 'none';
  bool get _isStandard => _userTier == 'standard';
  bool get _isPremium => _userTier == 'premium';
  bool get _isEnterprise => _userTier == 'entreprise' || _userTier == 'enterprise';
  bool get _isOfficial => _userTier == 'officiel' || _userTier == 'official';

  bool get _canFormatText => !_isFree;
  bool get _canPostVideo => !_isFree;
  bool get _canCreatePoll => _isPremium || _isEnterprise || _isOfficial;
  bool get _canCreateChallenge => _isPremium || _isEnterprise || _isOfficial;
  bool get _hasWidePollOptions => _isEnterprise || _isOfficial;

  int get _maxTextLength => _isFree ? 280 : 5000;
  int get _maxPhotos => _isFree ? 1 : (_isStandard ? 4 : 10);
  int get _maxAudioDuration => _isFree ? 30 : (_isStandard ? 60 : 120);
  bool get _hasAudioDailyQuota => _isFree;
  static const int _freeAudioDailyLimit = 3;

  // Constantes de validation
  static const int _maxImageSizeMB = 10;
  static const int _maxVideoSizeMB = 100;
  static const int _maxAudioSizeMB = 20;
  static const Set<String> _allowedImageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const Set<String> _allowedVideoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
  static const Set<String> _allowedAudioExts = {'m4a', 'mp3', 'wav', 'aac'};
  static const int _maxPollOptionLength = 100;
  static const Duration _uploadTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadUserLimits();
    _contentController.addListener(_onContentChanged);
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _animationController.forward();
  }

  Future<void> _loadUserLimits() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('certification_tier')
          .eq('id', uid)
          .maybeSingle();

      final tier = (profile?['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';

      final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
      final audioCountRes = await Supabase.instance.client
          .from('posts')
          .select('id')
          .eq('user_id', uid)
          .eq('post_type', 'audio')
          .gte('created_at', startOfDay);

      if (mounted) {
        setState(() {
          _userTier = tier;
          _audioPostsToday = (audioCountRes as List).length;
          _isLoadingLimits = false;
        });
      }
    } catch (e) {
      debugPrint('[LoadLimits] Error: $e');
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _contentFocusNode.dispose();
    _challengeDescController.dispose();
    _challengeRewardController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  bool get _hasBgColor => _selectedBgColor != Colors.transparent;
  bool get _canHaveBgColor => _postTypeMode == 0 && _images.isEmpty && _videos.isEmpty && _audioBytes == null && _contentController.text.length <= _maxCharsForBgColor;

  String _colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _onContentChanged() {
    final text = _contentController.text;
    final currentLength = text.length;

    if (_isFree && currentLength > 280) {
      _contentController.text = text.substring(0, 280);
      _contentController.selection = TextSelection.collapsed(offset: 280);
      HapticFeedback.lightImpact();
      return;
    }

    if ((_previousTextLength <= _maxCharsForBgColor && currentLength > _maxCharsForBgColor) ||
        (_previousTextLength > _maxCharsForBgColor && currentLength <= _maxCharsForBgColor)) {
      setState(() {
        if (currentLength > _maxCharsForBgColor && _hasBgColor) _selectedBgColor = Colors.transparent;
      });
    }
    _previousTextLength = currentLength;

    final lastAt = text.lastIndexOf('@');
    if (lastAt == -1) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final query = text.substring(lastAt + 1);
    if (query.contains(' ') || query.contains('\n')) {
      setState(() => _showMentions = false);
    } else {
      setState(() => _showMentions = true);
      _searchUsers(query);
    }
  }

  Future<void> _searchUsers(String query) async {
    try {
      final users = await ref.read(networkServiceProvider).searchUsers(query);
      if (mounted) setState(() => _mentionSuggestions = users);
    } catch (e) {
      debugPrint('[Search] Error: $e');
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final text = _contentController.text;
    final lastAt = text.lastIndexOf('@');
    final before = text.substring(0, lastAt);
    final newText = '$before@${user['display_name']} ';
    _contentController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
    setState(() => _showMentions = false);
  }

  void _showUpgradeDialog(String featureName, String requiredTier) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.gold, size: 28),
            const SizedBox(width: 8),
            Text('Fonctionnalité bloquée', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text(
          "$featureName est réservée aux comptes $requiredTier et supérieurs.\n\nMettez à niveau votre compte pour débloquer de nouveaux outils pour votre communauté.",
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Plus tard', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificationTiersPage()));
            },
            child: Text('Voir les offres', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );
  }

  void _showAudioLimitDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Quota journalier atteint', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
        content: Text(
          "Vous avez atteint votre quota de $_freeAudioDailyLimit publications vocales par jour.\n\nVotre quota sera réinitialisé dans 24h, ou vous pouvez mettre à niveau votre abonnement pour publier sans limite.",
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Compris', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificationTiersPage()));
            },
            child: Text('Mettre à niveau', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkPermissionWithDisclosure(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;
    
    // Gérer le cas "permanently denied"
    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          title: Text('Permission requise', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          content: Text(
            'Vous avez précédemment refusé cette permission. Veuillez l\'activer dans les paramètres de l\'application.',
            style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Ouvrir les paramètres'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    if (!mounted) return false;

    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        surfaceTintColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: ThixPolicy.textMain, size: 28),
            const SizedBox(width: 10),
            Text("Autorisation requise", style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text(
          explanation,
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Annuler", style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.card,
              foregroundColor: ThixPolicy.textMain,
              elevation: 0,
              side: const BorderSide(color: ThixPolicy.textMain, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Compris", style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );

    if (userAgreed != true) return false;

    var newStatus = await permission.request();
    return newStatus.isGranted;
  }

  void _wrapSelection(String prefix, String suffix) {
    if (!_canFormatText) {
      _showUpgradeDialog('Le formatage du texte', 'Standard');
      return;
    }

    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) {
      final newText = '$text$prefix$suffix';
      _contentController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length - suffix.length));
    } else {
      final selected = text.substring(sel.start, sel.end);
      final newText = text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
      _contentController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: sel.start + prefix.length + selected.length + suffix.length));
    }
    _contentFocusNode.requestFocus();
  }

  void _applyBold() => _wrapSelection('**', '**');
  void _applyItalic() => _wrapSelection('*', '*');
  void _applyColor(Color color) {
    if (!_canFormatText) {
      _showUpgradeDialog('Les couleurs de texte', 'Standard');
      return;
    }
    _wrapSelection('{c:${_colorToHex(color)}}', '{c}');
  }

  void _resetBgColorIfMediaAdded() {
    if (_hasBgColor) setState(() => _selectedBgColor = Colors.transparent);
  }

  Future<void> _startRecording() async {
    if (_isUploading || _isRecording) return; // Protection race condition

    if (_hasAudioDailyQuota && _audioPostsToday >= _freeAudioDailyLimit) {
      _showAudioLimitDialog();
      return;
    }

    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.microphone,
      "Pour vous permettre d'enregistrer et de partager un message vocal dans votre publication, THIX ID a besoin d'accéder à votre microphone.",
    );
    if (!hasPerm) {
      if (mounted) setState(() => _errorMessage = 'Permission microphone refusée.');
      return;
    }

    try {
      String recordPath = kIsWeb ? 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a' : p.join((await getTemporaryDirectory()).path, 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), path: recordPath);

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _audioBytes = null;
        _localAudioPath = null;
        _resetBgColorIfMediaAdded();
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _recordDuration++);
        if (_recordDuration >= _maxAudioDuration) {
          _stopRecording();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Durée maximale atteinte ($_maxAudioDuration s)')));
        }
      });
    } catch (e) {
      debugPrint('[Record] Start error: $e');
      if (mounted) setState(() => _errorMessage = 'Impossible de démarrer l\'enregistrement.');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        
        // Validation taille
        if (!_PostValidators.validateFileSize(bytes.length, maxSizeMB: _maxAudioSizeMB)) {
          if (mounted) setState(() => _errorMessage = 'Audio trop volumineux (max ${_maxAudioSizeMB}MB)');
          return;
        }
        
        if (mounted) setState(() {
          _audioBytes = bytes;
          _localAudioPath = path;
        });
      }
    } catch (e) {
      debugPrint('[Record] Stop error: $e');
      if (mounted) setState(() => _errorMessage = 'Erreur lors de l\'enregistrement.');
    }
  }

  Future<void> _pickImages() async {
    if (_isUploading) return;
    
    if (_images.length >= _maxPhotos) {
      _showUpgradeDialog('Ajouter plus de photos', _isFree ? 'Standard' : 'Premium');
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (result != null && mounted) {
      setState(() {
        _resetBgColorIfMediaAdded();
        for (final f in result.files) {
          if (_images.length >= _maxPhotos) break;
          if (f.bytes == null) continue;
          
          // Validation taille
          if (!_PostValidators.validateFileSize(f.bytes!.length, maxSizeMB: _maxImageSizeMB)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${f.name}: trop volumineux (max ${_maxImageSizeMB}MB)'), backgroundColor: ThixPolicy.danger),
            );
            continue;
          }
          
          // Validation extension
          if (!_PostValidators.validateFileExtension(f.name, _allowedImageExts)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${f.name}: format non supporté'), backgroundColor: ThixPolicy.danger),
            );
            continue;
          }
          
          // Validation MIME
          final mimeError = _PostValidators.validateMime(f.bytes!);
          if (mimeError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${f.name}: $mimeError'), backgroundColor: ThixPolicy.danger),
            );
            continue;
          }
          
          _images.add(_MediaItem(f.bytes!, f.name));
        }
      });
    }
  }

  Future<void> _pickVideos() async {
    if (_isUploading) return;
    
    if (!_canPostVideo) {
      _showUpgradeDialog('La publication de vidéos', 'Standard');
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true, withData: true);
    if (result != null && mounted) {
      setState(() {
        _resetBgColorIfMediaAdded();
        for (final f in result.files) {
          if (f.bytes == null) continue;
          
          // Validation taille
          if (!_PostValidators.validateFileSize(f.bytes!.length, maxSizeMB: _maxVideoSizeMB)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${f.name}: trop volumineux (max ${_maxVideoSizeMB}MB)'), backgroundColor: ThixPolicy.danger),
            );
            continue;
          }
          
          // Validation extension
          if (!_PostValidators.validateFileExtension(f.name, _allowedVideoExts)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${f.name}: format vidéo non supporté'), backgroundColor: ThixPolicy.danger),
            );
            continue;
          }
          
          _videos.add(_MediaItem(f.bytes!, f.name, isVideo: true));
        }
      });
    }
  }

  Future<void> _pickCamera() async {
    if (_isUploading) return;
    
    if (_images.length >= _maxPhotos) {
      _showUpgradeDialog('Ajouter plus de photos', _isFree ? 'Standard' : 'Premium');
      return;
    }

    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.camera,
      "Pour vous permettre de prendre une photo directement depuis l'application et l'ajouter à votre publication, THIX ID a besoin d'accéder à votre caméra.",
    );
    if (!hasPerm) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        
        // Validation taille
        if (!_PostValidators.validateFileSize(bytes.length, maxSizeMB: _maxImageSizeMB)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Photo trop volumineuse (max ${_maxImageSizeMB}MB)'), backgroundColor: ThixPolicy.danger),
            );
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            _resetBgColorIfMediaAdded();
            _images.add(_MediaItem(bytes, photo.name));
          });
        }
      }
    } catch (e) {
      debugPrint("[Camera] Error: $e");
    }
  }

  void _removeMedia(int index, bool isVideo) {
    setState(() {
      if (isVideo) {
        _videos.removeAt(index);
      } else {
        _images.removeAt(index);
      }
    });
  }

  Future<void> _publishPost() async {
    if (_isUploading || _isRecording) return; // Protection race condition

    final textContent = _contentController.text.trim();
    setState(() => _errorMessage = null);

    // Validations
    if (_postTypeMode == 0 && textContent.isEmpty && _images.isEmpty && _videos.isEmpty && _audioBytes == null) {
      setState(() => _errorMessage = 'Ajoutez du texte, un média ou un audio');
      return;
    }
    if (_postTypeMode == 1 && textContent.isEmpty) {
      setState(() => _errorMessage = 'Saisissez la question du sondage');
      return;
    }
    if (_postTypeMode == 2 && (textContent.isEmpty || _challengeEndDate == null || _challengeDescController.text.trim().isEmpty)) {
      setState(() => _errorMessage = 'Titre, description et date de fin obligatoires');
      return;
    }

    // Validation options sondage
    if (_postTypeMode == 1) {
      final options = _pollOptionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (options.length < 2) {
        setState(() => _errorMessage = 'Au moins 2 options requises');
        return;
      }
      for (final opt in options) {
        if (opt.length > _maxPollOptionLength) {
          setState(() => _errorMessage = 'Options trop longues (max $_maxPollOptionLength caractères)');
          return;
        }
      }
    }

    setState(() => _isUploading = true);

    final uploadedUrls = <String>[];
    final ns = ref.read(networkServiceProvider);

    try {
      // Upload audio
      if (_audioBytes != null) {
        try {
          final url = await ns.uploadAudioBytes(_audioBytes!).timeout(_uploadTimeout);
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        } catch (e) {
          debugPrint('[Upload] Audio error: $e');
          throw Exception('Échec upload audio: $e');
        }
      }

      // Upload images
      for (final item in _images) {
        try {
          final compressed = await _compressImageBytes(item.bytes);
          final url = await ns.uploadImageBytes(compressed, fileExtension: item.name.split('.').last, bucket: 'post_images').timeout(_uploadTimeout);
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        } catch (e) {
          debugPrint('[Upload] Image error: $e');
          throw Exception('Échec upload image: $e');
        }
      }

      // Upload videos
      for (final item in _videos) {
        try {
          final url = await ns.uploadImageBytes(item.bytes, fileExtension: item.name.split('.').last, bucket: 'videos').timeout(_uploadTimeout);
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        } catch (e) {
          debugPrint('[Upload] Video error: $e');
          throw Exception('Échec upload vidéo: $e');
        }
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Non authentifié');

      String authorName = 'Moi';
      String? authorAvatar;
      String? authorTitle;
      try {
        final pr = await Supabase.instance.client.from('profiles').select('display_name, avatar_url, profession').eq('id', user.id).maybeSingle();
        if (pr != null) {
          authorName = pr['display_name']?.toString() ?? authorName;
          authorAvatar = pr['avatar_url']?.toString();
          authorTitle = pr['profession']?.toString();
        }
      } catch (e) {
        debugPrint('[Profile] Fetch error: $e');
      }

      // Sanitize tous les inputs texte
      final sanitizedContent = _PostValidators.sanitizeText(textContent, maxLength: _maxTextLength);
      final sanitizedChallengeDesc = _PostValidators.sanitizeText(_challengeDescController.text, maxLength: 2000);
      final sanitizedReward = _PostValidators.sanitizeText(_challengeRewardController.text, maxLength: 500);

      final payload = <String, dynamic>{
        'user_id': user.id,
        'content': sanitizedContent,
        'is_public': true,
        'image_urls': uploadedUrls.where((u) => u.contains('post_images')).toList(),
        'video_urls': uploadedUrls.where((u) => u.contains('videos')).toList(),
        'media_urls': uploadedUrls,
        'media_url': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
        'community_id': widget.communityId,
        'post_type': 'standard',
        if (_audioBytes != null) 'audio_duration_seconds': _recordDuration,
      };

      if (_postTypeMode == 0 && _audioBytes != null && _images.isEmpty && _videos.isEmpty) payload['post_type'] = 'audio';
      if (_canHaveBgColor && _hasBgColor) payload['bg_color'] = _colorToHex(_selectedBgColor);

      if (_postTypeMode == 1) {
        final options = _pollOptionControllers.map((c) => _PostValidators.sanitizeText(c.text.trim(), maxLength: _maxPollOptionLength)).where((t) => t.isNotEmpty).toList();
        payload['post_type'] = 'poll';
        payload['poll_data'] = {
          'options': options.map((o) => {'text': o, 'votes': []}).toList(),
          'end_date': DateTime.now().add(Duration(days: _pollDurationDays)).toIso8601String(),
        };
      } else if (_postTypeMode == 2) {
        payload['post_type'] = 'challenge';
        payload['challenge_data'] = {
          'description': sanitizedChallengeDesc,
          'reward': sanitizedReward,
          'end_date': _challengeEndDate?.toIso8601String(),
          'participants_count': 0,
          'participants': [],
        };
      }

      final inserted = await Supabase.instance.client.from('posts').insert(payload).select().single();
      final postId = inserted['id']?.toString() ?? '';

      final newPost = NetworkPost(
        id: postId,
        userId: user.id,
        authorName: authorName,
        authorAvatar: authorAvatar,
        authorTitle: authorTitle,
        content: sanitizedContent,
        bgColor: payload['bg_color'] as String?,
        mediaUrls: uploadedUrls,
        postType: PostType.values.asNameMap()[payload['post_type'] as String?] ?? PostType.standard,
        pollData: payload['poll_data'] as Map<String, dynamic>?,
        challengeData: payload['challenge_data'] as Map<String, dynamic>?,
        createdAt: DateTime.now(),
        likesCount: 0,
        commentsCount: 0,
        repostsCount: 0,
        isLiked: false,
        isSaved: false,
        isReposted: false,
        isPublic: true,
      );

      try {
        ref.read(feedProvider.notifier).addPostOnTop(newPost);
      } catch (e) {
        debugPrint('[Feed] Add post error: $e');
        ref.invalidate(feedProvider);
      }
      widget.onPostCreated?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication réussie'), backgroundColor: ThixPolicy.success),
      );
      Navigator.pop(context, newPost);
    } catch (e) {
      debugPrint('[Publish] Error: $e');
      
      // Rollback : supprimer les fichiers uploadés si l'insertion DB a échoué
      if (uploadedUrls.isNotEmpty) {
        try {
          // Extraire les paths des URLs et supprimer
          for (final url in uploadedUrls) {
            try {
              final uri = Uri.parse(url);
              final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
              final bucket = path.split('/').first;
              final filePath = path.replaceFirst('$bucket/', '');
              await Supabase.instance.client.storage.from(bucket).remove([filePath]);
            } catch (cleanupError) {
              debugPrint('[Cleanup] Error: $cleanupError');
            }
          }
        } catch (cleanupError) {
          debugPrint('[Cleanup] Global error: $cleanupError');
        }
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: ${e.toString().split('\n').first}';
          _isUploading = false;
        });
      }
    }
  }

  // ─────────────────────────── UI helpers ───────────────────────────

  Widget _typeTab(String label, int mode, IconData icon) {
    final sel = _postTypeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (mode == 1 && !_canCreatePoll) {
            _showUpgradeDialog('Les sondages', 'Premium');
            return;
          }
          if (mode == 2 && !_canCreateChallenge) {
            _showUpgradeDialog('Les challenges', 'Premium');
            return;
          }
          setState(() => _postTypeMode = mode);
        },
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: sel ? ThixPolicy.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: sel ? ThixPolicy.primary.withOpacity(0.25) : ThixPolicy.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: sel ? ThixPolicy.primary : ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: ThixPolicy.labelStyle.copyWith(fontWeight: sel ? ThixPolicy.bold : ThixPolicy.medium, color: sel ? ThixPolicy.primary : ThixPolicy.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatBtn({required Widget child, required VoidCallback onTap, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rXs), border: Border.all(color: ThixPolicy.border)),
          child: child,
        ),
      ),
    );
  }

  Widget _mediaBtn(IconData icon, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: (_isUploading || _isRecording) ? null : onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.28), width: 1.3)),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLimits) {
      return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
      backgroundColor: ThixPolicy.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.94,
          constraints: const BoxConstraints(maxHeight: 760),
          padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s20, ThixPolicy.s20, ThixPolicy.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Créer un post', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.2)),
                  const Spacer(),
                  InkWell(
                    onTap: _isUploading ? null : () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                    child: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: ThixPolicy.surface, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 17, color: ThixPolicy.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: ThixPolicy.s16),

              Row(
                children: [
                  _typeTab('Publication', 0, Icons.article_rounded),
                  const SizedBox(width: ThixPolicy.s8),
                  _typeTab('Sondage', 1, Icons.poll_rounded),
                  const SizedBox(width: ThixPolicy.s8),
                  _typeTab('Challenge', 2, Icons.emoji_events_rounded),
                ],
              ),
              const SizedBox(height: ThixPolicy.s14),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: ThixPolicy.s12),
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s10),
                  decoration: BoxDecoration(color: ThixPolicy.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.danger.withOpacity(0.15))),
                  child: Text(_errorMessage!, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger)),
                ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_postTypeMode != 2 && !_hasBgColor) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s10, vertical: ThixPolicy.s8),
                          decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                          child: Row(
                            children: [
                              _formatBtn(child: Text('B', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)), onTap: _applyBold, tooltip: 'Gras'),
                              const SizedBox(width: ThixPolicy.s8),
                              _formatBtn(child: Text('I', style: ThixPolicy.labelStyle.copyWith(fontStyle: FontStyle.italic, fontWeight: ThixPolicy.bold)), onTap: _applyItalic, tooltip: 'Italique'),
                              Container(width: 1, height: 18, color: ThixPolicy.border, margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s10)),
                              for (final color in _textColors)
                                Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: GestureDetector(
                                    onTap: () => _applyColor(color),
                                    child: Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.card, width: 2))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: ThixPolicy.s12),
                      ],

                      Container(
                        decoration: BoxDecoration(
                          color: _canHaveBgColor && _hasBgColor ? _selectedBgColor : ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          border: Border.all(color: _canHaveBgColor && _hasBgColor ? Colors.transparent : ThixPolicy.border),
                        ),
                        padding: _canHaveBgColor && _hasBgColor ? const EdgeInsets.symmetric(horizontal: 20, vertical: 40) : const EdgeInsets.all(15),
                        alignment: _canHaveBgColor && _hasBgColor ? Alignment.center : Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _contentController,
                              focusNode: _contentFocusNode,
                              maxLength: _isFree ? 280 : null,
                              minLines: _postTypeMode == 2 ? 2 : (_canHaveBgColor && _hasBgColor ? null : 5),
                              maxLines: _canHaveBgColor && _hasBgColor ? null : 10,
                              textAlign: _canHaveBgColor && _hasBgColor ? TextAlign.center : TextAlign.start,
                              style: ThixPolicy.bodyStyle.copyWith(
                                color: _canHaveBgColor && _hasBgColor ? Colors.white : ThixPolicy.textMain,
                                fontSize: _canHaveBgColor && _hasBgColor ? 22 : 14.5,
                                fontWeight: _canHaveBgColor && _hasBgColor ? ThixPolicy.bold : ThixPolicy.regular,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: _postTypeMode == 1 ? 'Posez votre question...' : _postTypeMode == 2 ? 'Titre du challenge...' : 'Commencer un post...',
                                hintStyle: ThixPolicy.bodyStyle.copyWith(color: _canHaveBgColor && _hasBgColor ? Colors.white70 : ThixPolicy.textSecondary),
                                border: InputBorder.none,
                                isCollapsed: true,
                                counterText: "",
                                fillColor: Colors.transparent,
                                filled: true,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                            if (_isFree && _postTypeMode == 0)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${_contentController.text.length} / 280',
                                    style: ThixPolicy.captionStyle.copyWith(
                                      fontWeight: ThixPolicy.bold,
                                      color: _contentController.text.length >= 280 ? ThixPolicy.danger : ThixPolicy.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),

                      if (_isRecording)
                        Container(
                          margin: const EdgeInsets.only(top: ThixPolicy.s12),
                          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                          decoration: BoxDecoration(color: ThixPolicy.danger.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.danger.withOpacity(0.2))),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: ThixPolicy.danger, size: 20),
                              const SizedBox(width: ThixPolicy.s12),
                              Text('Enregistrement... ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')} / 0${_maxAudioDuration ~/ 60}:${(_maxAudioDuration % 60).toString().padLeft(2, '0')}', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
                              const Spacer(),
                              GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: ThixPolicy.danger, size: 30)),
                            ],
                          ),
                        )
                      else if (_localAudioPath != null)
                        Container(
                          margin: const EdgeInsets.only(top: ThixPolicy.s12),
                          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s8),
                          decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                          child: Row(
                            children: [
                              Expanded(child: _DialogAudioPlayer(audioPath: _localAudioPath!)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.textSecondary, size: 20),
                                onPressed: () => setState(() {
                                  _audioBytes = null;
                                  _localAudioPath = null;
                                }),
                              ),
                            ],
                          ),
                        ),

                      if (_canHaveBgColor)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(top: ThixPolicy.s12),
                          child: Row(
                            children: _bgColors.map((c) {
                              final sel = _selectedBgColor == c;
                              return GestureDetector(
                                onTap: () {
                                  if (!_canFormatText && c != Colors.transparent) {
                                    _showUpgradeDialog('Les fonds colorés', 'Standard');
                                    return;
                                  }
                                  setState(() => _selectedBgColor = c);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 9),
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: sel ? ThixPolicy.textMain : ThixPolicy.borderStrong, width: sel ? 2.2 : 1.3)),
                                  child: c == Colors.transparent ? const Icon(Icons.format_color_reset_rounded, size: 15, color: Colors.black45) : null,
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else if (_postTypeMode == 0 && _images.isEmpty && _videos.isEmpty && _audioBytes == null && _contentController.text.length > _maxCharsForBgColor)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, left: 2),
                          child: Text('Texte trop long pour un fond coloré (max $_maxCharsForBgColor caractères).', style: ThixPolicy.captionStyle.copyWith(fontStyle: FontStyle.italic)),
                        ),

                      if (_postTypeMode == 1) ...[
                        const SizedBox(height: ThixPolicy.s16),
                        Text('Options', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                        const SizedBox(height: ThixPolicy.s8),
                        ..._pollOptionControllers.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: e.value,
                                    maxLength: _maxPollOptionLength,
                                    style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                                    decoration: InputDecoration(
                                      hintText: 'Option ${e.key + 1}',
                                      filled: true,
                                      fillColor: ThixPolicy.surface,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      counterText: '',
                                    ),
                                  ),
                                ),
                                if (e.key > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: ThixPolicy.danger, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _pollOptionControllers[e.key].dispose();
                                        _pollOptionControllers.removeAt(e.key);
                                      });
                                    },
                                  )
                              ],
                            ),
                          );
                        }),
                        if (_pollOptionControllers.length < (_hasWidePollOptions ? 8 : 4))
                          TextButton.icon(
                            onPressed: () => setState(() => _pollOptionControllers.add(TextEditingController())),
                            icon: const Icon(Icons.add_circle_outline, size: 17),
                            label: Text('Ajouter une option', style: ThixPolicy.labelStyle),
                          ),
                        const SizedBox(height: ThixPolicy.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _pollDurationDays,
                              isExpanded: true,
                              style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1 jour')),
                                DropdownMenuItem(value: 3, child: Text('3 jours')),
                                DropdownMenuItem(value: 7, child: Text('1 semaine'))
                              ],
                              onChanged: (v) => setState(() => _pollDurationDays = v ?? 1),
                            ),
                          ),
                        ),
                      ],

                      if (_postTypeMode == 2) ...[
                        const SizedBox(height: ThixPolicy.s16),
                        Text('Description du Challenge', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                        const SizedBox(height: ThixPolicy.s8),
                        TextField(
                          controller: _challengeDescController,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 2000,
                          style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Expliquez les règles et comment participer...',
                            filled: true,
                            fillColor: ThixPolicy.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(14),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: ThixPolicy.s12),
                        TextField(
                          controller: _challengeRewardController,
                          maxLength: 500,
                          style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Récompense (optionnel)',
                            filled: true,
                            fillColor: ThixPolicy.surface,
                            prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18, color: ThixPolicy.gold),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          style: TextButton.styleFrom(backgroundColor: ThixPolicy.surface, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => _challengeEndDate = picked);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 15, color: ThixPolicy.primary),
                          label: Text(
                            _challengeEndDate == null ? 'Choisir la date de fin' : 'Date de fin: ${_challengeEndDate!.day}/${_challengeEndDate!.month}/${_challengeEndDate!.year}',
                            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
                          ),
                        ),
                      ],

                      if (_showMentions && _mentionSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                          child: Column(
                            children: _mentionSuggestions
                                .map((u) => ListTile(
                                      dense: true,
                                      title: Text(u['display_name'] ?? '', style: ThixPolicy.bodyStyle.copyWith(fontSize: 13)),
                                      onTap: () => _insertMention(u),
                                    ))
                                .toList(),
                          ),
                        ),

                      if (_images.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (int i = 0; i < _images.length; i++)
                                Stack(
                                  children: [
                                    ClipRRect(borderRadius: BorderRadius.circular(ThixPolicy.rSm), child: Image.memory(_images[i].bytes, width: 82, height: 82, fit: BoxFit.cover)),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeMedia(i, false),
                                        child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)),
                                      ),
                                    )
                                  ],
                                ),
                            ],
                          ),
                        ),

                      if (_videos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (int i = 0; i < _videos.length; i++)
                                Stack(
                                  children: [
                                    Container(width: 82, height: 82, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(ThixPolicy.rSm)), child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28))),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeMedia(i, true),
                                        child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)),
                                      ),
                                    )
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  _mediaBtn(Icons.photo_rounded, _pickImages, ThixPolicy.success),
                  _mediaBtn(Icons.videocam_rounded, _pickVideos, ThixPolicy.danger),
                  _mediaBtn(Icons.photo_camera_rounded, _pickCamera, ThixPolicy.primary),
                  _mediaBtn(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded, _isRecording ? _stopRecording : _startRecording, ThixPolicy.gold),
                ],
              ),
              const SizedBox(height: ThixPolicy.s14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_isUploading || _isRecording) ? null : _publishPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ThixPolicy.surfaceStrong,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
                    elevation: 0,
                  ),
                  child: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Publier', style: ThixPolicy.buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogAudioPlayer extends StatefulWidget {
  final String audioPath;
  const _DialogAudioPlayer({required this.audioPath});
  @override
  State<_DialogAudioPlayer> createState() => _DialogAudioPlayerState();
}

class _DialogAudioPlayerState extends State<_DialogAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (kIsWeb) {
        await _player.setSourceUrl(widget.audioPath);
      } else {
        await _player.setSourceDeviceFile(widget.audioPath);
      }
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
    } catch (e) {
      debugPrint('[AudioPlayer] Init error: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (_isPlaying) {
              _player.pause();
            } else {
              _player.resume();
            }
          },
          child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(trackHeight: 2, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: ThixPolicy.primary, inactiveTrackColor: ThixPolicy.border, thumbColor: ThixPolicy.primary),
            child: Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
              onChanged: (val) {
                _player.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
      ],
    );
  }
}
