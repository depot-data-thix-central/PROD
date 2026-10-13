// lib/presentation/network/widgets/post_card.dart
//
// PostCard — Production Enterprise (THIX PRO / THIX ID) — v5 FINAL
//
// ✅ v5 : Badges premium (10), paragraphes espacés, traductions intégrées
// ✅ v4 : Téléchargement in-app, lien thix.id, PostShareSheet
// ✅ v3 : Texte sélectionnable, #tags/@mentions, menu ⋯, vidéo sans écran noir,
//         galerie zoom, stats, pin, sondage, challenge, audio, signalement
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/presentation/network/widgets/post_share_sheet.dart';
import 'package:thix_id/services/media_saver.dart';

// ============================================================================
// PALETTE MONOCHROME
// ============================================================================
class _Mono {
  _Mono._();
  static const Color accent = Color(0xFF3F3F46);
  static const Color accentDeep = Color(0xFF18181B);
  static const Color accentSoft = Color(0xFF71717A);
}

// ============================================================================
// CONSTANTES
// ============================================================================
class _PostCardConfig {
  _PostCardConfig._();
  static const Duration networkTimeout = Duration(seconds: 10);
  static const Duration linkPreviewTimeout = Duration(seconds: 8);
  static const Duration videoThumbTimeout = Duration(seconds: 5);
  static const Duration impressionDebounce = Duration(milliseconds: 500);
  static const Duration contentDebounce = Duration(milliseconds: 100);
  static const Duration followThrottle = Duration(milliseconds: 800);
  static const Duration voteThrottle = Duration(milliseconds: 800);
  static const Duration reportThrottle = Duration(milliseconds: 1500);
  static const Duration repostThrottle = Duration(milliseconds: 1500);
  static const Duration likeVerifyTimeout = Duration(seconds: 6);
  static const int maxContentChars = 250;
  static const int maxContentLines = 7;
  static const int maxParseDepth = 6;
  static const int maxSanitizedLength = 5000;
  static const int maxReportDetailsLength = 500;
  static const int maxRepostQuoteLength = 500;
  static const int cacheMaxSize = 50;
  static const Duration cacheTtl = Duration(minutes: 5);
  static const double postBlurSigma = kIsWeb ? 8 : 16;
  static const double dialogBlurSigma = 10;
  static const int maxLikersFetched = 5;
  static const int avatarFallbackSize = 256;
  static const double cardBottomBorderWidth = 1.2;
  static const double cardFirstTopBorderWidth = 2.0;
  static const int maxVideoFrameFallbacks = 3;
  static const String permalinkBase = 'https://thix.id/network/post/';
  static const Set<String> knownRedirectDomains = {
    'facebook.com', 'fb.me', 'l.facebook.com',
    'share.google', 'goo.gl', 'g.co',
  };
}

// ============================================================================
// LOGGING
// ============================================================================
class _PostCardLogger {
  static const _tag = 'PostCard';
  static void info(String message, [Map<String, Object?>? data]) => _log('INFO', message, data);
  static void warn(String message, [Map<String, Object?>? data]) => _log('WARN', message, data);
  static void error(String message, [Map<String, Object?>? data]) => _log('ERROR', message, data);
  static void _log(String level, String message, Map<String, Object?>? data) {
    if (!kDebugMode && level == 'INFO') return;
    final suffix = data != null ? ' ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag][$level] $message$suffix');
  }
}

// ============================================================================
// VALIDATEURS / SÉCURITÉ
// ============================================================================
class _PostCardValidators {
  _PostCardValidators._();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _privateHostRegex = RegExp(
    r'^(localhost|127\.|0\.|10\.|192\.168\.|169\.254\.|::1$|fc00:|fd00:)',
    caseSensitive: false,
  );

  /// ✅ CORRECTIF : conserve \n (0x0A) et \t (0x09)
  static String sanitize(String? input, {int maxLength = _PostCardConfig.maxSanitizedLength, bool multiline = true}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = (doc.body?.text ?? input)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'(javascript|data|vbscript):', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    if (multiline) {
      s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    } else {
      s = s.replaceAll(RegExp(r'\s+'), ' ');
    }
    s = s.trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String sanitizeLine(String? input, {int maxLength = 200}) => sanitize(input, maxLength: maxLength, multiline: false);
  static bool isValidId(String? id) => id != null && _uuidRegex.hasMatch(id);

  static bool isValidUrl(String url) {
    if (url.length > 2048) return false;
    try {
      final uri = Uri.parse(url);
      return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty && !uri.host.contains('..');
    } catch (_) {
      return false;
    }
  }

  static bool isSafeExternalFetchUrl(String url) {
    if (!isValidUrl(url)) return false;
    final host = Uri.tryParse(url)?.host ?? '';
    return !_privateHostRegex.hasMatch(host);
  }

  static bool isValidRichTextUrl(String url) {
    if (!isValidUrl(url)) return false;
    if (url.toLowerCase().contains('javascript:')) return false;
    return true;
  }

  static bool isValidPollData(Map<String, dynamic>? pollData) {
    if (pollData == null) return false;
    final options = pollData['options'];
    if (options is! List || options.isEmpty) return false;
    return options.every((opt) => opt is Map && opt.containsKey('text') && opt.containsKey('votes'));
  }

  static bool isKnownRedirectDomain(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase().replaceFirst('www.', '') ?? '';
    return _PostCardConfig.knownRedirectDomains.any((d) => host == d || host.endsWith('.$d'));
  }
}

// ============================================================================
// HELPERS
// ============================================================================
final RegExp _kRichContentRegex = RegExp(
  r'\{c:(#[0-9A-Fa-f]{6,8})\}([\s\S]*?)\{c\}|'
  r'\*\*([\s\S]+?)\*\*|'
  r'\*([\s\S]+?)\*|'
  r'(?<![\w@])@([\p{L}\p{N}_]{1,32})|'
  r'(?<![\w#&])#([\p{L}\p{N}_]{1,64})|'
  r'((?:https?:\/\/|www\.)[^\s]+)',
  unicode: true,
);
final RegExp _kUrlFinder = RegExp(r'((?:https?:\/\/|www\.)[^\s]+)');
final RegExp _kUrlTrailingPunct = RegExp(r'[.,;:!?)\]]+$');

String _normalizeUrl(String url) => url.toLowerCase().startsWith('www.') ? 'https://$url' : url;

String _plainText(String content) {
  var s = content.replaceAll(RegExp(r'\{c:#[0-9A-Fa-f]{6,8}\}'), '').replaceAll('{c}', '');
  s = s.replaceAllMapped(RegExp(r'\*\*([\s\S]+?)\*\*'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'\*([\s\S]+?)\*'), (m) => m.group(1) ?? '');
  return s.trim();
}

String _formatCountHelper(int count) {
  if (count <= 0) return '';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

bool _isVideoUrl(String url) {
  try {
    final path = Uri.parse(url).path.toLowerCase();
    const exts = ['.mp4', '.mov', '.m4v', '.webm', '.avi', '.mkv'];
    return exts.any(path.endsWith) || path.contains('/videos/') || path.contains('/video/');
  } catch (_) {
    return false;
  }
}

String? _safeImageUrl(String? url) => (url != null && url.isNotEmpty && _PostCardValidators.isValidUrl(url)) ? url : null;
bool _isGhostRepostContent(NetworkPost post) => post.isRepostCard && post.content.trim().toLowerCase() == 'true';
String _postLink(String postId) => '${_PostCardConfig.permalinkBase}$postId';

String _fullDate(DateTime dt) {
  final d = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

String _trL(AppLocalizations l10n, String key, String fallback) {
  final v = l10n.t(key);
  return (v.isEmpty || v == key) ? fallback : v;
}

void _toast(BuildContext context, String message, {Color? bg, int seconds = 2}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: bg, behavior: SnackBarBehavior.floating, duration: Duration(seconds: seconds)));
}

Future<void> _downloadMedia(BuildContext context, String url) async {
  if (!_PostCardValidators.isValidUrl(url)) return;
  HapticFeedback.selectionClick();
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final isVideo = _isVideoUrl(url);
  if (kIsWeb) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }
  final progress = ValueNotifier<double>(0);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(minutes: 2),
      behavior: SnackBarBehavior.floating,
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, __) => Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, value: v > 0 ? v : null, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text('${_trL(l10n, 'post_downloading', 'Téléchargement…')}${v > 0 ? ' ${(v * 100).round()}%' : ''}')),
        ]),
      ),
    ));
  final result = await MediaSaver.save(url, isVideo: isVideo, onProgress: (v) => progress.value = v);
  messenger.hideCurrentSnackBar();
  progress.dispose();
  final ok = result == MediaSaveResult.saved;
  final msg = switch (result) {
    MediaSaveResult.saved => _trL(l10n, 'post_download_saved', 'Enregistré dans votre galerie'),
    MediaSaveResult.denied => _trL(l10n, 'post_download_denied', "Autorisez l'accès aux photos dans les réglages"),
    _ => _trL(l10n, 'post_download_failed', 'Impossible de télécharger'),
  };
  messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? ThixPolicy.success : ThixPolicy.danger, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}

Future<void> _copyToClipboard(BuildContext context, String text, String message) async {
  HapticFeedback.selectionClick();
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _toast(context, message, seconds: 1);
}

// ============================================================================
// CACHE LRU & OPTIMISTE
// ============================================================================
class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  _CacheEntry(this.value) : timestamp = DateTime.now();
}

class _PostCardCache {
  _PostCardCache._();
  static final _PostCardCache instance = _PostCardCache._();
  final LinkedHashMap<String, _CacheEntry<List<String>>> _likers = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<Map<String, dynamic>>> _linkPreviews = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<String>> _videoThumbs = LinkedHashMap();
  final Map<String, bool> optimisticLikes = {};
  final Map<String, int> optimisticLikeCounts = {};
  final Map<String, bool> optimisticSaves = {};
  final Map<String, bool> optimisticReposts = {};
  final Map<String, int> optimisticRepostCounts = {};

  List<String>? getLikers(String postId) => _get(_likers, postId);
  void setLikers(String postId, List<String> avatars) => _set(_likers, postId, avatars);
  Map<String, dynamic>? getLinkPreview(String url) => _get(_linkPreviews, url);
  void setLinkPreview(String url, Map<String, dynamic> data) => _set(_linkPreviews, url, data);
  String? getVideoThumb(String url) => _get(_videoThumbs, url);
  void setVideoThumb(String url, String thumb) => _set(_videoThumbs, url, thumb);

  T? _get<T>(LinkedHashMap<String, _CacheEntry<T>> map, String key) {
    final entry = map[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _PostCardConfig.cacheTtl) { map.remove(key); return null; }
    map.remove(key);
    map[key] = entry;
    return entry.value;
  }

  void _set<T>(LinkedHashMap<String, _CacheEntry<T>> map, String key, T value) {
    if (map.length >= _PostCardConfig.cacheMaxSize) map.remove(map.keys.first);
    map[key] = _CacheEntry(value);
  }
}

// ============================================================================
// POST ORIGINAL D'UN REPOST
// ============================================================================
final _originalPostProvider = FutureProvider.autoDispose.family<NetworkPost?, String>((ref, postId) async {
  ref.keepAlive();
  try {
    return await ref.read(networkServiceProvider).getPostById(postId).timeout(_PostCardConfig.networkTimeout);
  } catch (e) {
    _PostCardLogger.warn('original post load failed', {'postId': postId, 'error': '$e'});
    return null;
  }
});

// ============================================================================
// STATE NOTIFIER
// ============================================================================
final postItemProvider = StateNotifierProvider.autoDispose<PostItemNotifier, NetworkPost>(
  (ref) => throw UnimplementedError('postItemProvider doit être surchargé par PostCard'),
);

class PostItemNotifier extends StateNotifier<NetworkPost> {
  PostItemNotifier(NetworkPost post, this.ref) : super(post) {
    bool changed = false;
    bool newIsLiked = state.isLiked;
    int newLikesCount = state.likesCount;
    bool newIsSaved = state.isSaved;
    bool newIsReposted = state.isReposted;
    int newRepostsCount = state.repostsCount;
    if (_PostCardCache.instance.optimisticLikes.containsKey(post.id)) {
      newIsLiked = _PostCardCache.instance.optimisticLikes[post.id]!;
      newLikesCount = _PostCardCache.instance.optimisticLikeCounts[post.id] ?? state.likesCount;
      changed = true;
    }
    if (_PostCardCache.instance.optimisticSaves.containsKey(post.id)) { newIsSaved = _PostCardCache.instance.optimisticSaves[post.id]!; changed = true; }
    if (_PostCardCache.instance.optimisticReposts.containsKey(post.id)) {
      newIsReposted = _PostCardCache.instance.optimisticReposts[post.id]!;
      newRepostsCount = _PostCardCache.instance.optimisticRepostCounts[post.id] ?? state.repostsCount;
      changed = true;
    }
    if (changed) state = state.copyWith(isLiked: newIsLiked, likesCount: newLikesCount, isSaved: newIsSaved, isReposted: newIsReposted, repostsCount: newRepostsCount);
    if (!_PostCardCache.instance.optimisticLikes.containsKey(post.id) && _isAuthenticated) _verifyLikeStatusFromServer(post.id);
  }

  final Ref ref;
  bool _likeBusy = false;
  bool _isDisposed = false;
  @override void dispose() { _isDisposed = true; super.dispose(); }
  bool get _isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  Future<void> _verifyLikeStatusFromServer(String postId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client.from('post_likes').select('post_id').eq('post_id', postId).eq('user_id', uid).maybeSingle().timeout(_PostCardConfig.likeVerifyTimeout);
      final reallyLiked = res != null;
      if (_isDisposed) return;
      if (reallyLiked != state.isLiked) state = state.copyWith(isLiked: reallyLiked);
      _PostCardCache.instance.optimisticLikes[postId] = reallyLiked;
      _PostCardCache.instance.optimisticLikeCounts[postId] = state.likesCount;
    } catch (e) { _PostCardLogger.warn('verifyLikeStatus failed', {'postId': postId, 'error': '$e'}); }
  }

  Future<void> toggleLike() async {
    if (_likeBusy || !_isAuthenticated || _isDisposed) return;
    _likeBusy = true;
    final wasLiked = state.isLiked;
    final oldCount = state.likesCount;
    final newLiked = !wasLiked;
    final newCount = wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1;
    state = state.copyWith(isLiked: newLiked, likesCount: newCount);
    _PostCardCache.instance.optimisticLikes[state.id] = newLiked;
    _PostCardCache.instance.optimisticLikeCounts[state.id] = newCount;
    try {
      final service = ref.read(networkServiceProvider);
      try {
        final result = await service.togglePostLike(state.id).timeout(_PostCardConfig.networkTimeout);
        if (_isDisposed) return;
        state = state.copyWith(isLiked: result.liked, likesCount: result.likesCount);
        _PostCardCache.instance.optimisticLikes[state.id] = result.liked;
        _PostCardCache.instance.optimisticLikeCounts[state.id] = result.likesCount;
      } catch (_) {
        if (_isDisposed) return;
        if (wasLiked) await service.unlikePost(state.id).timeout(_PostCardConfig.networkTimeout);
        else await service.likePost(state.id).timeout(_PostCardConfig.networkTimeout);
      }
    } catch (e) {
      _PostCardLogger.error('toggleLike failed', {'postId': state.id});
      if (!_isDisposed) {
        state = state.copyWith(isLiked: wasLiked, likesCount: oldCount);
        _PostCardCache.instance.optimisticLikes[state.id] = wasLiked;
        _PostCardCache.instance.optimisticLikeCounts[state.id] = oldCount;
      }
    } finally { if (!_isDisposed) _likeBusy = false; }
  }

  Future<void> toggleSave() async {
    if (!_isAuthenticated || _isDisposed) return;
    final was = state.isSaved;
    state = state.copyWith(isSaved: !was);
    _PostCardCache.instance.optimisticSaves[state.id] = !was;
    try {
      final service = ref.read(networkServiceProvider);
      if (was) await service.unsavePost(state.id).timeout(_PostCardConfig.networkTimeout);
      else await service.savePost(state.id).timeout(_PostCardConfig.networkTimeout);
    } catch (e) {
      _PostCardLogger.error('toggleSave failed', {'postId': state.id});
      if (!_isDisposed) { state = state.copyWith(isSaved: was); _PostCardCache.instance.optimisticSaves[state.id] = was; }
    }
  }

  void updateContent(String content) { if (!_isDisposed) state = state.copyWith(content: _PostCardValidators.sanitize(content)); }
  void incrementRepost() {
    if (!_isDisposed) {
      final c = state.repostsCount + 1;
      state = state.copyWith(repostsCount: c, isReposted: true);
      _PostCardCache.instance.optimisticReposts[state.id] = true;
      _PostCardCache.instance.optimisticRepostCounts[state.id] = c;
    }
  }
}

// ============================================================================
// 🏷️ BADGES PREMIUM (10) — chip encadré + pulse URGENT/ALERTE
// ============================================================================
class _BadgeStyle {
  final Color color;
  final IconData icon;
  final bool pulse;
  const _BadgeStyle(this.color, this.icon, {this.pulse = false});
}

class _StaticBadgeChip extends StatelessWidget {
  final _BadgeStyle style;
  final String label;
  const _StaticBadgeChip({required this.style, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: style.color, borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.6),
        boxShadow: [BoxShadow(color: style.color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(style.icon, size: 15, color: Colors.white),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.9, height: 1)),
      ]),
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  final _BadgeStyle style;
  final String label;
  const _PulsingBadge({required this.style, required this.label});
  @override State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    _scale = Tween<double>(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeInOut)).animate(_ctrl);
    _glow = Tween<double>(begin: 0.25, end: 0.65).chain(CurveTween(curve: Curves.easeInOut)).animate(_ctrl);
    _ctrl.repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _ctrl, builder: (context, _) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: widget.style.color, borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.8),
          boxShadow: [BoxShadow(color: widget.style.color.withValues(alpha: _glow.value), blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 2))],
        ),
        child: Transform.scale(scale: _scale.value, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.style.icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.9, height: 1)),
        ])),
      );
    });
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class PostCard extends ConsumerStatefulWidget {
  final NetworkPost post;
  final String currentProfileId;
  final VoidCallback? onLike, onComment, onTap, onShare, onRefresh, onPin, onEdit, onDelete, onSave, onFollow;
  final bool isFollowingAuthor;
  final bool isFirst;
  const PostCard({super.key, required this.post, required this.currentProfileId, this.onLike, this.onComment, this.onTap, this.onShare, this.onRefresh, this.onPin, this.onEdit, this.onDelete, this.onSave, this.isFollowingAuthor = false, this.onFollow, this.isFirst = false});
  @override ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  bool _isReposting = false, _isExpanded = false, _pollVoteBusy = false, _isFollowingLocal = false, _followBusy = false;
  final _quoteController = TextEditingController();
  DateTime? _lastFollowTap, _lastVoteTap, _lastReportSubmit, _lastRepostSubmit, _lastContentUpdate;
  bool _impressionRegistered = false;
  Timer? _impressionDebounce;
  List<InlineSpan>? _cachedFullSpans, _cachedTruncatedSpans;
  List<List<InlineSpan>>? _cachedParagraphSpans;
  bool _isMultiParagraph = false, _isTruncatable = false, _parsedOnce = false;
  Locale? _parsedLocale;
  final List<GestureRecognizer> _recognizers = [];

  // ── 🏷️ PALETTE DES 10 BADGES PREMIUM ──
  static const Map<String, _BadgeStyle> _badgeStyles = {
    'urgent': _BadgeStyle(Color(0xFFE53935), Icons.priority_high_rounded, pulse: true),
    'alert': _BadgeStyle(Color(0xFFD84315), Icons.warning_amber_rounded, pulse: true),
    'flash': _BadgeStyle(Color(0xFFF57C00), Icons.bolt_rounded),
    'important': _BadgeStyle(Color(0xFFF9A825), Icons.error_outline_rounded),
    'info': _BadgeStyle(Color(0xFF1E88E5), Icons.info_outline_rounded),
    'new': _BadgeStyle(Color(0xFF43A047), Icons.fiber_new_rounded),
    'official': _BadgeStyle(ThixPolicy.gold, Icons.verified_rounded),
    'event': _BadgeStyle(Color(0xFF8E24AA), Icons.celebration_rounded),
    'promo': _BadgeStyle(Color(0xFF00897B), Icons.local_offer_rounded),
    'reminder': _BadgeStyle(Color(0xFF3949AB), Icons.alarm_rounded),
  };

  bool get _isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  @override void initState() { super.initState(); _isFollowingLocal = widget.isFollowingAuthor; }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (!_parsedOnce || _parsedLocale != locale) { _parsedOnce = true; _parsedLocale = locale; _cacheParsedContent(); }
  }
  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowingAuthor != widget.isFollowingAuthor) _isFollowingLocal = widget.isFollowingAuthor;
    if (oldWidget.post.content != widget.post.content) {
      final now = DateTime.now();
      if (_lastContentUpdate == null || now.difference(_lastContentUpdate!) > _PostCardConfig.contentDebounce) { _lastContentUpdate = now; _cacheParsedContent(); }
    }
  }
  @override void dispose() { _disposeRecognizers(); _quoteController.dispose(); _impressionDebounce?.cancel(); super.dispose(); }

  void _disposeRecognizers() { for (final r in _recognizers) { try { r.dispose(); } catch (_) {} } _recognizers.clear(); }
  bool _throttle(DateTime? Function() get, void Function(DateTime) set, Duration w) { final n = DateTime.now(), l = get(); if (l != null && n.difference(l) < w) return false; set(n); return true; }
  bool _throttleFollow() => _throttle(() => _lastFollowTap, (t) => _lastFollowTap = t, _PostCardConfig.followThrottle);
  bool _throttleVote() => _throttle(() => _lastVoteTap, (t) => _lastVoteTap = t, _PostCardConfig.voteThrottle);
  bool _throttleReport() => _throttle(() => _lastReportSubmit, (t) => _lastReportSubmit = t, _PostCardConfig.reportThrottle);
  bool _throttleRepost() => _throttle(() => _lastRepostSubmit, (t) => _lastRepostSubmit = t, _PostCardConfig.repostThrottle);

  String _truncate(String content) {
    var t = content;
    final lines = t.split('\n');
    if (lines.length > _PostCardConfig.maxContentLines) t = lines.take(_PostCardConfig.maxContentLines).join('\n');
    if (t.length > _PostCardConfig.maxContentChars) { t = t.substring(0, _PostCardConfig.maxContentChars); final ls = t.lastIndexOf(RegExp(r'\s')); if (ls > 0) t = t.substring(0, ls); }
    return t.trimRight();
  }

  List<String> _splitParagraphs(String content) => content.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  void _cacheParsedContent() {
    final content = _PostCardValidators.sanitize(widget.post.content);
    final l10n = AppLocalizations.of(context);
    final baseStyle = ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontSize: 14.5, height: 1.5);
    _disposeRecognizers();
    _cachedFullSpans = _parseContent(content, baseStyle, 0, l10n);
    final paras = _splitParagraphs(content);
    _isMultiParagraph = paras.length > 1;
    _cachedParagraphSpans = _isMultiParagraph ? paras.map((p) => _parseContent(p, baseStyle, 0, l10n)).toList() : null;
    final truncated = _truncate(content);
    _isTruncatable = truncated.length < content.length;
    _cachedTruncatedSpans = _isTruncatable ? _parseContent('$truncated…', baseStyle, 0, l10n) : _cachedFullSpans;
  }

  List<InlineSpan> _parseContent(String content, TextStyle baseStyle, int depth, AppLocalizations l10n) {
    if (depth > _PostCardConfig.maxParseDepth || content.isEmpty) return [TextSpan(text: content, style: baseStyle)];
    final spans = <InlineSpan>[];
    var lastIndex = 0;
    for (final match in _kRichContentRegex.allMatches(content)) {
      if (match.start > lastIndex) spans.add(TextSpan(text: content.substring(lastIndex, match.start), style: baseStyle));
      if (match.group(1) != null) {
        final hex = match.group(1)!.replaceFirst('#', '');
        Color color; try { color = Color(int.parse(hex.length == 8 ? hex : 'FF$hex', radix: 16)); } catch (_) { color = baseStyle.color ?? ThixPolicy.textMain; }
        spans.addAll(_parseContent(match.group(2) ?? '', baseStyle.copyWith(color: color), depth + 1, l10n));
      } else if (match.group(3) != null) { spans.addAll(_parseContent(match.group(3)!, baseStyle.copyWith(fontWeight: FontWeight.bold), depth + 1, l10n)); }
      else if (match.group(4) != null) { spans.addAll(_parseContent(match.group(4)!, baseStyle.copyWith(fontStyle: FontStyle.italic), depth + 1, l10n)); }
      else if (match.group(5) != null) {
        final u = match.group(5)!;
        final r = TapGestureRecognizer()..onTap = () { if (!mounted) return; HapticFeedback.selectionClick(); context.push('/network/profile/$u'); };
        _recognizers.add(r);
        spans.add(TextSpan(text: '@$u', style: baseStyle.copyWith(color: _Mono.accent, fontWeight: FontWeight.bold), recognizer: r, semanticsLabel: l10n.t('post_mention', args: [u])));
      } else if (match.group(6) != null) {
        final tag = match.group(6)!;
        final r = TapGestureRecognizer()..onTap = () { if (!mounted) return; HapticFeedback.selectionClick(); context.push('/hashtag/$tag'); };
        _recognizers.add(r);
        spans.add(TextSpan(text: '#$tag', style: baseStyle.copyWith(color: _Mono.accent, fontWeight: FontWeight.bold), recognizer: r, semanticsLabel: l10n.t('post_hashtag', args: [tag])));
      } else if (match.group(7) != null) {
        var raw = match.group(7)!; var trailing = '';
        final punct = _kUrlTrailingPunct.firstMatch(raw); if (punct != null) { trailing = punct.group(0)!; raw = raw.substring(0, punct.start); }
        final url = _normalizeUrl(raw);
        if (_PostCardValidators.isValidRichTextUrl(url)) {
          final r = TapGestureRecognizer()..onTap = () async { if (!mounted) return; HapticFeedback.selectionClick(); final uri = Uri.parse(url); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); };
          _recognizers.add(r);
          spans.add(TextSpan(text: raw, style: baseStyle.copyWith(color: _Mono.accent, decoration: TextDecoration.underline), recognizer: r, semanticsLabel: l10n.t('post_link')));
        } else { spans.add(TextSpan(text: raw, style: baseStyle)); }
        if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing, style: baseStyle));
      }
      lastIndex = match.end;
    }
    if (lastIndex < content.length) spans.add(TextSpan(text: content.substring(lastIndex), style: baseStyle));
    return spans;
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    final hex = hexColor.replaceAll('#', '');
    if (hex.length != 6 && hex.length != 8) return null;
    try { return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16)); } catch (_) { return null; }
  }

  String? _extractFirstUrl(String content) {
    final match = _kUrlFinder.firstMatch(content);
    var url = match?.group(0); if (url == null) return null;
    url = url.replaceAll(_kUrlTrailingPunct, ''); url = _normalizeUrl(url);
    return _PostCardValidators.isValidUrl(url) ? url : null;
  }

  String _shareExcerpt(NetworkPost post) { final c = _PostCardValidators.sanitizeLine(_plainText(post.content), maxLength: 140); return c.isEmpty ? 'Découvrez ce post sur THIX Hub' : c; }
  String? _shareImage(NetworkPost post) => post.imageUrls.isNotEmpty ? _safeImageUrl(post.imageUrls.first) : null;
  void _sharePost(NetworkPost post) => PostShareSheet.show(context, postId: post.id, postExcerpt: _shareExcerpt(post), imageUrl: _shareImage(post));

  Future<void> _togglePin(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated) return;
    HapticFeedback.selectionClick();
    final was = post.isPinned;
    try {
      final s = ref.read(networkServiceProvider);
      if (was) await s.unpinPost(post.id).timeout(_PostCardConfig.networkTimeout);
      else await s.pinPost(post.id).timeout(_PostCardConfig.networkTimeout);
      if (!mounted) return;
      _toast(context, was ? _trL(l10n, 'post_unpinned', 'Post désépinglé') : _trL(l10n, 'post_pinned_ok', 'Post épinglé sur votre profil'), bg: ThixPolicy.success);
      widget.onRefresh?.call();
    } catch (e) { _PostCardLogger.error('togglePin failed', {'postId': post.id}); if (mounted) _toast(context, 'Erreur : ${e.toString().split('\n').first}', bg: ThixPolicy.danger); }
  }

  // ── ¶ Contenu texte (paragraphes espacés) ──
  Widget _buildPostContent(NetworkPost post, AppLocalizations l10n) {
    if (post.content.isEmpty) return const SizedBox.shrink();
    final bgColor = _parseColor(post.bgColor);
    if (bgColor != null) {
      return Container(width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bgColor.withValues(alpha: 0.9), bgColor.withValues(alpha: 0.7)])),
        alignment: Alignment.center,
        child: SelectableText(_PostCardValidators.sanitize(post.content), textAlign: TextAlign.center,
          style: ThixPolicy.h2Style.copyWith(color: Colors.white, fontSize: 22, height: 1.3, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))])));
    }
    final firstUrl = _extractFirstUrl(post.content);
    final linkPreview = firstUrl != null ? Padding(padding: const EdgeInsets.only(top: 12), child: _PremiumLinkPreview(url: firstUrl, fallbackImage: post.imageUrls.isNotEmpty ? _safeImageUrl(post.imageUrls.first) : null)) : const SizedBox.shrink();

    if (_isMultiParagraph && _cachedParagraphSpans != null) {
      final spansList = _cachedParagraphSpans!;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (int i = 0; i < spansList.length; i++) ...[
          SelectableText.rich(TextSpan(children: spansList[i]), onTap: widget.onTap ?? () => _openPostDetails(post.id)),
          if (i < spansList.length - 1) const SizedBox(height: 12),
        ],
        linkPreview,
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(label: _plainText(post.content), child: SelectableText.rich(TextSpan(children: _isExpanded ? (_cachedFullSpans ?? []) : (_cachedTruncatedSpans ?? [])), onTap: widget.onTap ?? () => _openPostDetails(post.id))),
      if (_isTruncatable) Semantics(button: true, label: _isExpanded ? l10n.t('post_see_less') : l10n.t('post_see_more'),
        child: GestureDetector(onTap: () { HapticFeedback.selectionClick(); setState(() => _isExpanded = !_isExpanded); },
          child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(_isExpanded ? l10n.t('post_see_less') : l10n.t('post_see_more'), style: ThixPolicy.labelStyle.copyWith(color: _Mono.accent, fontSize: 13, fontWeight: FontWeight.bold))))),
      linkPreview,
    ]);
  }

  String _getTimeAgo(DateTime dt) => timeago.format(dt.toLocal(), locale: 'fr');
  void _openPostDetails(String postId) { if (!mounted || !_PostCardValidators.isValidId(postId)) return; HapticFeedback.mediumImpact(); context.push('/network/comments/$postId'); }
  void _openProfile(String userId) { if (!mounted || !_PostCardValidators.isValidId(userId)) return; HapticFeedback.selectionClick(); context.push('/network/profile/$userId'); }
  void _openGallery(int idx, List<String> urls) { if (!mounted || urls.isEmpty) return; HapticFeedback.mediumImpact(); Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenGallery(imageUrls: urls, initialIndex: idx.clamp(0, urls.length - 1)))); }
  void _openVideoFullScreen(String url) { if (!mounted || !_PostCardValidators.isValidUrl(url)) return; HapticFeedback.mediumImpact(); Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenVideoPlayer(videoUrl: url))); }

  // ── 🏷️ BADGE PREMIUM EN TÊTE ──
  Widget _buildPostBadge(NetworkPost post, AppLocalizations l10n) {
    if (!post.hasBadge) return const SizedBox.shrink();
    final style = _badgeStyles[post.postBadge]; if (style == null) return const SizedBox.shrink();
    final label = _trL(l10n, 'cp_badge_${post.postBadge}', post.postBadge!.toUpperCase());
    return Container(margin: const EdgeInsets.only(bottom: 10), child: style.pulse ? _PulsingBadge(style: style, label: label) : _StaticBadgeChip(style: style, label: label));
  }

  Widget _buildMediaGrid(List<String> rawUrls, AppLocalizations l10n) {
    final urls = rawUrls.where(_PostCardValidators.isValidUrl).toList(); if (urls.isEmpty) return const SizedBox.shrink();
    const spacing = 4.0; final radius = BorderRadius.circular(16);
    final imageOnlyUrls = urls.where((u) => !_isVideoUrl(u)).toList();
    Widget mediaTile(String url, {double? width, double? height, Alignment alignment = Alignment.center}) {
      if (_isVideoUrl(url)) return _VideoThumbTile(videoUrl: url, width: width, height: height, onTap: () => _openVideoFullScreen(url));
      return Stack(fit: StackFit.passthrough, children: [
        GestureDetector(onTap: () => _openGallery(imageOnlyUrls.indexOf(url), imageOnlyUrls),
          child: CachedNetworkImage(imageUrl: url, width: width, height: height, fit: BoxFit.cover, alignment: alignment, memCacheWidth: 600,
            placeholder: (_, __) => Container(color: Colors.white.withValues(alpha: 0.5), child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _Mono.accent)))),
            errorWidget: (_, __, ___) => Container(color: Colors.white.withValues(alpha: 0.5), child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted)))),
        Positioned(top: 6, right: 6, child: _MediaChipButton(icon: Icons.download_rounded, semanticsLabel: _trL(l10n, 'post_download_photo', 'Télécharger la photo'), onTap: () => _downloadMedia(context, url))),
      ]);
    }
    if (urls.length == 1) return ClipRRect(borderRadius: radius, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 500, minHeight: 200), child: SizedBox(width: double.infinity, child: mediaTile(urls[0], alignment: Alignment.topCenter))));
    Widget cell(int i, double h) => Expanded(child: ClipRRect(borderRadius: radius, child: mediaTile(urls[i], height: h, width: double.infinity)));
    if (urls.length == 2) return SizedBox(height: 220, child: Row(children: [cell(0, 220), const SizedBox(width: spacing), cell(1, 220)]));
    return SizedBox(height: 260, child: Row(children: [
      Expanded(flex: 3, child: ClipRRect(borderRadius: radius, child: mediaTile(urls[0], height: 260, width: double.infinity))),
      const SizedBox(width: spacing),
      Expanded(flex: 2, child: Column(children: [
        Expanded(child: ClipRRect(borderRadius: radius, child: mediaTile(urls[1], width: double.infinity, height: double.infinity))),
        const SizedBox(height: spacing),
        Expanded(child: ClipRRect(borderRadius: radius, child: Stack(fit: StackFit.expand, children: [
          mediaTile(urls[2], width: double.infinity, height: double.infinity),
          if (urls.length > 3) IgnorePointer(child: Container(color: Colors.black54, alignment: Alignment.center, child: Text('+${urls.length - 3}', style: ThixPolicy.h2Style.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))),
        ]))),
      ])),
    ]));
  }

  Widget _buildPollWidget(NetworkPost post, AppLocalizations l10n) {
    if (!_PostCardValidators.isValidPollData(post.pollData)) return const SizedBox.shrink();
    final options = (post.pollData!['options'] as List);
    var totalVotes = 0; for (final o in options) totalVotes += ((o['votes'] as List?)?.length ?? 0);
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [const Icon(Icons.poll_rounded, size: 18, color: _Mono.accent), const SizedBox(width: 8), Text(l10n.t('post_poll_title'), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: ThixPolicy.textMain)), const Spacer(), Text('$totalVotes ${_trL(l10n, 'post_poll_votes', 'vote(s)')}', style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 12),
        ...options.asMap().entries.map((e) {
          final i = e.key, opt = e.value;
          final text = _PostCardValidators.sanitizeLine('${opt['text'] ?? ''}');
          final voters = (opt['votes'] as List?) ?? [];
          final pct = totalVotes > 0 ? voters.length / totalVotes : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => _votePoll(post, i, l10n),
            child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white)),
              child: Stack(children: [
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct.clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_Mono.accent.withValues(alpha: 0.2), _Mono.accent.withValues(alpha: 0.1)]), borderRadius: BorderRadius.circular(12))))),
                Row(children: [Expanded(child: Text(text, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: ThixPolicy.textMain))), Text('${(pct * 100).toStringAsFixed(0)}%', style: ThixPolicy.labelStyle.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: _Mono.accent))]),
              ])))));
        }),
      ]));
  }

  Future<void> _votePoll(NetworkPost post, int index, AppLocalizations l10n) async {
    if (_pollVoteBusy || !_throttleVote() || !_isAuthenticated || !_PostCardValidators.isValidPollData(post.pollData)) return;
    final options = post.pollData!['options'] as List; if (index < 0 || index >= options.length) return;
    setState(() => _pollVoteBusy = true); HapticFeedback.selectionClick();
    try { await ref.read(networkServiceProvider).votePoll(post.id, index).timeout(_PostCardConfig.networkTimeout); }
    catch (e) { _PostCardLogger.error('votePoll failed', {'postId': post.id}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('post_vote_error')), backgroundColor: ThixPolicy.danger)); }
    finally { if (mounted) setState(() => _pollVoteBusy = false); }
  }

  Widget _buildChallengeWidget(NetworkPost post, AppLocalizations l10n) {
    final data = post.challengeData ?? <String, dynamic>{};
    final desc = _PostCardValidators.sanitize('${data['description'] ?? ''}');
    final pc = (data['participants_count'] is num) ? data['participants_count'] as num : 0;
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_Mono.accent.withValues(alpha: 0.1), _Mono.accent.withValues(alpha: 0.03)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _Mono.accent.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(gradient: LinearGradient(colors: [_Mono.accent, _Mono.accentDeep]), shape: BoxShape.circle), child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18)), const SizedBox(width: 10), Expanded(child: Text(l10n.t('post_challenge_title'), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 14, color: ThixPolicy.textMain))), Text(l10n.t('post_challenge_participants', args: ['$pc']), style: ThixPolicy.captionStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textMuted))]),
        if (desc.isNotEmpty) ...[const SizedBox(height: 12), Text(desc, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, height: 1.4, color: ThixPolicy.textMain))],
        const SizedBox(height: 14),
        SizedBox(height: 44, child: ElevatedButton.icon(onPressed: () { if (!_isAuthenticated) return; HapticFeedback.selectionClick(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('post_challenge_joined')), backgroundColor: ThixPolicy.success)); }, style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: _Mono.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), icon: const Icon(Icons.check_circle_outline_rounded, size: 18), label: Text(l10n.t('post_challenge_cta'), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)))),
      ]));
  }

  static const _reportReasonCodes = ['spam', 'nudity', 'violence', 'harassment', 'misinformation', 'impersonation', 'inappropriate', 'other'];

  Future<void> _showReportDialog(NetworkPost post, AppLocalizations l10n) async {
    if (!_isAuthenticated) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('report_error_auth')), backgroundColor: ThixPolicy.danger)); return; }
    String? selectedReasonCode; final dc = TextEditingController(); bool isSub = false;
    final confirmed = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => BackdropFilter(filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
      child: AlertDialog(backgroundColor: Colors.white.withValues(alpha: 0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const Icon(Icons.flag_outlined, color: ThixPolicy.danger, size: 22), const SizedBox(width: 8), Expanded(child: Text(l10n.t('report_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.bold)))]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.t('report_prompt'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16), Text(l10n.t('report_reason_label'), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, color: ThixPolicy.textMain, fontSize: 12)),
          const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.8))),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: selectedReasonCode, isExpanded: true, hint: Text(l10n.t('report_reason_hint'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13)), items: _reportReasonCodes.map((c) => DropdownMenuItem(value: c, child: Text(l10n.t('reason_$c'), style: ThixPolicy.bodyStyle.copyWith(fontSize: 13)))).toList(), onChanged: isSub ? null : (v) => ss(() => selectedReasonCode = v)))),
          const SizedBox(height: 16), Text(l10n.t('report_details_label'), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, color: ThixPolicy.textMain, fontSize: 12)),
          const SizedBox(height: 8), TextField(controller: dc, maxLines: 3, maxLength: _PostCardConfig.maxReportDetailsLength, enabled: !isSub, decoration: InputDecoration(hintText: l10n.t('report_details_hint'), hintStyle: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13), filled: true, fillColor: Colors.white.withValues(alpha: 0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _Mono.accent, width: 1.5)), counterText: '')),
        ])),
        actions: [TextButton(onPressed: isSub ? null : () => Navigator.pop(ctx, false), child: Text(l10n.t('report_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ElevatedButton(onPressed: (selectedReasonCode == null || isSub) ? null : () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, disabledBackgroundColor: ThixPolicy.danger.withValues(alpha: 0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: isSub ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l10n.t('report_submit')))],
      ))));
    if (confirmed != true || selectedReasonCode == null) { dc.dispose(); return; }
    if (!_throttleReport()) { dc.dispose(); return; }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) { dc.dispose(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('report_error_auth')), backgroundColor: ThixPolicy.danger)); return; }
    final details = _PostCardValidators.sanitize(dc.text.trim(), maxLength: _PostCardConfig.maxReportDetailsLength); dc.dispose();
    try {
      await Supabase.instance.client.from('post_reports').insert({'post_id': post.id, 'reporter_id': uid, 'reason_code': selectedReasonCode, 'details': details, 'status': 'pending', 'created_at': DateTime.now().toUtc().toIso8601String()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20), const SizedBox(width: 8), Expanded(child: Text(l10n.t('report_sent'), style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13)))]), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      _PostCardLogger.error('Report insert failed', {'postId': post.id});
      final dup = e.toString().contains('duplicate key') || e.toString().contains('unique constraint');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dup ? l10n.t('report_error_duplicate') : l10n.t('report_error_generic')), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _editPost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated || widget.currentProfileId != post.userId) return;
    final c = TextEditingController(text: post.content);
    final nc = await showDialog<String>(context: context, builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
      child: AlertDialog(backgroundColor: Colors.white.withValues(alpha: 0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
        title: Row(children: [const Icon(Icons.edit_rounded, color: ThixPolicy.textMain), const SizedBox(width: 8), Text(l10n.t('edit_title'), style: ThixPolicy.titleStyle.copyWith(fontSize: 16))]),
        content: TextField(controller: c, maxLines: 6, autofocus: true, maxLength: _PostCardConfig.maxSanitizedLength, keyboardType: TextInputType.multiline, decoration: InputDecoration(hintText: l10n.t('edit_hint'), filled: true, fillColor: Colors.white.withValues(alpha: 0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _Mono.accent, width: 1.5)))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.t('edit_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted))), ElevatedButton(onPressed: () { final t = _PostCardValidators.sanitize(c.text.trim()); if (t.isNotEmpty) Navigator.pop(ctx, t); }, style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.textMain, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l10n.t('edit_save')))])));
    c.dispose(); if (nc == null || nc.isEmpty || !mounted) return;
    try { if (widget.onEdit != null) widget.onEdit!(); else await ref.read(networkServiceProvider).updatePost(post.id, nc).timeout(_PostCardConfig.networkTimeout); if (mounted) { ref.read(postItemProvider.notifier).updateContent(nc); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('edit_success')))); } }
    catch (e) { _PostCardLogger.error('editPost failed', {'postId': post.id}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('edit_error')), backgroundColor: ThixPolicy.danger)); }
  }

  Future<void> _deletePost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated || widget.currentProfileId != post.userId) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
      child: AlertDialog(backgroundColor: Colors.white.withValues(alpha: 0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
        title: Row(children: [const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger), const SizedBox(width: 8), Text(l10n.t('delete_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger))]),
        content: Text(l10n.t('delete_confirm'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('delete_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l10n.t('delete_confirm_btn')))])));
    if (ok != true || !mounted) return;
    try { if (widget.onDelete != null) widget.onDelete!(); else await ref.read(networkServiceProvider).deletePost(post.id).timeout(_PostCardConfig.networkTimeout); }
    catch (e) { _PostCardLogger.error('deletePost failed', {'postId': post.id}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('delete_error')), backgroundColor: ThixPolicy.danger)); }
  }

  Future<void> _repost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (_isReposting || !_isAuthenticated) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
      child: AlertDialog(backgroundColor: Colors.white.withValues(alpha: 0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
        title: Text(l10n.t('repost_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain)),
        content: TextField(controller: _quoteController, maxLines: 3, maxLength: _PostCardConfig.maxRepostQuoteLength, decoration: InputDecoration(hintText: l10n.t('repost_hint'), filled: true, fillColor: Colors.white.withValues(alpha: 0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('repost_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _Mono.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l10n.t('repost_submit')))])));
    if (ok != true) { _quoteController.clear(); return; }
    if (!_throttleRepost()) return;
    setState(() => _isReposting = true);
    final q = _PostCardValidators.sanitize(_quoteController.text.trim(), maxLength: _PostCardConfig.maxRepostQuoteLength);
    try {
      final created = await ref.read(networkServiceProvider).repostPost(post.id, quote: q.isEmpty ? null : q).timeout(_PostCardConfig.networkTimeout);
      if (!mounted) return; ref.read(postItemProvider.notifier).incrementRepost(); if (created != null) ref.read(feedProvider.notifier).addPostOnTop(created);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('repost_success')), backgroundColor: ThixPolicy.success));
    } catch (e) { _PostCardLogger.error('repost failed', {'postId': post.id}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('repost_error')), backgroundColor: ThixPolicy.danger)); }
    finally { if (mounted) setState(() => _isReposting = false); _quoteController.clear(); }
  }

  Future<void> _hidePost(NetworkPost post, AppLocalizations l10n) async {
    if (!_isAuthenticated) return; HapticFeedback.selectionClick();
    try { await ref.read(networkServiceProvider).hidePost(post.id).timeout(_PostCardConfig.networkTimeout); if (mounted) { _toast(context, l10n.t('post_hidden')); widget.onRefresh?.call(); } }
    catch (e) { _PostCardLogger.error('hidePost failed', {'postId': post.id}); }
  }

  void _registerImpression(String postId) {
    if (_impressionRegistered || !_isAuthenticated) return;
    final uid = Supabase.instance.client.auth.currentUser?.id; if (uid == null) return;
    _impressionDebounce?.cancel();
    _impressionDebounce = Timer(_PostCardConfig.impressionDebounce, () {
      if (_impressionRegistered || !mounted) return; _impressionRegistered = true;
      Supabase.instance.client.rpc('increment_post_impression', params: {'p_post_id': postId, 'p_user_id': uid}).catchError((e) { _PostCardLogger.error('impression rpc failed', {'postId': postId}); _impressionRegistered = false; });
    });
  }

  int _impressionsOf(NetworkPost post) => post.views ?? 0;

  void _showStats(NetworkPost post, AppLocalizations l10n) {
    final rows = <MapEntry<String, int>>[
      MapEntry(_trL(l10n, 'post_stats_impressions', 'Impressions'), _impressionsOf(post)),
      MapEntry(_trL(l10n, 'post_stats_likes', "J'aime"), post.likesCount),
      MapEntry(_trL(l10n, 'post_stats_comments', 'Commentaires'), post.commentsCount),
      MapEntry(_trL(l10n, 'post_stats_reposts', 'Republications'), post.repostsCount),
    ];
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16), Text(_trL(l10n, 'post_stats_title', 'Statistiques du post'), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4), Text(_fullDate(post.createdAt), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
        const SizedBox(height: 14),
        for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text(r.key, style: ThixPolicy.bodyStyle)), Text('${r.value}', style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 15))])),
      ]))));
  }

  Future<void> _showPostMenu(NetworkPost post, bool isOwner, bool isCurrentUserFree, WidgetRef ref, AppLocalizations l10n) async {
    HapticFeedback.selectionClick();
    final text = _plainText(post.content);
    final images = post.imageUrls.where(_PostCardValidators.isValidUrl).toList();
    final videos = post.videoUrls.where(_PostCardValidators.isValidUrl).toList();
    final canCopyId = _PostCardValidators.isValidId(post.id);
    await showModalBottomSheet<void>(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (sheetCtx) {
      Widget tile(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(dense: true, leading: Icon(icon, color: color ?? ThixPolicy.textMain, size: 22), title: Text(label, style: ThixPolicy.bodyStyle.copyWith(color: color ?? ThixPolicy.textMain, fontWeight: FontWeight.w600, fontSize: 14)), onTap: () { Navigator.pop(sheetCtx); onTap(); });
      return Container(constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.82), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(top: false, child: SingleChildScrollView(padding: const EdgeInsets.only(top: 10, bottom: 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          if (text.isNotEmpty) tile(Icons.copy_rounded, _trL(l10n, 'post_copy_text', 'Copier le texte'), () => _copyToClipboard(context, text, _trL(l10n, 'post_text_copied', 'Texte copié'))),
          if (canCopyId) tile(Icons.link_rounded, _trL(l10n, 'post_copy_link', 'Copier le lien'), () => _copyToClipboard(context, _postLink(post.id), _trL(l10n, 'post_link_copied', 'Lien copié'))),
          tile(Icons.send_outlined, l10n.t('post_share'), () => _sharePost(post)),
          tile(post.isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined, post.isSaved ? _trL(l10n, 'post_unsave_menu', 'Retirer des enregistrements') : _trL(l10n, 'post_save_menu', 'Enregistrer'), () { if (!_isAuthenticated) return; final w = post.isSaved; ref.read(postItemProvider.notifier).toggleSave(); widget.onSave?.call(); _toast(context, w ? _trL(l10n, 'post_save_removed', 'Retiré des enregistrements') : _trL(l10n, 'post_save_done', 'Enregistré'), seconds: 1); }),
          if (images.length == 1) tile(Icons.download_rounded, _trL(l10n, 'post_download_photo', 'Télécharger la photo'), () => _downloadMedia(context, images.first)),
          if (images.length > 1) tile(Icons.collections_rounded, '${_trL(l10n, 'post_view_photos', 'Voir et télécharger les photos')} (${images.length})', () => _openGallery(0, images)),
          if (videos.isNotEmpty) tile(Icons.download_rounded, _trL(l10n, 'post_download_video', 'Télécharger la vidéo'), () => _downloadMedia(context, videos.first)),
          const Divider(height: 8),
          if (isOwner) ...[
            tile(post.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, post.isPinned ? _trL(l10n, 'post_unpin_menu', 'Désépingler du profil') : _trL(l10n, 'post_pin_menu', 'Épingler sur le profil'), () => _togglePin(post, ref, l10n)),
            tile(Icons.insights_rounded, _trL(l10n, 'post_stats_menu', 'Voir les statistiques'), () => _showStats(post, l10n)),
            if (!isCurrentUserFree) tile(Icons.edit_outlined, l10n.t('post_edit'), () => _editPost(post, ref, l10n)),
            tile(Icons.delete_outline_rounded, l10n.t('post_delete'), () => _deletePost(post, ref, l10n), color: ThixPolicy.danger),
          ] else ...[
            tile(Icons.visibility_off_outlined, l10n.t('post_hide'), () => _hidePost(post, l10n)),
            tile(Icons.flag_outlined, l10n.t('post_report'), () => _showReportDialog(post, l10n), color: ThixPolicy.danger),
          ],
        ]))));
    });
  }

  Widget _buildPinnedBadge(AppLocalizations l10n) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ThixPolicy.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8), border: Border.all(color: ThixPolicy.gold.withValues(alpha: 0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.push_pin_rounded, size: 12, color: ThixPolicy.gold), const SizedBox(width: 5), Text(l10n.t('post_pinned_label'), style: ThixPolicy.captionStyle.copyWith(fontSize: 10.5, fontWeight: FontWeight.w800, color: ThixPolicy.gold, letterSpacing: 0.3))]));

  Widget _buildHeader(NetworkPost post, bool isOwner, bool isFollowing, bool isCertified, CertificationTier? tier, CertificationStatus? status, bool isLegacyVerified, bool isCurrentUserFree, WidgetRef ref, AppLocalizations l10n) {
    final name = _PostCardValidators.sanitizeLine(post.authorName, maxLength: 100);
    return Row(children: [
      Semantics(button: true, label: l10n.t('post_open_profile', args: [name]), child: GestureDetector(onTap: () => _openProfile(post.userId), child: Stack(clipBehavior: Clip.none, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))], color: ThixPolicy.surfaceSoft), child: ClipOval(child: _safeImageUrl(post.authorAvatar) != null ? CachedNetworkImage(imageUrl: _safeImageUrl(post.authorAvatar)!, fit: BoxFit.cover) : const Icon(Icons.person_rounded, size: 20, color: ThixPolicy.textMuted))),
        if (!isOwner && !isFollowing) Positioned(bottom: -2, right: -2, child: Semantics(button: true, label: l10n.t('post_follow'), child: GestureDetector(onTap: () async {
          if (_followBusy || !_throttleFollow() || !_isAuthenticated) return; setState(() { _followBusy = true; _isFollowingLocal = true; }); HapticFeedback.selectionClick();
          try { await ref.read(networkServiceProvider).followUser(post.userId).timeout(_PostCardConfig.networkTimeout); if (!mounted) return; ref.invalidate(followStatusProvider(post.userId)); ref.invalidate(userProfileProvider(post.userId)); widget.onFollow?.call(); }
          catch (e) { _PostCardLogger.error('followUser failed', {'userId': post.userId}); if (mounted) setState(() => _isFollowingLocal = false); } finally { if (mounted) setState(() => _followBusy = false); }
        }, child: Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: _Mono.accent, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.add_rounded, size: 14, color: Colors.white))))),
      ]))),
      const SizedBox(width: 12),
      Expanded(child: GestureDetector(onTap: () => _openProfile(post.userId), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Flexible(child: Text(name, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 14.5, color: ThixPolicy.textMain, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis)), if (isCertified) CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 15, padding: const EdgeInsets.only(left: 6)) else if (isLegacyVerified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, color: _Mono.accent, size: 15))]),
        const SizedBox(height: 2), Tooltip(message: _fullDate(post.createdAt), triggerMode: TooltipTriggerMode.longPress, child: Text(_getTimeAgo(post.createdAt), style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
      ]))),
      IconButton(tooltip: _trL(l10n, 'post_more_options', "Plus d'options"), onPressed: () => _showPostMenu(post, isOwner, isCurrentUserFree, ref, l10n), icon: const Icon(Icons.more_horiz_rounded, color: ThixPolicy.textSecondary)),
    ]);
  }

  Widget _buildActionRow(NetworkPost post, bool isLiked, bool isOwner, bool isCurrentUserFree, WidgetRef ref, AppLocalizations l10n) {
    final imp = _impressionsOf(post);
    return SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: [
      _ActionBtn(icon: isLiked ? Icons.bolt_rounded : Icons.bolt_outlined, label: '', color: isLiked ? ThixPolicy.danger : ThixPolicy.textSecondary.withValues(alpha: 0.95), onTap: () async { if (!_isAuthenticated) return; HapticFeedback.selectionClick(); await ref.read(postItemProvider.notifier).toggleLike(); }, semanticsLabel: isLiked ? l10n.t('post_unlike') : l10n.t('post_like')),
      const SizedBox(width: 20), _ActionBtn(icon: Icons.chat_bubble_outline_rounded, label: _formatCountHelper(post.commentsCount), color: ThixPolicy.textSecondary.withValues(alpha: 0.8), onTap: widget.onComment ?? () => _openPostDetails(post.id), semanticsLabel: l10n.t('post_comments')),
      const SizedBox(width: 20), _ActionBtn(icon: Icons.repeat_rounded, label: _formatCountHelper(post.repostsCount), color: post.isReposted ? ThixPolicy.success : ThixPolicy.textSecondary.withValues(alpha: 0.8), onTap: () => _repost(post, ref, l10n), semanticsLabel: l10n.t('post_repost')),
      const SizedBox(width: 20), _ActionBtn(icon: Icons.bar_chart_rounded, label: _formatCountHelper(imp), color: ThixPolicy.textSecondary.withValues(alpha: 0.8), onTap: () { HapticFeedback.selectionClick(); if (isOwner) _showStats(post, l10n); else _toast(context, l10n.t('post_impressions', args: ['$imp'])); }, semanticsLabel: l10n.t('post_impressions_label')),
      const SizedBox(width: 20), _ActionBtn(icon: Icons.send_outlined, label: '', color: ThixPolicy.textSecondary.withValues(alpha: 0.8), onTap: widget.onShare ?? () => _sharePost(post), semanticsLabel: l10n.t('post_share')),
      const SizedBox(width: 20), _ActionBtn(icon: post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: '', color: post.isSaved ? ThixPolicy.textMain : ThixPolicy.textSecondary.withValues(alpha: 0.8), onTap: () { if (!_isAuthenticated) return; HapticFeedback.selectionClick(); final w = post.isSaved; ref.read(postItemProvider.notifier).toggleSave(); widget.onSave?.call(); _toast(context, w ? _trL(l10n, 'post_save_removed', 'Retiré des enregistrements') : _trL(l10n, 'post_save_done', 'Enregistré'), seconds: 1); }, semanticsLabel: post.isSaved ? l10n.t('post_unsave') : l10n.t('post_save')),
      if (isOwner && !isCurrentUserFree) ...[const SizedBox(width: 20), _ActionBtn(icon: Icons.edit_outlined, label: '', color: ThixPolicy.textMain, onTap: () => _editPost(post, ref, l10n), semanticsLabel: l10n.t('post_edit'))],
      if (isOwner) ...[const SizedBox(width: 20), _ActionBtn(icon: Icons.delete_outline_rounded, label: '', color: ThixPolicy.danger, onTap: () => _deletePost(post, ref, l10n), semanticsLabel: l10n.t('post_delete')), const SizedBox(width: 20), _ActionBtn(icon: post.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, label: '', color: post.isPinned ? ThixPolicy.gold : ThixPolicy.textSecondary.withValues(alpha: 0.8), onTap: () => _togglePin(post, ref, l10n), semanticsLabel: post.isPinned ? _trL(l10n, 'post_unpin_menu', 'Désépingler du profil') : _trL(l10n, 'post_pin_menu', 'Épingler sur le profil'))],
      if (!isOwner) ...[const SizedBox(width: 20), _ActionBtn(icon: Icons.visibility_off_outlined, label: '', color: ThixPolicy.textSecondary.withValues(alpha: 0.8), onTap: () => _hidePost(post, l10n), semanticsLabel: l10n.t('post_hide')), const SizedBox(width: 20), _ActionBtn(icon: Icons.flag_outlined, label: '', color: ThixPolicy.danger.withValues(alpha: 0.8), onTap: () => _showReportDialog(post, l10n), semanticsLabel: l10n.t('post_report'))],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    return ProviderScope(overrides: [postItemProvider.overrideWith((ref) => PostItemNotifier(widget.post, ref))], child: Consumer(builder: (context, ref, _) {
      final post = ref.watch(postItemProvider);
      final isLiked = ref.watch(postItemProvider.select((p) => p.isLiked));
      final likesCount = ref.watch(postItemProvider.select((p) => p.likesCount));
      final isOwner = widget.currentProfileId == post.userId;
      final ap = ref.watch(userProfileProvider(post.userId)).valueOrNull;
      CertificationTier? tier; CertificationStatus? status; var isCertified = false, isLegacyVerified = false;
      if (ap != null) { tier = CertificationTierX.parse(ap['certification_tier']); status = CertificationStatusX.parse(ap['certification_status']); isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated; isLegacyVerified = ap['is_verified'] == true; }
      final cp = ref.watch(userProfileProvider(widget.currentProfileId)).valueOrNull;
      var isCurrentUserFree = true; if (cp != null) { final t = (cp['certification_tier']?.toString().toLowerCase()) ?? 'gratuit'; isCurrentUserFree = t == 'gratuit' || t == 'none'; }
      final isFollowing = ref.watch(followStatusProvider(post.userId)).valueOrNull ?? _isFollowingLocal;
      final showContent = post.content.isNotEmpty && !_isGhostRepostContent(post);
      WidgetsBinding.instance.addPostFrameCallback((_) => _registerImpression(post.id));
      return RepaintBoundary(child: Container(margin: EdgeInsets.zero, decoration: BoxDecoration(border: Border(top: widget.isFirst ? const BorderSide(color: ThixPolicy.gold, width: _PostCardConfig.cardFirstTopBorderWidth) : BorderSide.none, bottom: const BorderSide(color: ThixPolicy.gold, width: _PostCardConfig.cardBottomBorderWidth))),
        child: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: _PostCardConfig.postBlurSigma, sigmaY: _PostCardConfig.postBlurSigma),
          child: Container(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.65)), child: Material(color: Colors.transparent, child: InkWell(onTap: widget.onTap ?? () => _openPostDetails(post.id), onLongPress: () => _showPostMenu(post, isOwner, isCurrentUserFree, ref, l10n),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (post.isPinned) _buildPinnedBadge(l10n),
              _buildPostBadge(post, l10n),
              _buildHeader(post, isOwner, isFollowing, isCertified, tier, status, isLegacyVerified, isCurrentUserFree, ref, l10n),
              if (post.isRepostCard) Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Row(children: [const Icon(Icons.repeat_rounded, size: 14, color: ThixPolicy.textMuted), const SizedBox(width: 6), Text(l10n.t('reposted_label'), style: ThixPolicy.captionStyle.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: ThixPolicy.textMuted))])),
              const SizedBox(height: 12),
              if (showContent) _buildPostContent(post, l10n),
              if (post.isRepostCard && _PostCardValidators.isValidId(post.repostOfId)) ...[const SizedBox(height: 12), _OriginalPostEmbed(postId: post.repostOfId!)],
              if (!post.isRepostCard && (post.hasImages || post.hasVideos)) ...[const SizedBox(height: 12), RepaintBoundary(child: _buildMediaGrid([...post.imageUrls, ...post.videoUrls], l10n))],
              if (post.hasAudio && post.audioUrls.isNotEmpty) ...[const SizedBox(height: 12), RepaintBoundary(child: _PremiumAudioPlayer(audioUrl: post.audioUrls.first, duration: post.audioDurationSeconds))],
              if (post.postType == PostType.poll && _PostCardValidators.isValidPollData(post.pollData)) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: SizedBox(width: double.infinity, child: _buildPollWidget(post, l10n)))]
              else if (post.postType == PostType.challenge) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: SizedBox(width: double.infinity, child: _buildChallengeWidget(post, l10n)))],
              const SizedBox(height: 16),
              if (likesCount > 0) RepaintBoundary(child: _LikersStack(count: likesCount, postId: post.id, isLikedByMe: isLiked, l10n: l10n)),
              const SizedBox(height: 8),
              _buildActionRow(post, isLiked, isOwner, isCurrentUserFree, ref, l10n),
            ]))))))));
    }));
  }
}

// ============================================================================
// WIDGETS AUXILIAIRES
// ============================================================================
class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback? onTap; final String? semanticsLabel;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap, this.semanticsLabel});
  @override Widget build(BuildContext context) => Semantics(button: true, label: semanticsLabel ?? label, child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 22, color: color), if (label.isNotEmpty) ...[const SizedBox(width: 4), Text(label, style: ThixPolicy.labelStyle.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: color))]]))));
}

class _PremiumAudioPlayer extends StatefulWidget {
  final String audioUrl; final int? duration;
  const _PremiumAudioPlayer({required this.audioUrl, this.duration});
  @override State<_PremiumAudioPlayer> createState() => _PremiumAudioPlayerState();
}

class _PremiumAudioPlayerState extends State<_PremiumAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false, _isValidSource = false;
  Duration _duration = Duration.zero, _position = Duration.zero;
  double _playbackSpeed = 1.0;
  StreamSubscription<PlayerState>? _ss; StreamSubscription<Duration>? _ds, _ps;
  @override void initState() { super.initState(); _isValidSource = _PostCardValidators.isValidUrl(widget.audioUrl); if (_isValidSource) { _audioPlayer.setSourceUrl(widget.audioUrl); _ss = _audioPlayer.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _isPlaying = s == PlayerState.playing); }); _ds = _audioPlayer.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); }); _ps = _audioPlayer.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); }); } }
  @override void dispose() { _ss?.cancel(); _ds?.cancel(); _ps?.cancel(); _audioPlayer.dispose(); super.dispose(); }
  void _cycleSpeed() { setState(() { _playbackSpeed = _playbackSpeed == 1.0 ? 1.5 : (_playbackSpeed == 1.5 ? 2.0 : 1.0); _audioPlayer.setPlaybackRate(_playbackSpeed); }); HapticFeedback.selectionClick(); }
  String _fmt(Duration d) => '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  @override Widget build(BuildContext context) {
    if (!_isValidSource) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final prog = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;
    final rem = _duration - _position;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_Mono.accent.withValues(alpha: 0.15), _Mono.accent.withValues(alpha: 0.05)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _Mono.accent.withValues(alpha: 0.3), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(gradient: LinearGradient(colors: [_Mono.accent, _Mono.accentDeep]), shape: BoxShape.circle), child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18)), const SizedBox(width: 10), Text(_trL(l10n, 'post_voice_note', 'Note vocale'), style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, color: ThixPolicy.textMain, fontSize: 12)), const Spacer(), if (_duration.inSeconds > 0) Text(_fmt(_duration), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 12),
        Row(children: [GestureDetector(onTap: () { if (_isPlaying) _audioPlayer.pause(); else _audioPlayer.play(UrlSource(widget.audioUrl)); HapticFeedback.lightImpact(); }, child: Container(width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_Mono.accent, _Mono.accentDeep]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: _Mono.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24))), const SizedBox(width: 14), Expanded(child: LayoutBuilder(builder: (c, cs) => GestureDetector(onTapDown: (d) { final p = d.localPosition.dx / cs.maxWidth; if (p >= 0 && p <= 1 && _duration.inMilliseconds > 0) _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * p).round())); }, child: CustomPaint(size: const Size(double.infinity, 32), painter: _WaveformPainter(progress: prog, color: _Mono.accent))))), const SizedBox(width: 10), GestureDetector(onTap: _cycleSpeed, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _Mono.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _Mono.accent.withValues(alpha: 0.3))), child: Text('${_playbackSpeed}x', style: ThixPolicy.captionStyle.copyWith(color: _Mono.accent, fontWeight: FontWeight.bold, fontSize: 11))))]),
        const SizedBox(height: 8), Row(children: [Text(_fmt(_position), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10)), const Spacer(), Text('-${_fmt(rem.isNegative ? Duration.zero : rem)}', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10))]),
      ]));
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress; final Color color;
  _WaveformPainter({required this.progress, required this.color});
  @override void paint(Canvas canvas, Size size) { const n = 40; final bw = size.width / (n * 1.5), sp = bw * 0.5; for (var i = 0; i < n; i++) { final x = i * (bw + sp), hp = (sin(i * 0.5) * 0.3 + 0.5 + (i % 3) * 0.1).clamp(0.2, 0.9), bh = size.height * hp, y = (size.height - bh) / 2; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), Radius.circular(bw / 2)), Paint()..color = (i / n) <= progress ? color : color.withValues(alpha: 0.3)..style = PaintingStyle.fill); } }
  @override bool shouldRepaint(covariant _WaveformPainter o) => o.progress != progress;
}

// ============================================================================
// LINK PREVIEW RICHE
// ============================================================================
class _PremiumLinkPreview extends StatefulWidget {
  final String url; final String? fallbackImage;
  const _PremiumLinkPreview({required this.url, this.fallbackImage});
  @override State<_PremiumLinkPreview> createState() => _PremiumLinkPreviewState();
}

class _PremiumLinkPreviewState extends State<_PremiumLinkPreview> {
  Map<String, dynamic>? _previewData; bool _isLoading = true;
  String get _domain => Uri.tryParse(widget.url)?.host.replaceFirst('www.', '') ?? '';
  String get _faviconUrl => 'https://www.google.com/s2/favicons?domain=${Uri.tryParse(widget.url)?.host ?? ''}&sz=${_PostCardConfig.avatarFallbackSize}';
  bool get _isRedirectDomain => _PostCardValidators.isKnownRedirectDomain(widget.url);
  @override void initState() { super.initState(); _loadPreview(); }
  Future<void> _loadPreview() async {
    if (!_PostCardValidators.isSafeExternalFetchUrl(widget.url)) { if (mounted) setState(() => _isLoading = false); return; }
    final cached = _PostCardCache.instance.getLinkPreview(widget.url); if (cached != null) { if (mounted) setState(() { _previewData = cached; _isLoading = false; }); return; }
    try { final r = await Supabase.instance.client.functions.invoke('link-preview', body: {'url': widget.url}).timeout(_PostCardConfig.linkPreviewTimeout); if (r.data is Map) { final d = Map<String, dynamic>.from(r.data as Map); _PostCardCache.instance.setLinkPreview(widget.url, d); if (mounted) setState(() { _previewData = d; _isLoading = false; }); } else throw Exception('Invalid'); }
    catch (e) { _PostCardLogger.error('LinkPreview fetch failed'); if (mounted) setState(() => _isLoading = false); }
  }
  Future<void> _open() async { final u = Uri.parse(widget.url); if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication); }
  @override Widget build(BuildContext context) {
    if (_isLoading) return Container(height: 200, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.8))), child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _Mono.accent))));
    if (_domain.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final title = _PostCardValidators.sanitizeLine(_previewData?['title']?.toString() ?? '', maxLength: 300);
    final desc = _PostCardValidators.sanitizeLine(_previewData?['description']?.toString() ?? '', maxLength: 500);
    final ogImg = _safeImageUrl(_previewData?['image']?.toString()) ?? _safeImageUrl(widget.fallbackImage);
    final hasOg = ogImg != null, hasReal = title.isNotEmpty || hasOg;
    if (!hasReal && _isRedirectDomain) return GestureDetector(onTap: _open, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.85))), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: _Mono.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.open_in_new_rounded, size: 17, color: _Mono.accent)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_domain, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)), const SizedBox(height: 2), Text(l10n.t('external_link'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textSecondary))])), const Icon(Icons.chevron_right_rounded, size: 18, color: ThixPolicy.textMuted)])));
    return GestureDetector(onTap: _open, onLongPress: () => _copyToClipboard(context, widget.url, _trL(l10n, 'post_link_copied', 'Lien copié')),
      child: Container(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.9)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]), clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasOg) CachedNetworkImage(imageUrl: ogImg, height: 180, width: double.infinity, fit: BoxFit.cover, placeholder: (_, __) => Container(height: 180, color: Colors.white.withValues(alpha: 0.4)), errorWidget: (_, __, ___) => Container(height: 100, width: double.infinity, color: _Mono.accent.withValues(alpha: 0.06), alignment: Alignment.center, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)), child: CachedNetworkImage(imageUrl: _faviconUrl, width: 40, height: 40, fit: BoxFit.contain, errorWidget: (_, __, ___) => const Icon(Icons.link_rounded, color: _Mono.accent, size: 28))))))
          else Container(height: 100, width: double.infinity, color: _Mono.accent.withValues(alpha: 0.06), alignment: Alignment.center, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)), child: CachedNetworkImage(imageUrl: _faviconUrl, width: 40, height: 40, fit: BoxFit.contain, placeholder: (_, __) => const SizedBox(width: 40, height: 40, child: Icon(Icons.link_rounded, color: _Mono.accent, size: 24)), errorWidget: (_, __, ___) => const Icon(Icons.link_rounded, color: _Mono.accent, size: 28))))),
          Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title.isNotEmpty) Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.bold, fontSize: 15, height: 1.25)) else Text(l10n.t('external_link'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.bold, fontSize: 15)),
            if (desc.isNotEmpty) ...[const SizedBox(height: 6), Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12.5, height: 1.35))],
            const SizedBox(height: 10), Row(children: [const Icon(Icons.link_rounded, size: 14, color: ThixPolicy.textSecondary), const SizedBox(width: 6), Expanded(child: Text(_domain, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))), CachedNetworkImage(imageUrl: _faviconUrl, width: 18, height: 18, fit: BoxFit.contain, errorWidget: (_, __, ___) => const Icon(Icons.public_rounded, size: 16, color: ThixPolicy.textMuted))]),
          ])),
        ])));
  }
}

// ============================================================================
// MINIATURE VIDÉO
// ============================================================================
class _VideoThumbTile extends StatefulWidget {
  final String videoUrl; final double? width, height; final VoidCallback onTap;
  const _VideoThumbTile({required this.videoUrl, this.width, this.height, required this.onTap});
  @override State<_VideoThumbTile> createState() => _VideoThumbTileState();
}

class _VideoThumbTileState extends State<_VideoThumbTile> {
  static int _activeFrameReaders = 0;
  String? _thumbnailUrl; VideoPlayerController? _frameController; bool _frameReady = false, _countedActive = false; Duration? _duration;
  @override void initState() { super.initState(); _thumbnailUrl = _PostCardCache.instance.getVideoThumb(widget.videoUrl); if (_thumbnailUrl == null) _loadThumbnail(); }
  Future<void> _loadThumbnail() async {
    if (!_PostCardValidators.isSafeExternalFetchUrl(widget.videoUrl)) return;
    try { final r = await Supabase.instance.client.functions.invoke('video-thumbnail', body: {'video_url': widget.videoUrl}).timeout(_PostCardConfig.videoThumbTimeout); final d = r.data; final u = d is Map ? _safeImageUrl(d['thumbnail_url']?.toString()) : null; if (u != null) { _PostCardCache.instance.setVideoThumb(widget.videoUrl, u); if (mounted) setState(() => _thumbnailUrl = u); return; } } catch (e) { _PostCardLogger.warn('Video thumbnail (server) failed'); }
    await _loadFirstFrame();
  }
  Future<void> _loadFirstFrame() async {
    if (!mounted || _frameController != null || _activeFrameReaders >= _PostCardConfig.maxVideoFrameFallbacks) return;
    final uri = Uri.tryParse(widget.videoUrl); if (uri == null || !_PostCardValidators.isValidUrl(widget.videoUrl)) return;
    _activeFrameReaders++; _countedActive = true;
    final c = VideoPlayerController.networkUrl(uri, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)); _frameController = c;
    try { await c.initialize().timeout(const Duration(seconds: 12)); await c.setVolume(0); await c.seekTo(const Duration(milliseconds: 300)); if (!mounted) return; setState(() { _frameReady = true; _duration = c.value.duration; }); }
    catch (e) { _PostCardLogger.warn('Video first frame failed'); try { await c.dispose(); } catch (_) {} if (_frameController == c) _frameController = null; }
  }
  @override void dispose() { _frameController?.dispose(); if (_countedActive && _activeFrameReaders > 0) _activeFrameReaders--; super.dispose(); }
  String _fmt(Duration d) => d.inHours > 0 ? '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}' : '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  Widget _bg() { if (_thumbnailUrl != null) return CachedNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _ph()); final c = _frameController; if (_frameReady && c != null && c.value.isInitialized) return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: c.value.size.width == 0 ? 16 : c.value.size.width, height: c.value.size.height == 0 ? 9 : c.value.size.height, child: VideoPlayer(c))); return _ph(); }
  Widget _ph() => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_Mono.accentDeep, _Mono.accent])));
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(onTap: widget.onTap, child: Container(width: widget.width, height: widget.height, color: _Mono.accentDeep, child: Stack(fit: StackFit.expand, children: [
      _bg(), Container(color: Colors.black.withValues(alpha: 0.18)),
      Center(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36))),
      Positioned(left: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.videocam_rounded, size: 12, color: Colors.white), const SizedBox(width: 4), Text((_duration != null && _duration! > Duration.zero) ? _fmt(_duration!) : _trL(l10n, 'post_video_badge', 'VIDÉO'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700))]))),
      Positioned(top: 6, right: 6, child: _MediaChipButton(icon: Icons.download_rounded, semanticsLabel: _trL(l10n, 'post_download_video', 'Télécharger la vidéo'), onTap: () => _downloadMedia(context, widget.videoUrl))),
    ])));
  }
}

class _MediaChipButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final String semanticsLabel;
  const _MediaChipButton({required this.icon, required this.onTap, required this.semanticsLabel});
  @override Widget build(BuildContext context) => Semantics(button: true, label: semanticsLabel, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35))), child: Icon(icon, size: 16, color: Colors.white))));
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls; final int initialIndex;
  const _FullScreenGallery({required this.imageUrls, required this.initialIndex});
  @override State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller; late int _index;
  @override void initState() { super.initState(); _index = widget.imageUrls.isEmpty ? 0 : widget.initialIndex.clamp(0, widget.imageUrls.length - 1); _controller = PageController(initialPage: _index); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context); final total = widget.imageUrls.length; final cur = total == 0 ? null : widget.imageUrls[_index];
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: total > 1 ? Text('${_index + 1} / $total', style: const TextStyle(color: Colors.white, fontSize: 14)) : null,
      actions: [if (cur != null) ...[IconButton(tooltip: _trL(l10n, 'post_copy_link', 'Copier le lien'), icon: const Icon(Icons.link_rounded), onPressed: () => _copyToClipboard(context, cur, _trL(l10n, 'post_link_copied', 'Lien copié'))), IconButton(tooltip: _trL(l10n, 'post_download_photo', 'Télécharger la photo'), icon: const Icon(Icons.download_rounded), onPressed: () => _downloadMedia(context, cur))]]),
      body: PageView.builder(controller: _controller, itemCount: total, onPageChanged: (i) => setState(() => _index = i), itemBuilder: (_, i) => InteractiveViewer(minScale: 1, maxScale: 4, child: Center(child: CachedNetworkImage(imageUrl: widget.imageUrls[i], fit: BoxFit.contain, placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)), errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48))))));
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});
  @override State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  VideoPlayerController? _controller; bool _initialized = false, _hasError = false, _showControls = true; Timer? _hideTimer;
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { final u = Uri.tryParse(widget.videoUrl); if (u == null || !_PostCardValidators.isValidUrl(widget.videoUrl)) { setState(() => _hasError = true); return; } final c = VideoPlayerController.networkUrl(u, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false)); _controller = c; try { await c.initialize(); if (!mounted) return; await c.setLooping(false); await c.play(); if (!mounted) return; setState(() => _initialized = true); _scheduleHide(); } catch (e) { _PostCardLogger.error('video init failed', {'error': '$e'}); if (mounted) setState(() => _hasError = true); } }
  @override void dispose() { _hideTimer?.cancel(); _controller?.dispose(); super.dispose(); }
  void _scheduleHide() { _hideTimer?.cancel(); _hideTimer = Timer(const Duration(seconds: 3), () { if (mounted && (_controller?.value.isPlaying ?? false)) setState(() => _showControls = false); }); }
  void _toggleControls() { setState(() => _showControls = !_showControls); if (_showControls) _scheduleHide(); }
  Future<void> _togglePlay() async { final c = _controller; if (c == null || !_initialized) return; HapticFeedback.selectionClick(); final v = c.value; final ended = v.duration > Duration.zero && v.position >= v.duration; if (v.isPlaying) { await c.pause(); _hideTimer?.cancel(); } else { if (ended) await c.seekTo(Duration.zero); await c.play(); _scheduleHide(); } }
  String _fmt(Duration d) => d.inHours > 0 ? '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}' : '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(backgroundColor: Colors.black, extendBodyBehindAppBar: true, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), actions: [IconButton(tooltip: _trL(l10n, 'post_download_video', 'Télécharger la vidéo'), icon: const Icon(Icons.download_rounded), onPressed: () => _downloadMedia(context, widget.videoUrl))]), body: _body(l10n));
  }
  Widget _body(AppLocalizations l10n) {
    if (_hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 40), const SizedBox(height: 12), Text(_trL(l10n, 'post_video_error', 'Impossible de lire cette vidéo'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14))])));
    final c = _controller; if (!_initialized || c == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggleControls, child: Stack(fit: StackFit.expand, children: [
      Center(child: AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c))),
      ValueListenableBuilder<VideoPlayerValue>(valueListenable: c, builder: (ctx, v, _) { final ended = v.duration > Duration.zero && v.position >= v.duration; final sc = _showControls || !v.isPlaying; return Stack(fit: StackFit.expand, children: [if (v.isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white)), if (sc && !v.isBuffering) Center(child: GestureDetector(onTap: _togglePlay, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle), child: Icon(ended ? Icons.replay_rounded : (v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded), color: Colors.white, size: 44)))), if (_showControls) Positioned(left: 16, right: 16, bottom: 24, child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 8), colors: VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white38, backgroundColor: Colors.white24)), Row(children: [Text(_fmt(v.position), style: const TextStyle(color: Colors.white, fontSize: 12)), const Spacer(), Text(_fmt(v.duration), style: const TextStyle(color: Colors.white70, fontSize: 12))])])))]); }),
    ]));
  }
}

class _OriginalPostEmbed extends ConsumerWidget {
  final String postId;
  const _OriginalPostEmbed({required this.postId});
  BoxDecoration get _box => BoxDecoration(color: _Mono.accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: _Mono.accent.withValues(alpha: 0.15)));
  @override Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(_originalPostProvider(postId));
    return a.when(loading: () => Container(height: 90, decoration: _box, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _Mono.accent)))), error: (_, __) => _unavail(context), data: (o) => o == null ? _unavail(context) : _card(context, o));
  }
  Widget _unavail(BuildContext context) { final l10n = AppLocalizations.of(context); return Container(padding: const EdgeInsets.all(12), decoration: _box, child: Row(children: [const Icon(Icons.info_outline_rounded, color: ThixPolicy.textSecondary, size: 18), const SizedBox(width: 8), Expanded(child: Text(_trL(l10n, 'post_original_unavailable', "Ce post n'est plus disponible"), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)))])); }
  Widget _card(BuildContext context, NetworkPost o) {
    final l10n = AppLocalizations.of(context); final name = _PostCardValidators.sanitizeLine(o.authorName, maxLength: 100); final av = _safeImageUrl(o.authorAvatar); final content = _PostCardValidators.sanitize(_plainText(o.content), maxLength: 600);
    final mu = <String>[...o.imageUrls.where(_PostCardValidators.isValidUrl), ...o.videoUrls.where(_PostCardValidators.isValidUrl)];
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (!_PostCardValidators.isValidId(o.id)) return; HapticFeedback.selectionClick(); context.push('/network/comments/${o.id}'); },
      child: Container(padding: const EdgeInsets.all(12), decoration: _box, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.surfaceSoft, border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2)), child: ClipOval(child: av != null ? CachedNetworkImage(imageUrl: av, fit: BoxFit.cover) : const Icon(Icons.person_rounded, size: 15, color: ThixPolicy.textMuted))), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.isEmpty ? _trL(l10n, 'post_user_fallback', 'Utilisateur') : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: ThixPolicy.textMain)), Text(timeago.format(o.createdAt.toLocal(), locale: 'fr'), style: ThixPolicy.captionStyle.copyWith(fontSize: 10.5, color: ThixPolicy.textSecondary))]))]),
        if (content.isNotEmpty) ...[const SizedBox(height: 10), Text(content, maxLines: 5, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, height: 1.4, color: ThixPolicy.textMain))],
        if (mu.isNotEmpty) ...[const SizedBox(height: 10), _media(context, mu)],
      ])));
  }
  Widget _media(BuildContext context, List<String> urls) {
    final first = urls.first; final io = urls.where((u) => !_isVideoUrl(u)).toList(); final extra = urls.length - 1;
    Widget tile; if (_isVideoUrl(first)) tile = _VideoThumbTile(videoUrl: first, width: double.infinity, height: 190, onTap: () { HapticFeedback.mediumImpact(); Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenVideoPlayer(videoUrl: first))); });
    else tile = GestureDetector(onTap: () { HapticFeedback.mediumImpact(); Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenGallery(imageUrls: io, initialIndex: io.indexOf(first).clamp(0, io.length - 1)))); }, child: CachedNetworkImage(imageUrl: first, width: double.infinity, height: 190, fit: BoxFit.cover, memCacheWidth: 600, placeholder: (_, __) => Container(color: Colors.white.withValues(alpha: 0.5)), errorWidget: (_, __, ___) => Container(height: 190, color: Colors.white.withValues(alpha: 0.5), child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted))));
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 190, width: double.infinity, child: Stack(fit: StackFit.expand, children: [tile, if (extra > 0) Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)), child: Text('+$extra', style: ThixPolicy.captionStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))))])));
  }
}

class _LikersStack extends StatefulWidget {
  final int count; final String postId; final bool isLikedByMe; final AppLocalizations l10n;
  const _LikersStack({required this.count, required this.postId, required this.isLikedByMe, required this.l10n});
  @override State<_LikersStack> createState() => _LikersStackState();
}

class _LikersStackState extends State<_LikersStack> {
  List<String> _avatars = []; bool _loading = true;
  @override void initState() { super.initState(); _fetch(); }
  @override void didUpdateWidget(covariant _LikersStack o) { super.didUpdateWidget(o); if (widget.count != o.count) _fetch(); }
  Future<void> _fetch() async {
    if (widget.count == 0) { if (mounted) setState(() { _loading = false; _avatars = []; }); return; }
    final cached = _PostCardCache.instance.getLikers(widget.postId); if (cached != null) { if (mounted) setState(() { _avatars = cached; _loading = false; }); return; }
    try { final r = await Supabase.instance.client.from('post_likes').select('user_id, profiles(avatar_url)').eq('post_id', widget.postId).order('created_at', ascending: false).limit(_PostCardConfig.maxLikersFetched).timeout(_PostCardConfig.networkTimeout); final a = <String>[]; if (r is List) for (final row in r) { final p = row['profiles']; a.add(p is Map ? _safeImageUrl(p['avatar_url']?.toString()) ?? '' : ''); } _PostCardCache.instance.setLikers(widget.postId, a); if (mounted) setState(() { _avatars = a; _loading = false; }); }
    catch (e) { _PostCardLogger.error('fetchLikersAvatars failed', {'postId': widget.postId}); if (mounted) setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) {
    final dc = min(_PostCardConfig.maxLikersFetched, widget.count), extra = widget.count - dc;
    final colors = [_Mono.accent, ThixPolicy.danger, _Mono.accentDeep, ThixPolicy.info, ThixPolicy.domainMedia];
    final text = widget.isLikedByMe ? (widget.count == 1 ? widget.l10n.t('post_liked_by_you') : widget.l10n.t('post_liked_by_you_and_others', args: ['${widget.count - 1}'])) : widget.l10n.t('post_liked_by_others', args: ['${widget.count}']);
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
      Row(children: List.generate(dc, (i) { final a = _avatars.length > i ? _avatars[i] : ''; final has = a.isNotEmpty && !_loading; return Align(widthFactor: 0.7, child: Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[(widget.postId.hashCode + i).abs() % colors.length], border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5), image: has ? DecorationImage(image: CachedNetworkImageProvider(a), fit: BoxFit.cover) : null), child: !has ? const Icon(Icons.person, size: 12, color: Colors.white) : null)); })),
      if (extra > 0) Padding(padding: const EdgeInsets.only(left: 4), child: Text('+$extra', style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.bold))),
      const SizedBox(width: 8), Expanded(child: Text(text, style: ThixPolicy.captionStyle.copyWith(fontSize: 12.5, color: ThixPolicy.textSecondary), overflow: TextOverflow.ellipsis)),
    ]));
  }
}
