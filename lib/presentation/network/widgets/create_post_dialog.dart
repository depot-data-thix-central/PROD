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
import 'package:permission_handler/permission_handler.dart'; // NOUVEAU: Indispensable pour vérifier les accès

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/services/ai/ai_service.dart';

class _C {
  static const bg = Color(0xFFF7F9FC);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2D6CDF);
  static const primaryDeep = Color(0xFF123B7A);
  static const softBlue = Color(0xFFF0F4FC);
  static const gold = Color(0xFFD9A63C);
  static const textDark = Color(0xFF10192E);
  static const textSecondary = Color(0xFF8492AC);
  static const border = Color(0xFFEDF1F9);
  static const shadow = Color(0x0A2D6CDF);
  static const red = Color(0xFFE5484D);
  static const green = Color(0xFF059669);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1F44), primaryDeep, primary],
  );
}

Future<Uint8List> compressImageBytes(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  try {
    return await FlutterImageCompress.compressWithList(bytes, minHeight: 1080, minWidth: 1080, quality: 85);
  } catch (e) {
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

  int _postTypeMode = 0; // 0 standard · 1 sondage · 2 challenge

  Color _selectedBgColor = Colors.transparent;
  final List<Color> _bgColors = const [Colors.transparent, Color(0xFF00A4FF), Color(0xFFE5484D), Color(0xFF059669), Color(0xFFD9A63C), Color(0xFF8B5CF6), Color(0xFF10192E)];

  final List<_MediaItem> _images = [];
  final List<_MediaItem> _videos = [];
  bool _isUploading = false;
  String? _errorMessage;
  String? _factCheckStatusLabel;

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

  final List<Color> _textColors = const [_C.textDark, _C.primary, _C.gold, _C.red, _C.green];

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
  bool get _skipAICheck => _isEnterprise || _isOfficial;
  bool get _hasWidePollOptions => _isEnterprise || _isOfficial; 

  int get _maxTextLength => _isFree ? 280 : 5000;
  int get _maxPhotos => _isFree ? 1 : (_isStandard ? 4 : 10);
  int get _maxAudioDuration => _isFree ? 30 : (_isStandard ? 60 : 120);
  bool get _hasAudioDailyQuota => _isFree; 
  static const int _freeAudioDailyLimit = 3;

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
    for (final c in _pollOptionControllers) { c.dispose(); }
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
      debugPrint('search: $e');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: _C.gold, size: 28),
            const SizedBox(width: 8),
            const Text('Fonctionnalité bloquée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "$featureName est réservée aux comptes $requiredTier et supérieurs.\n\nMettez à niveau votre compte pour débloquer de nouveaux outils pour votre communauté.",
          style: const TextStyle(fontSize: 14, color: _C.textDark, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard', style: TextStyle(color: _C.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Voir les offres', style: TextStyle(color: _C.textDark, fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quota journalier atteint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.red)),
        content: Text(
          "Vous avez atteint votre quota de $_freeAudioDailyLimit publications vocales par jour.\n\nVotre quota sera réinitialisé dans 24h, ou vous pouvez mettre à niveau votre abonnement pour publier sans limite.",
          style: const TextStyle(fontSize: 14, color: _C.textDark, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris', style: TextStyle(color: _C.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { Navigator.pop(ctx); },
            child: const Text('Mettre à niveau', style: TextStyle(color: _C.textDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── GESTION DES PERMISSIONS PLAY STORE (PROMINENT DISCLOSURE) ───
  Future<bool> _checkPermissionWithDisclosure(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;

    if (!mounted) return false;

    // Affiche le design Blanc/Noir validé
    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Colors.black, size: 28),
            SizedBox(width: 10),
            Text("Autorisation", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          explanation,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              side: const BorderSide(color: Colors.black, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Compris", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (userAgreed != true) return false;

    // Vraie demande système
    var newStatus = await permission.request();
    return newStatus.isGranted;
  }

  void _wrapSelection(String prefix, String suffix) {
    if (!_canFormatText) { _showUpgradeDialog('Le formatage du texte', 'Standard'); return; }
    
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
    if (!_canFormatText) { _showUpgradeDialog('Les couleurs de texte', 'Standard'); return; }
    _wrapSelection('{c:${_colorToHex(color)}}', '{c}');
  }

  void _resetBgColorIfMediaAdded() {
    if (_hasBgColor) setState(() => _selectedBgColor = Colors.transparent);
  }

  Future<void> _startRecording() async {
    if (_hasAudioDailyQuota && _audioPostsToday >= _freeAudioDailyLimit) {
      _showAudioLimitDialog();
      return;
    }

    // 🚨 VÉRIFICATION SÉCURITÉ PLAY STORE
    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.microphone,
      "Pour enregistrer un message vocal, THIX ID a besoin d'accéder à votre microphone."
    );
    if (!hasPerm) {
      if (mounted) setState(() => _errorMessage = 'Permission microphone refusée.');
      return;
    }

    try {
      String recordPath = kIsWeb ? 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a' : p.join((await getTemporaryDirectory()).path, 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), path: recordPath);

      if (!mounted) return;
      setState(() { _isRecording = true; _recordDuration = 0; _audioBytes = null; _localAudioPath = null; _resetBgColorIfMediaAdded(); });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordDuration++);
        if (_recordDuration >= _maxAudioDuration) {
          _stopRecording();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Durée maximale atteinte ($_maxAudioDuration s)')));
        }
      });
    } catch (e) {
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
        if (mounted) setState(() { _audioBytes = bytes; _localAudioPath = path; });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur lors de l\'enregistrement.');
    }
  }

  Future<void> _pickImages() async {
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
          if (f.bytes != null) _images.add(_MediaItem(f.bytes!, f.name));
        }
      });
    }
  }

  Future<void> _pickVideos() async {
    if (!_canPostVideo) {
      _showUpgradeDialog('La publication de vidéos', 'Standard');
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true, withData: true);
    if (result != null && mounted) {
      setState(() {
        _resetBgColorIfMediaAdded();
        for (final f in result.files) { if (f.bytes != null) _videos.add(_MediaItem(f.bytes!, f.name, isVideo: true)); }
      });
    }
  }

  Future<void> _pickCamera() async {
    if (_images.length >= _maxPhotos) {
      _showUpgradeDialog('Ajouter plus de photos', _isFree ? 'Standard' : 'Premium');
      return;
    }

    // 🚨 VÉRIFICATION SÉCURITÉ PLAY STORE AVANT OUVERTURE CAMÉRA
    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.camera,
      "Pour prendre une photo depuis l'application, THIX ID a besoin d'accéder à votre caméra."
    );
    if (!hasPerm) return;

    // Utilisation corrigée: ImagePicker ouvre la vraie caméra (contrairement à FilePicker)
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (mounted) {
          setState(() { 
            _resetBgColorIfMediaAdded(); 
            _images.add(_MediaItem(bytes, photo.name)); 
          });
        }
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _removeMedia(int index, bool isVideo) {
    setState(() { if (isVideo) _videos.removeAt(index); else _images.removeAt(index); });
  }

  Future<Map<String, String?>> _runFactCheck(String textContent) async {
    if (_skipAICheck || textContent.isEmpty) {
      return {'isMisinformation': 'false', 'message': null, 'severity': null};
    }

    final webSources = <String>[];
    try {
      final response = await Supabase.instance.client.rpc('search_tavily', params: {'search_query': textContent});
      if (response != null && response['results'] != null) {
        for (final r in response['results'] as List) { webSources.add('- [${r['title'] ?? ''}](${r['url'] ?? ''}) : ${r['content'] ?? ''}'); }
      }
    } catch (e) { debugPrint('Tavily: $e'); }

    if (webSources.isEmpty) return {'isMisinformation': 'false', 'message': null, 'severity': null};

    try {
      final ai = AiService(Supabase.instance.client);
      final prompt = '''Date actuelle : ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\nSOURCES WEB :\n${webSources.join('\n')}\nRÈGLES : 1. Vérifie UNIQUEMENT Gouvernements, Visas, Lois, Élections. 2. Histoires perso / entreprises privées → SAFE. 3. FAKE seulement si fausse info officielle avérée.\nPUBLICATION : "$textContent"\nRéponds : SAFE ou FAKE: [raison]''';
      final aiResponse = await ai.askAi(prompt: prompt, provider: AiProvider.mistral, systemPrompt: 'Fact-checker gouvernemental. SAFE pour le privé. Réponds SAFE ou FAKE: raison.');
      if (aiResponse.trim().toUpperCase().startsWith('FAKE:')) {
        return {'isMisinformation': 'true', 'message': aiResponse.substring(aiResponse.toUpperCase().indexOf('FAKE:') + 5).trim(), 'severity': 'fake'};
      }
    } catch (e) { debugPrint('Fact-check AI: $e'); }

    return {'isMisinformation': 'false', 'message': null, 'severity': null};
  }

  Future<void> _publishPost() async {
    final textContent = _contentController.text.trim();
    setState(() => _errorMessage = null);

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

    setState(() {
      _isUploading = true;
      _factCheckStatusLabel = (textContent.isNotEmpty && !_skipAICheck) ? 'Vérification en cours…' : null;
    });

    try {
      final ns = ref.read(networkServiceProvider);
      
      Map<String, dynamic>? factCheckResult;
      try {
        factCheckResult = await _runFactCheck(textContent).timeout(const Duration(seconds: 10));
      } catch (e) {
        factCheckResult = {'isMisinformation': 'false', 'message': null, 'severity': null};
      }

      final isMisinfo = factCheckResult['isMisinformation'] == 'true';
      final fcMessage = factCheckResult['message'];
      final fcSeverity = factCheckResult['severity'];

      if (mounted) setState(() => _factCheckStatusLabel = 'Envoi des médias…');

      final allMedia = <String>[];
      final uploadedImages = <String>[];
      final uploadedVideos = <String>[];

      if (_audioBytes != null) {
        final url = await ns.uploadAudioBytes(_audioBytes!);
        if (url != null && url.isNotEmpty) allMedia.add(url);
      }

      for (final item in _images) {
        final compressed = await compressImageBytes(item.bytes);
        final url = await ns.uploadImageBytes(compressed, fileExtension: item.name.split('.').last, bucket: 'post_images');
        if (url != null && url.isNotEmpty) { allMedia.add(url); uploadedImages.add(url); }
      }

      for (final item in _videos) {
        final url = await ns.uploadImageBytes(item.bytes, fileExtension: item.name.split('.').last, bucket: 'videos');
        if (url != null && url.isNotEmpty) { allMedia.add(url); uploadedVideos.add(url); }
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Non authentifié');

      String authorName = 'Moi'; String? authorAvatar; String? authorTitle;
      try {
        final pr = await Supabase.instance.client.from('profiles').select('display_name, avatar_url, profession').eq('id', user.id).maybeSingle();
        if (pr != null) { authorName = pr['display_name']?.toString() ?? authorName; authorAvatar = pr['avatar_url']?.toString(); authorTitle = pr['profession']?.toString(); }
      } catch (_) {}

      final payload = <String, dynamic>{
        'user_id': user.id, 'content': textContent, 'is_public': true, 'is_fact_checked': true,
        'is_misinformation': isMisinfo, 'fact_check_message': fcMessage, 'fact_check_severity': fcSeverity,
        'image_urls': uploadedImages, 'video_urls': uploadedVideos, 'media_urls': allMedia,
        'media_url': allMedia.isNotEmpty ? allMedia.first : null, 'community_id': widget.communityId, 'post_type': 'standard',
        if (_audioBytes != null) 'audio_duration_seconds': _recordDuration,
      };

      if (_postTypeMode == 0 && _audioBytes != null && _images.isEmpty && _videos.isEmpty) payload['post_type'] = 'audio';
      if (_canHaveBgColor && _hasBgColor) payload['bg_color'] = _colorToHex(_selectedBgColor);

      if (_postTypeMode == 1) {
        final options = _pollOptionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        if (options.length < 2) { setState(() { _errorMessage = 'Au moins 2 options'; _isUploading = false; _factCheckStatusLabel = null; }); return; }
        payload['post_type'] = 'poll';
        payload['poll_data'] = {'options': options.map((o) => {'text': o, 'votes': []}).toList(), 'end_date': DateTime.now().add(Duration(days: _pollDurationDays)).toIso8601String()};
      } else if (_postTypeMode == 2) {
        payload['post_type'] = 'challenge';
        payload['challenge_data'] = {'description': _challengeDescController.text.trim(), 'reward': _challengeRewardController.text.trim(), 'end_date': _challengeEndDate?.toIso8601String(), 'participants_count': 0, 'participants': []};
      }

      final inserted = await Supabase.instance.client.from('posts').insert(payload).select().single();
      final postId = inserted['id']?.toString() ?? '';
      
      final newPost = NetworkPost(
        id: postId, userId: user.id, authorName: authorName, authorAvatar: authorAvatar, authorTitle: authorTitle,
        content: textContent, bgColor: payload['bg_color'] as String?, mediaUrls: allMedia,
        postType: payload['post_type'] as String? ?? 'standard', pollData: payload['poll_data'] as Map<String, dynamic>?,
        challengeData: payload['challenge_data'] as Map<String, dynamic>?, isFactChecked: true, isMisinformation: isMisinfo,
        factCheckMessage: fcMessage, factCheckSeverity: fcSeverity, createdAt: DateTime.now(), likesCount: 0, commentsCount: 0,
        repostsCount: 0, isLiked: false, isSaved: false, isReposted: false, isPublic: true,
      );

      try { ref.read(feedProvider.notifier).addPostOnTop(newPost); } catch (_) { ref.invalidate(feedProvider); }
      widget.onPostCreated?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMisinfo ? 'Publié avec avertissement Fact-Check' : 'Publication réussie'), backgroundColor: isMisinfo ? Colors.orange : _C.primary));
      Navigator.pop(context, newPost);
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Erreur: $e'; _isUploading = false; _factCheckStatusLabel = null; });
    }
  }

  // ─────────────────────────── UI helpers ───────────────────────────

  Widget _typeTab(String label, int mode, IconData icon) {
    final sel = _postTypeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (mode == 1 && !_canCreatePoll) { _showUpgradeDialog('Les sondages', 'Premium'); return; }
          if (mode == 2 && !_canCreateChallenge) { _showUpgradeDialog('Les challenges', 'Premium'); return; }
          setState(() => _postTypeMode = mode);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: sel ? _C.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? _C.primary.withOpacity(0.25) : _C.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: sel ? _C.primary : _C.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? _C.primary : _C.textSecondary)),
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30, height: 30, alignment: Alignment.center,
          decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: _C.white, shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.28), width: 1.3)),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLimits) {
      return const Center(child: CircularProgressIndicator(color: _C.primary));
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: _C.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.94,
          constraints: const BoxConstraints(maxHeight: 760),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Text('Créer une publication', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.textDark, letterSpacing: -0.2)),
                  const Spacer(),
                  InkWell(
                    onTap: _isUploading ? null : () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: _C.softBlue, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 17, color: _C.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  _typeTab('Publication', 0, Icons.article_rounded),
                  const SizedBox(width: 8),
                  _typeTab('Sondage', 1, Icons.poll_rounded),
                  const SizedBox(width: 8),
                  _typeTab('Challenge', 2, Icons.emoji_events_rounded),
                ],
              ),
              const SizedBox(height: 14),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3F3), borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.red.withOpacity(0.15))),
                  child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: _C.red)),
                ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_postTypeMode != 2 && !_hasBgColor) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: _C.softBlue, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              _formatBtn(child: const Text('B', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), onTap: _applyBold, tooltip: 'Gras'),
                              const SizedBox(width: 8),
                              _formatBtn(child: const Text('I', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, fontSize: 13)), onTap: _applyItalic, tooltip: 'Italique'),
                              Container(width: 1, height: 18, color: _C.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
                              for (final color in _textColors)
                                Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: GestureDetector(
                                    onTap: () => _applyColor(color),
                                    child: Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Zone texte
                      Container(
                        decoration: BoxDecoration(
                          color: _canHaveBgColor && _hasBgColor ? _selectedBgColor : _C.bg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _canHaveBgColor && _hasBgColor ? Colors.transparent : _C.border),
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
                              style: TextStyle(
                                color: _canHaveBgColor && _hasBgColor ? Colors.white : _C.textDark,
                                fontSize: _canHaveBgColor && _hasBgColor ? 22 : 14.5,
                                fontWeight: _canHaveBgColor && _hasBgColor ? FontWeight.w700 : FontWeight.w400,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: _postTypeMode == 1 ? 'Posez votre question...' : _postTypeMode == 2 ? 'Titre du challenge...' : 'Exprimez-vous...',
                                hintStyle: TextStyle(color: _canHaveBgColor && _hasBgColor ? Colors.white70 : _C.textSecondary),
                                border: InputBorder.none, isCollapsed: true, counterText: "",
                              ),
                            ),
                            if (_isFree && _postTypeMode == 0)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${_contentController.text.length} / 280',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _contentController.text.length >= 280 ? _C.red : _C.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),

                      if (_isRecording)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: _C.red.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.red.withOpacity(0.2))),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: _C.red, size: 20), const SizedBox(width: 12),
                              Text('Enregistrement... ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')} / 0${_maxAudioDuration~/60}:${(_maxAudioDuration%60).toString().padLeft(2,'0')}', style: const TextStyle(color: _C.red, fontWeight: FontWeight.w700, fontSize: 13)),
                              const Spacer(),
                              GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: _C.red, size: 30)),
                            ],
                          ),
                        )
                      else if (_localAudioPath != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: _C.primaryDeep, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Expanded(child: _DialogAudioPlayer(audioPath: _localAudioPath!)),
                              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 20), onPressed: () => setState(() { _audioBytes = null; _localAudioPath = null; })),
                            ],
                          ),
                        ),

                      if (_canHaveBgColor)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: _bgColors.map((c) {
                              final sel = _selectedBgColor == c;
                              return GestureDetector(
                                onTap: () {
                                  if (!_canFormatText && c != Colors.transparent) { _showUpgradeDialog('Les fonds colorés', 'Standard'); return; }
                                  setState(() => _selectedBgColor = c);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 9), width: 30, height: 30,
                                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: sel ? _C.textDark : Colors.grey.shade300, width: sel ? 2.2 : 1.3)),
                                  child: c == Colors.transparent ? const Icon(Icons.format_color_reset_rounded, size: 15, color: Colors.black45) : null,
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else if (_postTypeMode == 0 && _images.isEmpty && _videos.isEmpty && _audioBytes == null && _contentController.text.length > _maxCharsForBgColor)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, left: 2),
                          child: Text('Texte trop long pour un fond coloré (max $_maxCharsForBgColor caractères).', style: const TextStyle(fontSize: 11.5, color: _C.textSecondary, fontStyle: FontStyle.italic)),
                        ),

                      // Sondage
                      if (_postTypeMode == 1) ...[
                        const SizedBox(height: 16),
                        const Text('Options', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _C.textDark)),
                        const SizedBox(height: 8),
                        ..._pollOptionControllers.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: e.value, style: const TextStyle(fontSize: 13.5),
                                    decoration: InputDecoration(hintText: 'Option ${e.key + 1}', filled: true, fillColor: _C.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                                  ),
                                ),
                                if (e.key > 1) 
                                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: _C.red, size: 20), onPressed: () { setState(() { _pollOptionControllers[e.key].dispose(); _pollOptionControllers.removeAt(e.key); }); })
                              ],
                            ),
                          );
                        }),
                        if (_pollOptionControllers.length < (_hasWidePollOptions ? 8 : 4))
                          TextButton.icon(
                            onPressed: () => setState(() => _pollOptionControllers.add(TextEditingController())),
                            icon: const Icon(Icons.add_circle_outline, size: 17),
                            label: const Text('Ajouter une option', style: TextStyle(fontSize: 13)),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _pollDurationDays, isExpanded: true, style: const TextStyle(fontSize: 13.5, color: _C.textDark),
                              items: const [DropdownMenuItem(value: 1, child: Text('1 jour')), DropdownMenuItem(value: 3, child: Text('3 jours')), DropdownMenuItem(value: 7, child: Text('1 semaine'))],
                              onChanged: (v) => setState(() => _pollDurationDays = v ?? 1),
                            ),
                          ),
                        ),
                      ],

                      // Challenge
                      if (_postTypeMode == 2) ...[
                        const SizedBox(height: 16),
                        const Text('Description du Challenge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _C.textDark)),
                        const SizedBox(height: 8),
                        TextField(controller: _challengeDescController, minLines: 3, maxLines: 5, style: const TextStyle(fontSize: 13.5), decoration: InputDecoration(hintText: 'Expliquez les règles et comment participer...', filled: true, fillColor: _C.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(14))),
                        const SizedBox(height: 12),
                        TextField(controller: _challengeRewardController, style: const TextStyle(fontSize: 13.5), decoration: InputDecoration(hintText: 'Récompense (optionnel)', filled: true, fillColor: _C.bg, prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18, color: _C.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 14))),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          style: TextButton.styleFrom(backgroundColor: _C.bg, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (picked != null) setState(() => _challengeEndDate = picked);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 15, color: _C.primary),
                          label: Text(_challengeEndDate == null ? 'Choisir la date de fin' : 'Date de fin: ${_challengeEndDate!.day}/${_challengeEndDate!.month}/${_challengeEndDate!.year}', style: const TextStyle(color: _C.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],

                      if (_showMentions && _mentionSuggestions.isNotEmpty)
                        Container(margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)), child: Column(children: _mentionSuggestions.map((u) => ListTile(dense: true, title: Text(u['display_name'] ?? '', style: const TextStyle(fontSize: 13)), onTap: () => _insertMention(u))).toList())),

                      if (_images.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              for (int i = 0; i < _images.length; i++)
                                Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_images[i].bytes, width: 82, height: 82, fit: BoxFit.cover)), Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _removeMedia(i, false), child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white))))]),
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
                                Stack(children: [Container(width: 82, height: 82, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(14)), child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28))), Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _removeMedia(i, true), child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white))))]),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (_factCheckStatusLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 6),
                  child: Row(children: [const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)), const SizedBox(width: 8), Text(_factCheckStatusLabel!, style: const TextStyle(fontSize: 12, color: _C.textSecondary))]),
                ),

              Row(
                children: [
                  _mediaBtn(Icons.photo_rounded, _pickImages, _C.green),
                  _mediaBtn(Icons.videocam_rounded, _pickVideos, _C.red),
                  _mediaBtn(Icons.photo_camera_rounded, _pickCamera, _C.primary),
                  _mediaBtn(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded, _isRecording ? _stopRecording : _startRecording, _C.gold),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: (_isUploading || _isRecording) ? null : _C.gradientPrimary, color: (_isUploading || _isRecording) ? _C.softBlue : null, borderRadius: BorderRadius.circular(24), boxShadow: (_isUploading || _isRecording) ? null : [BoxShadow(color: _C.primary.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 6))]),
                  child: ElevatedButton(
                    onPressed: (_isUploading || _isRecording) ? null : _publishPost, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('PUBLIER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white, letterSpacing: 0.6)),
                  ),
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
  @override State<_DialogAudioPlayer> createState() => _DialogAudioPlayerState();
}

class _DialogAudioPlayerState extends State<_DialogAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override void initState() {
    super.initState();
    if (kIsWeb) _player.setSourceUrl(widget.audioPath); else _player.setSourceDeviceFile(widget.audioPath);
    _player.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _isPlaying = state == PlayerState.playing); });
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
  }

  @override void dispose() { _player.dispose(); super.dispose(); }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () { if (_isPlaying) _player.pause(); else _player.resume(); },
          child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: _C.gold, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: _C.primaryDeep, size: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(child: SliderTheme(data: SliderThemeData(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: _C.gold, inactiveTrackColor: Colors.white30, thumbColor: _C.gold), child: Slider(min: 0, max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0, value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0), onChanged: (val) { _player.seek(Duration(milliseconds: val.toInt())); }))),
        const SizedBox(width: 8),
        Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
