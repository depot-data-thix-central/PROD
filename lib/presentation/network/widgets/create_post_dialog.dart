// lib/presentation/network/widgets/create_post_dialog.dart
// ============================================================================
// CRÉATION DE POST — PLEIN ÉCRAN (enterprise)
// • Suggestions @mentions + #hashtags en temps réel (comme les grands RS)
// • Sondages : choix multiple, durées, reorder, compteur
// • Challenges : date+heure, récompense, participants max
// • Tiers & quotas conservés • Médias/audio conservés • Rollback conservé
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
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
import 'package:cached_network_image/cached_network_image.dart';

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

  static bool validateFileSize(int bytes, {int maxSizeMB = 50}) =>
      bytes <= maxSizeMB * 1024 * 1024;

  static bool validateFileExtension(String filename, Set<String> allowed) {
    final ext = filename.split('.').last.toLowerCase();
    return allowed.contains(ext);
  }

  static String? validateMime(Uint8List bytes) {
    if (bytes.length < 12) return 'Fichier trop petit';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return null;
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return null;
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return null;
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return null;
    if (bytes[0] == 0xFF && bytes[1] == 0xFB) return null;
    return 'Format de fichier non reconnu';
  }

  static List<String> extractHashtags(String text) {
    final matches = RegExp(r'#([A-Za-z0-9_]{2,30})').allMatches(text);
    final tags = <String>{};
    for (final m in matches) {
      tags.add(m.group(1)!.toLowerCase());
    }
    return tags.toList();
  }
}

// ============================================================================
// COMPRESSION
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

// ============================================================================
// SUGGESTIONS : TOKEN ACTIF (@ ou #)
// ============================================================================
enum _TokenType { mention, hashtag }

class _ActiveToken {
  final _TokenType type;
  final String query;
  final int start;
  final int end;
  const _ActiveToken({required this.type, required this.query, required this.start, required this.end});
}

class _HashtagSuggestion {
  final String tag;
  final int count;
  const _HashtagSuggestion(this.tag, this.count);
}

// ============================================================================
// POINT D'ENTRÉE (compatibilité ancien code)
// ============================================================================
class CreatePostDialog {
  /// ✅ Ouvre l'écran de création PLEIN ÉCRAN.
  /// Remplace les anciens appels showDialog(CreatePostDialog(...)).
  static Future<NetworkPost?> show(
    BuildContext context, {
    String? communityId,
    VoidCallback? onPostCreated,
  }) {
    return Navigator.of(context).push<NetworkPost>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreatePostPage(
          communityId: communityId,
          onPostCreated: onPostCreated,
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE PLEIN ÉCRAN
// ============================================================================
class CreatePostPage extends ConsumerStatefulWidget {
  final String? communityId;
  final VoidCallback? onPostCreated;
  const CreatePostPage({super.key, this.communityId, this.onPostCreated});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();

  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _pollDurationDays = 1;
  bool _pollMultiple = false;

  final _challengeDescController = TextEditingController();
  final _challengeRewardController = TextEditingController();
  final _challengeMaxController = TextEditingController();
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
    ThixPolicy.textMain,
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

  // ── Suggestions @ / # ──
  _ActiveToken? _token;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  List<_HashtagSuggestion> _hashtagSuggestions = [];
  bool _showSuggestions = false;
  bool _loadingSuggestions = false;
  Timer? _suggestDebounce;
  final Set<String> _mentionedIds = {};

  // ── Profil auteur ──
  String _authorName = 'Moi';
  String? _authorAvatar;
  bool _isPublic = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Color> _textColors = const [
    ThixPolicy.textMain,
    ThixPolicy.primary,
    ThixPolicy.gold,
    ThixPolicy.danger,
    ThixPolicy.success,
  ];

  static const int _maxCharsForBgColor = 150;
  int _previousTextLength = 0;

  // ── LOGIQUE DE COMPTE (SÉCURITÉ & LIMITES) ──
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

  static const int _maxImageSizeMB = 10;
  static const int _maxVideoSizeMB = 100;
  static const int _maxAudioSizeMB = 20;
  static const Set<String> _allowedImageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const Set<String> _allowedVideoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
  static const Set<String> _allowedAudioExts = {'m4a', 'mp3', 'wav', 'aac'};
  static const int _maxPollOptionLength = 100;
  static const Duration _uploadTimeout = Duration(seconds: 30);
  static const Duration _suggestTimeout = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _loadUserLimits();
    _contentController.addListener(_onContentChanged);
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _animationController.forward();
  }

  Future<void> _loadUserLimits() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('certification_tier, display_name, full_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();

      final tier = (profile?['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';
      final name = profile?['display_name']?.toString() ?? profile?['full_name']?.toString();
      final avatar = profile?['avatar_url']?.toString();

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
          if (name != null && name.isNotEmpty) _authorName = name;
          _authorAvatar = avatar;
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
    _suggestDebounce?.cancel();
    _audioRecorder.dispose();
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _contentFocusNode.dispose();
    _challengeDescController.dispose();
    _challengeRewardController.dispose();
    _challengeMaxController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  bool get _hasBgColor => _selectedBgColor != Colors.transparent;
  bool get _canHaveBgColor => _postTypeMode == 0 &&
      _images.isEmpty &&
      _videos.isEmpty &&
      _audioBytes == null &&
      _contentController.text.length <= _maxCharsForBgColor;

  String _colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).substring(2).toUpperCase()}';
  }

  // ════════════════════════════════════════════════════════════════════════
  // DÉTECTION @ / # + SUGGESTIONS
  // ════════════════════════════════════════════════════════════════════════
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

    _updateToken();
    if (mounted) setState(() {});
  }

  void _updateToken() {
    final text = _contentController.text;
    final sel = _contentController.selection;
    final cursor = sel.isValid ? math.min(math.max(sel.baseOffset, 0), text.length) : text.length;
    final before = text.substring(0, cursor);

    final match = RegExp(r'([@#])([A-Za-z0-9_\.]{0,30})$').firstMatch(before);
    if (match == null) {
      _closeSuggestions();
      return;
    }

    final raw = match.group(0)!;
    final type = match.group(1) == '@' ? _TokenType.mention : _TokenType.hashtag;
    final query = match.group(2) ?? '';
    final start = cursor - raw.length;

    // Ne pas suggérer si on vient d'insérer (espace final)
    _token = _ActiveToken(type: type, query: query, start: start, end: cursor);
    _fetchSuggestionsDebounced();
  }

  void _closeSuggestions() {
    if (_showSuggestions || _loadingSuggestions) {
      _showSuggestions = false;
      _loadingSuggestions = false;
      _token = null;
    }
  }

  void _fetchSuggestionsDebounced() {
    _suggestDebounce?.cancel();
    final token = _token;
    if (token == null) return;

    setState(() => _loadingSuggestions = true);

    _suggestDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted || _token != token) return;
      try {
        if (token.type == _TokenType.mention) {
          final users = token.query.isEmpty
              ? <Map<String, dynamic>>[]
              : await ref.read(networkServiceProvider).searchUsers(token.query).timeout(_suggestTimeout);
          if (!mounted || _token != token) return;
          setState(() {
            _mentionSuggestions = users.take(6).toList();
            _hashtagSuggestions = [];
            _showSuggestions = _mentionSuggestions.isNotEmpty;
            _loadingSuggestions = false;
          });
        } else {
          final tags = await _searchHashtags(token.query);
          if (!mounted || _token != token) return;
          setState(() {
            _hashtagSuggestions = tags.take(6).toList();
            _mentionSuggestions = [];
            _showSuggestions = _hashtagSuggestions.isNotEmpty;
            _loadingSuggestions = false;
          });
        }
      } catch (e) {
        debugPrint('[Suggestions] Error: $e');
        if (mounted) setState(() => _loadingSuggestions = false);
      }
    });
  }

  /// Recherche de hashtags : table post_hashtags, fallback parsing des posts récents.
  Future<List<_HashtagSuggestion>> _searchHashtags(String q) async {
    final db = Supabase.instance.client;
    final results = <String, int>{};

    // 1) Table dédiée (si elle existe avec ces colonnes)
    try {
      final res = await db
          .from('post_hashtags')
          .select('*')
          .limit(200)
          .timeout(_suggestTimeout);
      for (final row in res as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final tag = (m['tag'] ?? m['hashtag'] ?? m['name'])?.toString().toLowerCase();
        if (tag == null) continue;
        if (q.isEmpty || tag.startsWith(q.toLowerCase())) {
          final count = (m['count'] ?? m['posts_count'] ?? m['usage_count'] as num?)?.toInt() ?? 1;
          results[tag] = (results[tag] ?? 0) + count;
        }
      }
      if (results.isNotEmpty) {
        final list = results.entries.map((e) => _HashtagSuggestion(e.key, e.value)).toList()
          ..sort((a, b) => b.count.compareTo(a.count));
        return list;
      }
    } catch (e) {
      debugPrint('[Hashtags] table error: $e');
    }

    // 2) Fallback : parser les posts récents
    try {
      final res = await db
          .from('posts')
          .select('content')
          .order('created_at', ascending: false)
          .limit(150)
          .timeout(_suggestTimeout);
      final pattern = RegExp(r'#([A-Za-z0-9_]{2,30})');
      for (final row in res as List) {
        final content = (row as Map)['content']?.toString() ?? '';
        for (final m in pattern.allMatches(content)) {
          final tag = m.group(1)!.toLowerCase();
          if (q.isEmpty || tag.startsWith(q.toLowerCase())) {
            results[tag] = (results[tag] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint('[Hashtags] fallback error: $e');
    }

    final list = results.entries.map((e) => _HashtagSuggestion(e.key, e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  void _applyMention(Map<String, dynamic> user) {
    final token = _token;
    if (token == null) return;
    final name = user['display_name']?.toString() ?? user['full_name']?.toString() ?? '';
    if (name.isEmpty) return;

    final id = user['id']?.toString();
    if (id != null) _mentionedIds.add(id);

    final replacement = '@$name ';
    _replaceToken(replacement);
    HapticFeedback.selectionClick();
  }

  void _applyHashtag(_HashtagSuggestion tag) {
    final replacement = '#${tag.tag} ';
    _replaceToken(replacement);
    HapticFeedback.selectionClick();
  }

  void _replaceToken(String replacement) {
    final token = _token;
    if (token == null) return;
    final text = _contentController.text;
    final newText = text.replaceRange(token.start, token.end, replacement);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: token.start + replacement.length),
    );
    setState(() {
      _showSuggestions = false;
      _token = null;
      _mentionSuggestions = [];
      _hashtagSuggestions = [];
    });
    _contentFocusNode.requestFocus();
  }

  // ════════════════════════════════════════════════════════════════════════
  // TIER GATES & DIALOGS
  // ════════════════════════════════════════════════════════════════════════
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

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          title: Text('Permission requise', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          content: Text('Vous avez précédemment refusé cette permission. Veuillez l\'activer dans les paramètres de l\'application.', style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ouvrir les paramètres')),
          ],
        ),
      );
      if (openSettings == true) await openAppSettings();
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
        content: Text(explanation, style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Annuler", style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
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

  // ════════════════════════════════════════════════════════════════════════
  // FORMATAGE
  // ════════════════════════════════════════════════════════════════════════
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

  // ════════════════════════════════════════════════════════════════════════
  // AUDIO
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _startRecording() async {
    if (_isUploading || _isRecording) return;
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
      String recordPath = kIsWeb
          ? 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : p.join((await getTemporaryDirectory()).path, 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
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
        if (!_PostValidators.validateFileSize(bytes.length, maxSizeMB: _maxAudioSizeMB)) {
          if (mounted) setState(() => _errorMessage = 'Audio trop volumineux (max ${_maxAudioSizeMB}MB)');
          return;
        }
        if (mounted) {
          setState(() {
            _audioBytes = bytes;
            _localAudioPath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('[Record] Stop error: $e');
      if (mounted) setState(() => _errorMessage = 'Erreur lors de l\'enregistrement.');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // MÉDIAS
  // ════════════════════════════════════════════════════════════════════════
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
          if (!_PostValidators.validateFileSize(f.bytes!.length, maxSizeMB: _maxImageSizeMB)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name}: trop volumineux (max ${_maxImageSizeMB}MB)'), backgroundColor: ThixPolicy.danger));
            continue;
          }
          if (!_PostValidators.validateFileExtension(f.name, _allowedImageExts)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name}: format non supporté'), backgroundColor: ThixPolicy.danger));
            continue;
          }
          final mimeError = _PostValidators.validateMime(f.bytes!);
          if (mimeError != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name}: $mimeError'), backgroundColor: ThixPolicy.danger));
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
          if (!_PostValidators.validateFileSize(f.bytes!.length, maxSizeMB: _maxVideoSizeMB)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name}: trop volumineux (max ${_maxVideoSizeMB}MB)'), backgroundColor: ThixPolicy.danger));
            continue;
          }
          if (!_PostValidators.validateFileExtension(f.name, _allowedVideoExts)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name}: format vidéo non supporté'), backgroundColor: ThixPolicy.danger));
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
        if (!_PostValidators.validateFileSize(bytes.length, maxSizeMB: _maxImageSizeMB)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo trop volumineuse (max ${_maxImageSizeMB}MB)'), backgroundColor: ThixPolicy.danger));
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

  // ════════════════════════════════════════════════════════════════════════
  // PUBLICATION
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _publishPost() async {
    if (_isUploading || _isRecording) return;

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
      if (_audioBytes != null) {
        try {
          final url = await ns.uploadAudioBytes(_audioBytes!).timeout(_uploadTimeout);
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        } catch (e) {
          debugPrint('[Upload] Audio error: $e');
          throw Exception('Échec upload audio: $e');
        }
      }

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

      String authorName = _authorName;
      String? authorAvatar = _authorAvatar;
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

      final sanitizedContent = _PostValidators.sanitizeText(textContent, maxLength: _maxTextLength);
      final sanitizedChallengeDesc = _PostValidators.sanitizeText(_challengeDescController.text, maxLength: 2000);
      final sanitizedReward = _PostValidators.sanitizeText(_challengeRewardController.text, maxLength: 500);
      final hashtags = _PostValidators.extractHashtags(sanitizedContent);

      final payload = <String, dynamic>{
        'user_id': user.id,
        'content': sanitizedContent,
        'is_public': _isPublic,
        'image_urls': uploadedUrls.where((u) => u.contains('post_images')).toList(),
        'video_urls': uploadedUrls.where((u) => u.contains('videos')).toList(),
        'media_urls': uploadedUrls,
        'media_url': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
        'community_id': widget.communityId,
        'post_type': 'standard',
        if (hashtags.isNotEmpty) 'hashtags': hashtags,
        if (_mentionedIds.isNotEmpty) 'mentioned_user_ids': _mentionedIds.toList(),
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
          'allow_multiple': _pollMultiple,
        };
      } else if (_postTypeMode == 2) {
        final maxP = int.tryParse(_challengeMaxController.text.trim());
        payload['post_type'] = 'challenge';
        payload['challenge_data'] = {
          'description': sanitizedChallengeDesc,
          'reward': sanitizedReward,
          'end_date': _challengeEndDate?.toIso8601String(),
          'participants_count': 0,
          'participants': [],
          if (maxP != null && maxP > 0) 'max_participants': maxP,
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
        isPublic: _isPublic,
      );

      try {
        ref.read(feedProvider.notifier).addPostOnTop(newPost);
      } catch (e) {
        debugPrint('[Feed] Add post error: $e');
        ref.invalidate(feedProvider);
      }
      widget.onPostCreated?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication réussie'), backgroundColor: ThixPolicy.success));
      Navigator.pop(context, newPost);
    } catch (e) {
      debugPrint('[Publish] Error: $e');

      if (uploadedUrls.isNotEmpty) {
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
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: ${e.toString().split('\n').first}';
          _isUploading = false;
        });
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // UI HELPERS
  // ════════════════════════════════════════════════════════════════════════
  Widget _segmentedType() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
      child: Row(
        children: [
          _segItem('Publication', 0, Icons.article_rounded),
          _segItem('Sondage', 1, Icons.poll_rounded),
          _segItem('Challenge', 2, Icons.emoji_events_rounded),
        ],
      ),
    );
  }

  Widget _segItem(String label, int mode, IconData icon) {
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? ThixPolicy.card : Colors.transparent,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            boxShadow: sel ? ThixPolicy.shadowSoft(opacity: 0.08) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: sel ? ThixPolicy.primary : ThixPolicy.textMuted),
              const SizedBox(width: 6),
              Text(label, style: ThixPolicy.labelStyle.copyWith(fontWeight: sel ? ThixPolicy.bold : ThixPolicy.medium, color: sel ? ThixPolicy.primary : ThixPolicy.textMuted)),
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
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rXs), border: Border.all(color: ThixPolicy.border)),
          child: child,
        ),
      ),
    );
  }

  Widget _mediaBtn(IconData icon, VoidCallback onTap, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: (_isUploading || _isRecording) ? null : onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.28), width: 1.3)),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }

  Widget _suggestionPanel() {
    if (!_showSuggestions || _token == null) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            if (_token!.type == _TokenType.mention)
              for (final u in _mentionSuggestions)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: ThixPolicy.surfaceSoft,
                    backgroundImage: (u['avatar_url']?.toString() ?? '').isNotEmpty ? NetworkImage(u['avatar_url'].toString()) : null,
                    child: (u['avatar_url']?.toString() ?? '').isEmpty ? const Icon(Icons.person, size: 16, color: ThixPolicy.textMuted) : null,
                  ),
                  title: Text(u['display_name']?.toString() ?? u['full_name']?.toString() ?? '', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                  subtitle: Text('@${u['username']?.toString() ?? u['thix_id']?.toString() ?? u['display_name']?.toString() ?? ''}', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                  onTap: () => _applyMention(u),
                ),
            if (_token!.type == _TokenType.hashtag)
              for (final h in _hashtagSuggestions)
                ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tag_rounded, size: 16, color: ThixPolicy.primary),
                  ),
                  title: Text('#${h.tag}', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                  subtitle: Text('${h.count} publication${h.count > 1 ? 's' : ''}', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                  onTap: () => _applyHashtag(h),
                ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final textLen = _contentController.text.length;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _postTypeMode == 1 ? 'Créer un sondage' : _postTypeMode == 2 ? 'Créer un challenge' : 'Créer une publication',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 17, color: ThixPolicy.textMain),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: (_isUploading || _isRecording) ? null : _publishPost,
              style: TextButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
              ),
              child: _isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publier', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: _isLoadingLimits
          ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── HEADER AUTEUR + VISIBILITÉ ──
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: ThixPolicy.surfaceSoft,
                                backgroundImage: (_authorAvatar ?? '').isNotEmpty ? CachedNetworkImageProvider(_authorAvatar!) : null,
                                child: (_authorAvatar ?? '').isEmpty ? const Icon(Icons.person, color: ThixPolicy.textMuted) : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_authorName, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                      child: Text(_userTier.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: ThixPolicy.gold, letterSpacing: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              // Sélecteur de visibilité
                              PopupMenuButton<bool>(
                                tooltip: 'Visibilité',
                                onSelected: (v) => setState(() => _isPublic = v),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: true, child: Row(children: [Icon(Icons.public_rounded, size: 18), SizedBox(width: 8), Text('Public')])),
                                  PopupMenuItem(value: false, child: Row(children: [Icon(Icons.group_rounded, size: 18), SizedBox(width: 8), Text('Contacts uniquement')])),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_isPublic ? Icons.public_rounded : Icons.group_rounded, size: 15, color: ThixPolicy.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(_isPublic ? 'Public' : 'Contacts', style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold)),
                                      const Icon(Icons.arrow_drop_down_rounded, size: 18, color: ThixPolicy.textMuted),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _segmentedType(),
                          const SizedBox(height: 14),

                          if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: ThixPolicy.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.danger.withOpacity(0.15))),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: ThixPolicy.danger),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_errorMessage!, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger))),
                                ],
                              ),
                            ),

                          // ── BARRE DE FORMATAGE ──
                          if (_postTypeMode != 2 && !_hasBgColor) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                              child: Row(
                                children: [
                                  _formatBtn(child: Text('B', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)), onTap: _applyBold, tooltip: 'Gras'),
                                  const SizedBox(width: 8),
                                  _formatBtn(child: Text('I', style: ThixPolicy.labelStyle.copyWith(fontStyle: FontStyle.italic, fontWeight: ThixPolicy.bold)), onTap: _applyItalic, tooltip: 'Italique'),
                                  Container(width: 1, height: 18, color: ThixPolicy.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
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
                            const SizedBox(height: 12),
                          ],

                          // ── CHAMP PRINCIPAL ──
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _canHaveBgColor && _hasBgColor ? _selectedBgColor : ThixPolicy.card,
                              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                              border: Border.all(color: _canHaveBgColor && _hasBgColor ? Colors.transparent : ThixPolicy.border),
                            ),
                            padding: _canHaveBgColor && _hasBgColor ? const EdgeInsets.symmetric(horizontal: 20, vertical: 40) : const EdgeInsets.all(15),
                            alignment: _canHaveBgColor && _hasBgColor ? Alignment.center : Alignment.topLeft,
                            child: TextField(
                              controller: _contentController,
                              focusNode: _contentFocusNode,
                              maxLength: _isFree ? 280 : null,
                              minLines: _postTypeMode == 2 ? 2 : (_canHaveBgColor && _hasBgColor ? null : 6),
                              maxLines: _canHaveBgColor && _hasBgColor ? null : 14,
                              textAlign: _canHaveBgColor && _hasBgColor ? TextAlign.center : TextAlign.start,
                              style: ThixPolicy.bodyStyle.copyWith(
                                color: _canHaveBgColor && _hasBgColor ? Colors.white : ThixPolicy.textMain,
                                fontSize: _canHaveBgColor && _hasBgColor ? 22 : 15,
                                fontWeight: _canHaveBgColor && _hasBgColor ? ThixPolicy.bold : ThixPolicy.regular,
                                height: 1.45,
                              ),
                              decoration: InputDecoration(
                                hintText: _postTypeMode == 1 ? 'Posez votre question...' : _postTypeMode == 2 ? 'Titre du challenge...' : 'Quoi de neuf ? Utilisez @ pour mentionner, # pour un hashtag...',
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
                          ),

                          // ── PANNEAU DE SUGGESTIONS @ / # ──
                          _suggestionPanel(),

                          // ── COMPTEUR ──
                          if (_isFree && _postTypeMode == 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '$textLen / 280',
                                  style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: textLen >= 280 ? ThixPolicy.danger : ThixPolicy.textSecondary),
                                ),
                              ),
                            ),

                          // ── ENREGISTREMENT AUDIO ──
                          if (_isRecording)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: ThixPolicy.danger.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.danger.withOpacity(0.2))),
                              child: Row(
                                children: [
                                  const Icon(Icons.mic, color: ThixPolicy.danger, size: 20),
                                  const SizedBox(width: 12),
                                  Text('Enregistrement... ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
                                  const Spacer(),
                                  GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: ThixPolicy.danger, size: 30)),
                                ],
                              ),
                            )
                          else if (_localAudioPath != null)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                              child: Row(
                                children: [
                                  Expanded(child: _InlineAudioPlayer(audioPath: _localAudioPath!)),
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

                          // ── FONDS COLORÉS ──
                          if (_canHaveBgColor)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(top: 12),
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
                            ),

                          // ── SONDAGE ──
                          if (_postTypeMode == 1) ...[
                            const SizedBox(height: 16),
                            Text('Options de réponse', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                            const SizedBox(height: 8),
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
                                          fillColor: ThixPolicy.card,
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
                                      ),
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
                            const SizedBox(height: 10),
                            // Choix multiple
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Autoriser plusieurs choix', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                value: _pollMultiple,
                                activeColor: ThixPolicy.primary,
                                onChanged: (v) => setState(() => _pollMultiple = v),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('Durée du sondage', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                for (final d in const [1, 3, 7]) ...[
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () => setState(() => _pollDurationDays = d),
                                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _pollDurationDays == d ? ThixPolicy.primary : ThixPolicy.card,
                                            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                            border: Border.all(color: _pollDurationDays == d ? ThixPolicy.primary : ThixPolicy.border),
                                          ),
                                          child: Text(
                                            d == 7 ? '1 semaine' : '$d jour${d > 1 ? 's' : ''}',
                                            textAlign: TextAlign.center,
                                            style: ThixPolicy.labelStyle.copyWith(color: _pollDurationDays == d ? Colors.white : ThixPolicy.textMain, fontWeight: ThixPolicy.semiBold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],

                          // ── CHALLENGE ──
                          if (_postTypeMode == 2) ...[
                            const SizedBox(height: 16),
                            Text('Description du challenge', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _challengeDescController,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 2000,
                              style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'Expliquez les règles et comment participer...',
                                filled: true,
                                fillColor: ThixPolicy.card,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.all(14),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _challengeRewardController,
                              maxLength: 500,
                              style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'Récompense (optionnel)',
                                filled: true,
                                fillColor: ThixPolicy.card,
                                prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18, color: ThixPolicy.gold),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _challengeMaxController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              maxLength: 6,
                              style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'Participants max (optionnel)',
                                filled: true,
                                fillColor: ThixPolicy.card,
                                prefixIcon: const Icon(Icons.groups_rounded, size: 18, color: ThixPolicy.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              style: TextButton.styleFrom(backgroundColor: ThixPolicy.card, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _challengeEndDate ?? DateTime.now().add(const Duration(days: 7)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(_challengeEndDate ?? DateTime.now().add(const Duration(days: 7, hours: 12))),
                                  );
                                  setState(() {
                                    _challengeEndDate = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 23, time?.minute ?? 59);
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today_rounded, size: 15, color: ThixPolicy.primary),
                              label: Text(
                                _challengeEndDate == null
                                    ? 'Choisir la date et l\'heure de fin'
                                    : 'Fin: ${_challengeEndDate!.day}/${_challengeEndDate!.month}/${_challengeEndDate!.year} à ${_challengeEndDate!.hour.toString().padLeft(2, '0')}:${_challengeEndDate!.minute.toString().padLeft(2, '0')}',
                                style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
                              ),
                            ),
                          ],

                          // ── MÉDIAS AJOUTÉS ──
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
                                        ClipRRect(borderRadius: BorderRadius.circular(ThixPolicy.rSm), child: Image.memory(_images[i].bytes, width: 92, height: 92, fit: BoxFit.cover)),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeMedia(i, false),
                                            child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)),
                                          ),
                                        ),
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
                                        Container(width: 92, height: 92, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(ThixPolicy.rSm)), child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30))),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeMedia(i, true),
                                            child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── BARRE BASSE : MÉDIAS + PUBLIER ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border.withOpacity(0.6)))),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _mediaBtn(Icons.photo_rounded, _pickImages, ThixPolicy.success, 'Photos'),
                              _mediaBtn(Icons.videocam_rounded, _pickVideos, ThixPolicy.danger, 'Vidéos'),
                              _mediaBtn(Icons.photo_camera_rounded, _pickCamera, ThixPolicy.primary, 'Caméra'),
                              _mediaBtn(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded, _isRecording ? _stopRecording : _startRecording, ThixPolicy.gold, 'Audio'),
                              const Spacer(),
                              Text('$textLen/${_isFree ? 280 : _maxTextLength}', style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: textLen >= (_isFree ? 280 : _maxTextLength) ? ThixPolicy.danger : ThixPolicy.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_isUploading || _isRecording) ? null : _publishPost,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThixPolicy.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: ThixPolicy.surfaceStrong,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
                                elevation: 0,
                              ),
                              child: _isUploading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text('Publier', style: ThixPolicy.buttonText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// LECTEUR AUDIO INLINE
// ============================================================================
class _InlineAudioPlayer extends StatefulWidget {
  final String audioPath;
  const _InlineAudioPlayer({required this.audioPath});
  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
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
              onChanged: (val) => _player.seek(Duration(milliseconds: val.toInt())),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
      ],
    );
  }
}
