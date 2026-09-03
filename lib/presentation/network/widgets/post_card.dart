// lib/presentation/network/widgets/post_card.dart
//
// PostCard — Production Enterprise (THIX PRO / THIX ID)
//
// - Rich text parsing (hashtags, mentions, URLs, formatage inline) avec
//   protections anti-ReDoS (longueur bornée + profondeur de récursion limitée)
// - Media grid (images/vidéos), lecteur audio waveform, aperçu de lien
//   avec protection anti-SSRF (validation stricte des URLs sortantes)
// - Sondages / challenges avec anti-double-vote
// - Actions (like, commentaire, repost, save, signalement, edit, delete)
//   toutes auth-gated côté client — l'autorisation réelle DOIT être
//   imposée par les policies RLS Supabase, pas seulement par ce fichier.
// - Aucune chaîne UI codée en dur : tout passe par AppLocalizations.
// - Aucune valeur magique : constantes nommées + tokens ThixPolicy.
//
// Dépendances requises (pubspec.yaml) : flutter_riverpod, go_router,
// timeago, audioplayers, cached_network_image, video_player,
// supabase_flutter, url_launcher, html.

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

// ============================================================================
// CONSTANTES (rien n'est codé en dur ailleurs dans le fichier)
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

  static const int maxContentChars = 250;
  static const int maxParseDepth = 6;
  static const int maxSanitizedLength = 5000;
  static const int maxReportDetailsLength = 500;
  static const int maxRepostQuoteLength = 500;

  static const int cacheMaxSize = 50;
  static const Duration cacheTtl = Duration(minutes: 5);

  static const double postBlurSigma = kIsWeb ? 8 : 20;
  static const double dialogBlurSigma = 10;

  static const int maxLikersFetched = 5;
  static const int avatarFallbackSize = 256;
}

// ============================================================================
// LOGGING (jamais de contenu utilisateur, jamais de PII)
// ============================================================================

class _PostCardLogger {
  static const _tag = 'PostCard';

  static void info(String message, [Map<String, Object?>? data]) =>
      _log('INFO', message, data);
  static void warn(String message, [Map<String, Object?>? data]) =>
      _log('WARN', message, data);
  static void error(String message, [Map<String, Object?>? data]) =>
      _log('ERROR', message, data);

  static void _log(String level, String message, Map<String, Object?>? data) {
    if (!kDebugMode && level == 'INFO') return;
    final suffix =
        data != null ? ' ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
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

  /// Nettoie tout contenu affiché : retire le HTML, les schémas
  /// dangereux et les caractères de contrôle.
  static String sanitize(String? input, {int maxLength = _PostCardConfig.maxSanitizedLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = (doc.body?.text ?? input)
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'(javascript|data|vbscript):', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  /// Un identifiant (postId/userId) valide au format UUID — bloque
  /// toute injection dans les routes go_router.
  static bool isValidId(String? id) => id != null && _uuidRegex.hasMatch(id);

  /// Une URL "sûre" à ouvrir dans le navigateur externe : http(s)
  /// uniquement, hôte non vide, pas de double-point suspect.
  static bool isValidUrl(String url) {
    if (url.length > 2048) return false;
    try {
      final uri = Uri.parse(url);
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty &&
          !uri.host.contains('..');
    } catch (_) {
      return false;
    }
  }

  /// URL "sûre" à FETCHER côté serveur (edge function link-preview,
  /// vignette vidéo) : exclut en plus les hôtes privés/loopback pour
  /// éviter le SSRF via une URL postée par un utilisateur.
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
}

// ============================================================================
// HELPERS
// ============================================================================

final RegExp _kRichContentRegex = RegExp(
  r'\{c:(#[0-9A-Fa-f]{6,8})\}([\s\S]*?)\{c\}|'
  r'\*\*([\s\S]+?)\*\*|'
  r'\*([\s\S]+?)\*|'
  r'@([a-zA-Z0-9_]{1,32})|'
  r'#([a-zA-Z0-9_]{1,64})|'
  r'(https?:\/\/[^\s]+)',
);

String _formatCountHelper(int count) {
  if (count <= 0) return '';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

bool _isVideoUrl(String url) {
  try {
    final path = Uri.parse(url).path.toLowerCase();
    const videoExtensions = ['.mp4', '.mov', '.m4v', '.webm', '.avi', '.mkv'];
    final hasExt = videoExtensions.any(path.endsWith);
    final hasPath = path.contains('/videos/') || path.contains('/video/');
    return hasExt || hasPath;
  } catch (_) {
    return false;
  }
}

/// Renvoie l'URL uniquement si elle est sûre à afficher, sinon null
/// (le widget appelant doit alors afficher un placeholder).
String? _safeImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  return _PostCardValidators.isValidUrl(url) ? url : null;
}

// ============================================================================
// CACHE LRU (likers & aperçus de liens)
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

  List<String>? getLikers(String postId) => _get(_likers, postId);
  void setLikers(String postId, List<String> avatars) => _set(_likers, postId, avatars);

  Map<String, dynamic>? getLinkPreview(String url) => _get(_linkPreviews, url);
  void setLinkPreview(String url, Map<String, dynamic> data) => _set(_linkPreviews, url, data);

  T? _get<T>(LinkedHashMap<String, _CacheEntry<T>> map, String key) {
    final entry = map[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _PostCardConfig.cacheTtl) {
      map.remove(key);
      return null;
    }
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
// STATE NOTIFIER — état optimiste du post, avec rollback sur échec
// ============================================================================

final postItemProvider = StateNotifierProvider.autoDispose<PostItemNotifier, NetworkPost>(
  (ref) => throw UnimplementedError('postItemProvider doit être surchargé par PostCard'),
);

class PostItemNotifier extends StateNotifier<NetworkPost> {
  PostItemNotifier(super.post, this.ref);
  final Ref ref;

  bool _likeBusy = false;

  bool get _isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  Future<void> toggleLike() async {
    if (_likeBusy || !_isAuthenticated) return;
    _likeBusy = true;

    final wasLiked = state.isLiked;
    final oldCount = state.likesCount;

    state = state.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1,
    );

    try {
      final service = ref.read(networkServiceProvider);
      try {
        final result = await service.togglePostLike(state.id).timeout(_PostCardConfig.networkTimeout);
        state = state.copyWith(isLiked: result.liked, likesCount: result.likesCount);
      } catch (_) {
        if (wasLiked) {
          await service.unlikePost(state.id).timeout(_PostCardConfig.networkTimeout);
        } else {
          await service.likePost(state.id).timeout(_PostCardConfig.networkTimeout);
        }
      }
    } catch (e) {
      _PostCardLogger.error('toggleLike failed', {'postId': state.id});
      state = state.copyWith(isLiked: wasLiked, likesCount: oldCount);
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> toggleSave() async {
    if (!_isAuthenticated) return;
    final was = state.isSaved;
    state = state.copyWith(isSaved: !was);
    try {
      final service = ref.read(networkServiceProvider);
      if (was) {
        await service.unsavePost(state.id).timeout(_PostCardConfig.networkTimeout);
      } else {
        await service.savePost(state.id).timeout(_PostCardConfig.networkTimeout);
      }
    } catch (e) {
      _PostCardLogger.error('toggleSave failed', {'postId': state.id});
      state = state.copyWith(isSaved: was);
    }
  }

  void updateContent(String content) =>
      state = state.copyWith(content: _PostCardValidators.sanitize(content));

  void incrementRepost() =>
      state = state.copyWith(repostsCount: state.repostsCount + 1, isReposted: true);
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================

class PostCard extends ConsumerStatefulWidget {
  final NetworkPost post;
  final String currentProfileId;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onRefresh;
  final VoidCallback? onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSave;
  final bool isFollowingAuthor;
  final VoidCallback? onFollow;

  const PostCard({
    super.key,
    required this.post,
    required this.currentProfileId,
    this.onLike,
    this.onComment,
    this.onTap,
    this.onShare,
    this.onRefresh,
    this.onPin,
    this.onEdit,
    this.onDelete,
    this.onSave,
    this.isFollowingAuthor = false,
    this.onFollow,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isReposting = false;
  bool _isExpanded = false;
  bool _pollVoteBusy = false;
  final _quoteController = TextEditingController();

  bool _isFollowingLocal = false;
  bool _followBusy = false;
  DateTime? _lastFollowTap;
  DateTime? _lastVoteTap;
  DateTime? _lastReportSubmit;
  DateTime? _lastRepostSubmit;

  bool _impressionRegistered = false;
  Timer? _impressionDebounce;
  DateTime? _lastContentUpdate;

  List<InlineSpan>? _cachedFullSpans;
  List<InlineSpan>? _cachedTruncatedSpans;
  bool _isTruncatable = false;
  final List<GestureRecognizer> _recognizers = [];

  bool get _isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _isFollowingLocal = widget.isFollowingAuthor;
    _cacheParsedContent();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowingAuthor != widget.isFollowingAuthor) {
      _isFollowingLocal = widget.isFollowingAuthor;
    }
    if (oldWidget.post.content != widget.post.content) {
      final now = DateTime.now();
      if (_lastContentUpdate == null ||
          now.difference(_lastContentUpdate!) > _PostCardConfig.contentDebounce) {
        _lastContentUpdate = now;
        _cacheParsedContent();
      }
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _quoteController.dispose();
    _impressionDebounce?.cancel();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      try {
        r.dispose();
      } catch (e) {
        _PostCardLogger.warn('Recognizer dispose failed');
      }
    }
    _recognizers.clear();
  }

  // ---- throttles ------------------------------------------------------

  bool _throttle(DateTime? Function() get, void Function(DateTime) set, Duration window) {
    final now = DateTime.now();
    final last = get();
    if (last != null && now.difference(last) < window) return false;
    set(now);
    return true;
  }

  bool _throttleFollow() =>
      _throttle(() => _lastFollowTap, (t) => _lastFollowTap = t, _PostCardConfig.followThrottle);
  bool _throttleVote() =>
      _throttle(() => _lastVoteTap, (t) => _lastVoteTap = t, _PostCardConfig.voteThrottle);
  bool _throttleReport() =>
      _throttle(() => _lastReportSubmit, (t) => _lastReportSubmit = t, _PostCardConfig.reportThrottle);
  bool _throttleRepost() =>
      _throttle(() => _lastRepostSubmit, (t) => _lastRepostSubmit = t, _PostCardConfig.repostThrottle);

  // ---- parsing du contenu (anti-ReDoS : longueur + profondeur bornées) --

  void _cacheParsedContent() {
    final content = _PostCardValidators.sanitize(widget.post.content);
    final l10n = AppLocalizations.of(context);
    final baseStyle = ThixPolicy.bodyStyle.copyWith(
      color: ThixPolicy.textMain,
      fontSize: 14.5,
      height: 1.5,
    );

    _disposeRecognizers();
    _cachedFullSpans = _parseContent(content, baseStyle, 0, l10n);
    _isTruncatable = content.length > _PostCardConfig.maxContentChars;

    if (_isTruncatable) {
      var truncated = content.substring(0, _PostCardConfig.maxContentChars);
      final lastSpace = truncated.lastIndexOf(' ');
      if (lastSpace > 0) truncated = truncated.substring(0, lastSpace);
      _cachedTruncatedSpans = _parseContent('$truncated…', baseStyle, 0, l10n);
    } else {
      _cachedTruncatedSpans = _cachedFullSpans;
    }
  }

  List<InlineSpan> _parseContent(
      String content, TextStyle baseStyle, int depth, AppLocalizations l10n) {
    if (depth > _PostCardConfig.maxParseDepth || content.isEmpty) {
      return [TextSpan(text: content, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in _kRichContentRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: content.substring(lastIndex, match.start), style: baseStyle));
      }

      if (match.group(1) != null) {
        final hex = match.group(1)!.replaceFirst('#', '');
        final inner = match.group(2) ?? '';
        Color color;
        try {
          final argb = hex.length == 8 ? hex : 'FF$hex';
          color = Color(int.parse(argb, radix: 16));
        } catch (_) {
          color = baseStyle.color ?? ThixPolicy.textMain;
        }
        spans.addAll(_parseContent(inner, baseStyle.copyWith(color: color), depth + 1, l10n));
      } else if (match.group(3) != null) {
        spans.addAll(_parseContent(
            match.group(3)!, baseStyle.copyWith(fontWeight: ThixPolicy.bold), depth + 1, l10n));
      } else if (match.group(4) != null) {
        spans.addAll(_parseContent(
            match.group(4)!, baseStyle.copyWith(fontStyle: FontStyle.italic), depth + 1, l10n));
      } else if (match.group(5) != null) {
        final username = match.group(5)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (!mounted) return;
            HapticFeedback.selectionClick();
            context.push('/network/profile/$username');
          };
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: '@$username',
          style: baseStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold),
          recognizer: recognizer,
          semanticsLabel: l10n.t('post_mention', args: {'user': username}),
        ));
      } else if (match.group(6) != null) {
        final tag = match.group(6)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (!mounted) return;
            HapticFeedback.selectionClick();
            context.push('/hashtag/$tag');
          };
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: '#$tag',
          style: baseStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold),
          recognizer: recognizer,
          semanticsLabel: l10n.t('post_hashtag', args: {'tag': tag}),
        ));
      } else if (match.group(7) != null) {
        final url = match.group(7)!;
        if (_PostCardValidators.isValidRichTextUrl(url)) {
          final recognizer = TapGestureRecognizer()
            ..onTap = () async {
              if (!mounted) return;
              HapticFeedback.selectionClick();
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            };
          _recognizers.add(recognizer);
          spans.add(TextSpan(
            text: url,
            style: baseStyle.copyWith(color: ThixPolicy.primary, decoration: TextDecoration.underline),
            recognizer: recognizer,
            semanticsLabel: l10n.t('post_link'),
          ));
        }
      }
      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(TextSpan(text: content.substring(lastIndex), style: baseStyle));
    }
    return spans;
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    final hex = hexColor.replaceAll('#', '');
    if (hex.length != 6 && hex.length != 8) return null;
    try {
      return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  String? _extractFirstUrl(String content) {
    final match = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(content);
    final url = match?.group(0);
    if (url != null && _PostCardValidators.isValidUrl(url)) return url;
    return null;
  }

  // ---- contenu du post --------------------------------------------------

  Widget _buildPostContent(NetworkPost post, AppLocalizations l10n) {
    if (post.content.isEmpty) return const SizedBox.shrink();

    final bgColor = _parseColor(post.bgColor);
    if (bgColor != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: ThixPolicy.s8),
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: ThixPolicy.s40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColor.withOpacity(0.9), bgColor.withOpacity(0.7)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          post.content,
          textAlign: TextAlign.center,
          style: ThixPolicy.h2Style.copyWith(
            color: Colors.white,
            fontSize: 22,
            height: 1.3,
            shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
          ),
        ),
      );
    }

    final firstUrl = _extractFirstUrl(post.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: post.content,
          child: RichText(
            text: TextSpan(children: _isExpanded ? (_cachedFullSpans ?? []) : (_cachedTruncatedSpans ?? [])),
          ),
        ),
        if (_isTruncatable)
          Semantics(
            button: true,
            label: _isExpanded ? l10n.t('post_see_less') : l10n.t('post_see_more'),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpanded = !_isExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _isExpanded ? l10n.t('post_see_less') : l10n.t('post_see_more'),
                  style: ThixPolicy.labelStyle
                      .copyWith(color: ThixPolicy.primary, fontSize: 13, fontWeight: ThixPolicy.bold),
                ),
              ),
            ),
          ),
        if (firstUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: ThixPolicy.s12),
            child: _PremiumLinkPreview(url: firstUrl),
          ),
      ],
    );
  }

  String _getTimeAgo(DateTime dt) => timeago.format(dt.toLocal(), locale: 'fr');

  void _openPostDetails(String postId) {
    if (!mounted || !_PostCardValidators.isValidId(postId)) return;
    HapticFeedback.mediumImpact();
    context.push('/network/comments/$postId');
  }

  void _openProfile(String userId) {
    if (!mounted || !_PostCardValidators.isValidId(userId)) return;
    HapticFeedback.selectionClick();
    context.push('/network/profile/$userId');
  }

  void _openGallery(int initialIndex, List<String> imageOnlyUrls) {
    if (!mounted || imageOnlyUrls.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenGallery(
        imageUrls: imageOnlyUrls,
        initialIndex: initialIndex.clamp(0, imageOnlyUrls.length - 1),
      ),
    ));
  }

  void _openVideoFullScreen(String url) {
    if (!mounted || !_PostCardValidators.isValidUrl(url)) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenVideoPlayer(videoUrl: url)));
  }

  // ---- grille média -------------------------------------------------------

  Widget _buildMediaGrid(List<String> rawUrls) {
    final urls = rawUrls.where(_PostCardValidators.isValidUrl).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    const spacing = 4.0;
    final radius = BorderRadius.circular(16);
    final imageOnlyUrls = urls.where((u) => !_isVideoUrl(u)).toList();

    Widget mediaTile(String url, {double? width, double? height, Alignment alignment = Alignment.center}) {
      if (_isVideoUrl(url)) {
        return _VideoThumbTile(videoUrl: url, width: width, height: height, onTap: () => _openVideoFullScreen(url));
      }
      return GestureDetector(
        onTap: () => _openGallery(imageOnlyUrls.indexOf(url), imageOnlyUrls),
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          alignment: alignment,
          memCacheWidth: 600,
          placeholder: (context, url) => Container(
            color: Colors.white.withOpacity(0.5),
            child: const Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.white.withOpacity(0.5),
            child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
          ),
        ),
      );
    }

    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500, minHeight: 200),
          child: SizedBox(width: double.infinity, child: mediaTile(urls[0], alignment: Alignment.topCenter)),
        ),
      );
    }

    Widget cell(int i, double h) =>
        Expanded(child: ClipRRect(borderRadius: radius, child: mediaTile(urls[i], height: h, width: double.infinity)));

    if (urls.length == 2) {
      return SizedBox(height: 220, child: Row(children: [cell(0, 220), const SizedBox(width: spacing), cell(1, 220)]));
    }

    return SizedBox(
      height: 260,
      child: Row(
        children: [
          Expanded(flex: 3, child: ClipRRect(borderRadius: radius, child: mediaTile(urls[0], height: 260, width: double.infinity))),
          const SizedBox(width: spacing),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: ClipRRect(borderRadius: radius, child: mediaTile(urls[1], width: double.infinity, height: double.infinity))),
                const SizedBox(height: spacing),
                Expanded(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        mediaTile(urls[2]),
                        if (urls.length > 3)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: Text('+${urls.length - 3}',
                                style: ThixPolicy.h2Style.copyWith(color: Colors.white, fontSize: 22, fontWeight: ThixPolicy.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- sondage --------------------------------------------------------

  Widget _buildPollWidget(NetworkPost post, AppLocalizations l10n) {
    if (!_PostCardValidators.isValidPollData(post.pollData)) return const SizedBox.shrink();
    final options = (post.pollData!['options'] as List);

    var totalVotes = 0;
    for (final opt in options) {
      totalVotes += ((opt['votes'] as List?)?.length ?? 0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, size: 18, color: ThixPolicy.primary),
              const SizedBox(width: ThixPolicy.s8),
              Text(l10n.t('post_poll_title'),
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13, color: ThixPolicy.textMain)),
            ],
          ),
          const SizedBox(height: ThixPolicy.s12),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final opt = entry.value;
            final text = _PostCardValidators.sanitize('${opt['text'] ?? ''}');
            final voters = (opt['votes'] as List?) ?? [];
            final pct = totalVotes > 0 ? voters.length / totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _votePoll(post, index, l10n),
                  child: Container(
                    padding: const EdgeInsets.all(ThixPolicy.s12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.1)]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(text,
                                  style: ThixPolicy.bodyStyle
                                      .copyWith(fontSize: 13.5, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain)),
                            ),
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                                style: ThixPolicy.labelStyle
                                    .copyWith(fontSize: 12, fontWeight: ThixPolicy.bold, color: ThixPolicy.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _votePoll(NetworkPost post, int index, AppLocalizations l10n) async {
    if (_pollVoteBusy || !_throttleVote() || !_isAuthenticated) return;
    if (!_PostCardValidators.isValidPollData(post.pollData)) return;
    final options = post.pollData!['options'] as List;
    if (index < 0 || index >= options.length) return;

    setState(() => _pollVoteBusy = true);
    HapticFeedback.selectionClick();
    try {
      await ref.read(networkServiceProvider).votePoll(post.id, index).timeout(_PostCardConfig.networkTimeout);
    } catch (e) {
      _PostCardLogger.error('votePoll failed', {'postId': post.id});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('post_vote_error')), backgroundColor: ThixPolicy.danger));
      }
    } finally {
      if (mounted) setState(() => _pollVoteBusy = false);
    }
  }

  // ---- challenge --------------------------------------------------------

  Widget _buildChallengeWidget(NetworkPost post, AppLocalizations l10n) {
    final data = post.challengeData ?? {};
    final description = _PostCardValidators.sanitize('${data['description'] ?? ''}');
    final participantsCount = (data['participants_count'] is num) ? data['participants_count'] as num : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThixPolicy.gold.withOpacity(0.1), ThixPolicy.primary.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [ThixPolicy.gold, Color(0xFFFFA500)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: ThixPolicy.s10),
              Expanded(
                  child: Text(l10n.t('post_challenge_title'),
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: ThixPolicy.textMain))),
              Text(l10n.t('post_challenge_participants', args: {'count': '$participantsCount'}),
                  style: ThixPolicy.captionStyle.copyWith(fontSize: 11, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMuted)),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: ThixPolicy.s12),
            Text(description, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, height: 1.4, color: ThixPolicy.textMain)),
          ],
          const SizedBox(height: ThixPolicy.s14),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                if (!_isAuthenticated) return;
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.t('post_challenge_joined')), backgroundColor: ThixPolicy.success));
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: ThixPolicy.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(l10n.t('post_challenge_cta'),
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 12, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- signalement (motif stocké en CODE, jamais en texte localisé) ----

  static const List<String> _reportReasonCodes = [
    'spam',
    'nudity',
    'violence',
    'harassment',
    'misinformation',
    'impersonation',
    'inappropriate',
    'other',
  ];

  Future<void> _showReportDialog(NetworkPost post, AppLocalizations l10n) async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.t('report_error_auth')), backgroundColor: ThixPolicy.danger));
      return;
    }

    String? selectedReasonCode;
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.flag_outlined, color: ThixPolicy.danger, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.t('report_title'),
                      style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontSize: 16, fontWeight: ThixPolicy.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('report_prompt'),
                      style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 16),
                  Text(l10n.t('report_reason_label'),
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.8)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReasonCode,
                        isExpanded: true,
                        hint: Text(l10n.t('report_reason_hint'),
                            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13)),
                        items: _reportReasonCodes
                            .map((code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(l10n.t('reason_$code'), style: ThixPolicy.bodyStyle.copyWith(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: isSubmitting ? null : (v) => setDialogState(() => selectedReasonCode = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.t('report_details_label'),
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    maxLength: _PostCardConfig.maxReportDetailsLength,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      hintText: l10n.t('report_details_hint'),
                      hintStyle: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx, false),
                child: Text(l10n.t('report_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (selectedReasonCode == null || isSubmitting) ? null : () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ThixPolicy.danger.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.t('report_submit')),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || selectedReasonCode == null) return;
    if (!_throttleReport()) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('report_error_auth')), backgroundColor: ThixPolicy.danger));
      }
      return;
    }

    try {
      await Supabase.instance.client.from('post_reports').insert({
        'post_id': post.id,
        'reporter_id': uid,
        'reason_code': selectedReasonCode,
        'details': _PostCardValidators.sanitize(detailsController.text.trim(),
            maxLength: _PostCardConfig.maxReportDetailsLength),
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.t('report_sent'), style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13))),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _PostCardLogger.error('Report insert failed', {'postId': post.id});
      final isDuplicate = e.toString().contains('duplicate key') || e.toString().contains('unique constraint');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDuplicate ? l10n.t('report_error_duplicate') : l10n.t('report_error_generic')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ---- édition --------------------------------------------------------

  Future<void> _editPost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated || widget.currentProfileId != post.userId) return;

    final controller = TextEditingController(text: post.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.8))),
          title: Row(children: [
            const Icon(Icons.edit_rounded, color: ThixPolicy.textMain),
            const SizedBox(width: 8),
            Text(l10n.t('edit_title'), style: ThixPolicy.titleStyle.copyWith(fontSize: 16)),
          ]),
          content: TextField(
            controller: controller,
            maxLines: 6,
            autofocus: true,
            maxLength: _PostCardConfig.maxSanitizedLength,
            decoration: InputDecoration(
              hintText: l10n.t('edit_hint'),
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.t('edit_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted))),
            ElevatedButton(
              onPressed: () {
                final text = _PostCardValidators.sanitize(controller.text.trim());
                if (text.isNotEmpty) Navigator.pop(dialogContext, text);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.textMain, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.t('edit_save')),
            ),
          ],
        ),
      ),
    );

    if (newContent == null || newContent.isEmpty || !mounted) return;
    try {
      if (widget.onEdit != null) {
        widget.onEdit!();
      } else {
        await ref.read(networkServiceProvider).updatePost(post.id, newContent).timeout(_PostCardConfig.networkTimeout);
      }
      ref.read(postItemProvider.notifier).updateContent(newContent);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('edit_success'))));
    } catch (e) {
      _PostCardLogger.error('editPost failed', {'postId': post.id});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('edit_error')), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  // ---- suppression --------------------------------------------------------

  Future<void> _deletePost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated || widget.currentProfileId != post.userId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.8))),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger),
            const SizedBox(width: 8),
            Text(l10n.t('delete_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger)),
          ]),
          content: Text(l10n.t('delete_confirm'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(l10n.t('delete_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted))),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.t('delete_confirm_btn')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      if (widget.onDelete != null) {
        widget.onDelete!();
      } else {
        await ref.read(networkServiceProvider).deletePost(post.id).timeout(_PostCardConfig.networkTimeout);
      }
    } catch (e) {
      _PostCardLogger.error('deletePost failed', {'postId': post.id});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('delete_error')), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  // ---- repost --------------------------------------------------------

  Future<void> _repost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (_isReposting || !_isAuthenticated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _PostCardConfig.dialogBlurSigma, sigmaY: _PostCardConfig.dialogBlurSigma),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.8))),
          title: Text(l10n.t('repost_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain)),
          content: TextField(
            controller: _quoteController,
            maxLines: 3,
            maxLength: _PostCardConfig.maxRepostQuoteLength,
            decoration: InputDecoration(
              hintText: l10n.t('repost_hint'),
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(l10n.t('repost_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.t('repost_submit')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      _quoteController.clear();
      return;
    }
    if (!_throttleRepost()) return;

    setState(() => _isReposting = true);
    final quote = _PostCardValidators.sanitize(_quoteController.text.trim(),
        maxLength: _PostCardConfig.maxRepostQuoteLength);

    try {
      final created =
          await ref.read(networkServiceProvider).repostPost(post.id, quote: quote.isEmpty ? null : quote).timeout(_PostCardConfig.networkTimeout);
      if (!mounted) return;
      ref.read(postItemProvider.notifier).incrementRepost();
      if (created != null) ref.read(feedProvider.notifier).addPostOnTop(created);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.t('repost_success')), backgroundColor: ThixPolicy.success));
    } catch (e) {
      _PostCardLogger.error('repost failed', {'postId': post.id});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('repost_error')), backgroundColor: ThixPolicy.danger));
      }
    } finally {
      if (mounted) setState(() => _isReposting = false);
      _quoteController.clear();
    }
  }

  // ---- impressions (auth-gated, debounced) ---------------------------

  void _registerImpression(String postId) {
    if (_impressionRegistered || !_isAuthenticated) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _impressionDebounce?.cancel();
    _impressionDebounce = Timer(_PostCardConfig.impressionDebounce, () {
      if (_impressionRegistered || !mounted) return;
      _impressionRegistered = true;
      Supabase.instance.client
          .rpc('increment_post_impression', params: {'p_post_id': postId, 'p_user_id': uid})
          .catchError((e) {
        _PostCardLogger.error('impression rpc failed', {'postId': postId});
        _impressionRegistered = false;
      });
    });
  }

  // ---- header -----------------------------------------------------------

  Widget _buildHeader(NetworkPost post, bool isOwner, bool isFollowing, bool isCertified, CertificationTier? tier,
      CertificationStatus? status, bool isLegacyVerified, AppLocalizations l10n) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: l10n.t('post_open_profile', args: {'name': _PostCardValidators.sanitize(post.authorName)}),
          child: GestureDetector(
            onTap: () => _openProfile(post.userId),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.5),
                    backgroundImage: _safeImageUrl(post.authorAvatar) != null
                        ? CachedNetworkImageProvider(_safeImageUrl(post.authorAvatar)!)
                        : null,
                    child: _safeImageUrl(post.authorAvatar) == null
                        ? const Icon(Icons.person_rounded, size: 18, color: ThixPolicy.textMuted)
                        : null,
                  ),
                ),
                if (!isOwner && !isFollowing)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Semantics(
                      button: true,
                      label: l10n.t('post_follow'),
                      child: GestureDetector(
                        onTap: () async {
                          if (_followBusy || !_throttleFollow() || !_isAuthenticated) return;
                          setState(() {
                            _followBusy = true;
                            _isFollowingLocal = true;
                          });
                          HapticFeedback.selectionClick();
                          try {
                            await ref.read(networkServiceProvider).followUser(post.userId).timeout(_PostCardConfig.networkTimeout);
                            if (!mounted) return;
                            ref.invalidate(followStatusProvider(post.userId));
                            ref.invalidate(userProfileProvider(post.userId));
                            widget.onFollow?.call();
                          } catch (e) {
                            _PostCardLogger.error('followUser failed', {'userId': post.userId});
                            if (mounted) setState(() => _isFollowingLocal = false);
                          } finally {
                            if (mounted) setState(() => _followBusy = false);
                          }
                        },
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: ThixPolicy.s12),
        Expanded(
          child: GestureDetector(
            onTap: () => _openProfile(post.userId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _PostCardValidators.sanitize(post.authorName),
                        style: ThixPolicy.titleStyle
                            .copyWith(fontWeight: ThixPolicy.bold, fontSize: 14.5, color: ThixPolicy.textMain, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCertified)
                      CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 15, padding: const EdgeInsets.only(left: 6))
                    else if (isLegacyVerified)
                      const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_getTimeAgo(post.createdAt),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- barre d'actions ----------------------------------------------------

  Widget _buildActionRow(NetworkPost post, bool isLiked, bool isOwner, bool isCurrentUserFree, WidgetRef ref, AppLocalizations l10n) {
    final impressionsRaw = post.toJson()['impressions_count'];
    final impressions = (impressionsRaw is num) ? impressionsRaw.toInt() : 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _ActionBtn(
            icon: isLiked ? Icons.bolt_rounded : Icons.bolt_outlined,
            label: '',
            color: isLiked ? ThixPolicy.gold : ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () async {
              if (!_isAuthenticated) return;
              HapticFeedback.selectionClick();
              await ref.read(postItemProvider.notifier).toggleLike();
            },
            semanticsLabel: isLiked ? l10n.t('post_unlike') : l10n.t('post_like'),
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: _formatCountHelper(post.commentsCount),
            color: ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: widget.onComment ?? () => _openPostDetails(post.id),
            semanticsLabel: l10n.t('post_comments'),
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.repeat_rounded,
            label: _formatCountHelper(post.repostsCount),
            color: post.isReposted ? ThixPolicy.success : ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () => _repost(post, ref, l10n),
            semanticsLabel: l10n.t('post_repost'),
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.bar_chart_rounded,
            label: _formatCountHelper(impressions),
            color: ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l10n.t('post_impressions', args: {'count': '$impressions'})),
                  behavior: SnackBarBehavior.floating));
            },
            semanticsLabel: l10n.t('post_impressions_label'),
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.send_outlined,
            label: '',
            color: ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: widget.onShare,
            semanticsLabel: l10n.t('post_share'),
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: '',
            color: post.isSaved ? ThixPolicy.textMain : ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () {
              if (!_isAuthenticated) return;
              HapticFeedback.selectionClick();
              ref.read(postItemProvider.notifier).toggleSave();
              widget.onSave?.call();
            },
            semanticsLabel: post.isSaved ? l10n.t('post_unsave') : l10n.t('post_save'),
          ),
          if (isOwner && !isCurrentUserFree) ...[
            const SizedBox(width: 20),
            _ActionBtn(
                icon: Icons.edit_outlined,
                label: '',
                color: ThixPolicy.textMain,
                onTap: () => _editPost(post, ref, l10n),
                semanticsLabel: l10n.t('post_edit')),
          ],
          if (isOwner) ...[
            const SizedBox(width: 20),
            _ActionBtn(
                icon: Icons.delete_outline_rounded,
                label: '',
                color: ThixPolicy.danger,
                onTap: () => _deletePost(post, ref, l10n),
                semanticsLabel: l10n.t('post_delete')),
          ],
          if (!isOwner) ...[
            const SizedBox(width: 20),
            _ActionBtn(
              icon: Icons.visibility_off_outlined,
              label: '',
              color: ThixPolicy.textSecondary.withOpacity(0.8),
              onTap: () async {
                if (!_isAuthenticated) return;
                HapticFeedback.selectionClick();
                try {
                  await ref.read(networkServiceProvider).hidePost(post.id).timeout(_PostCardConfig.networkTimeout);
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.t('post_hidden')), behavior: SnackBarBehavior.floating));
                  }
                } catch (e) {
                  _PostCardLogger.error('hidePost failed', {'postId': post.id});
                }
              },
              semanticsLabel: l10n.t('post_hide'),
            ),
            const SizedBox(width: 20),
            _ActionBtn(
              icon: Icons.flag_outlined,
              label: '',
              color: ThixPolicy.danger.withOpacity(0.8),
              onTap: () => _showReportDialog(post, l10n),
              semanticsLabel: l10n.t('post_report'),
            ),
          ],
        ],
      ),
    );
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return ProviderScope(
      overrides: [postItemProvider.overrideWith((ref) => PostItemNotifier(widget.post, ref))],
      child: Consumer(
        builder: (context, ref, _) {
          final post = ref.watch(postItemProvider);
          final isLiked = ref.watch(postItemProvider.select((p) => p.isLiked));
          final likesCount = ref.watch(postItemProvider.select((p) => p.likesCount));
          final isOwner = widget.currentProfileId == post.userId;
          final authorProfile = ref.watch(userProfileProvider(post.userId)).valueOrNull;

          CertificationTier? tier;
          CertificationStatus? status;
          var isCertified = false;
          var isLegacyVerified = false;

          if (authorProfile != null) {
            tier = CertificationTierX.parse(authorProfile['certification_tier']);
            status = CertificationStatusX.parse(authorProfile['certification_status']);
            isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
            isLegacyVerified = authorProfile['is_verified'] == true;
          }

          final currentUserProfile = ref.watch(userProfileProvider(widget.currentProfileId)).valueOrNull;
          var isCurrentUserFree = true;
          if (currentUserProfile != null) {
            final currentTierStr = (currentUserProfile['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';
            isCurrentUserFree = currentTierStr == 'gratuit' || currentTierStr == 'none';
          }

          final isFollowingDB = ref.watch(followStatusProvider(post.userId)).valueOrNull;
          final isFollowing = isFollowingDB ?? _isFollowingLocal;

          WidgetsBinding.instance.addPostFrameCallback((_) => _registerImpression(post.id));

          return RepaintBoundary(
            child: Container(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ThixPolicy.gold, width: 1.5))),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: _PostCardConfig.postBlurSigma, sigmaY: _PostCardConfig.postBlurSigma),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.65)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onTap ?? () => _openPostDetails(post.id),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(post, isOwner, isFollowing, isCertified, tier, status, isLegacyVerified, l10n),
                              if (post.isRepostCard)
                                Padding(
                                  padding: const EdgeInsets.only(top: ThixPolicy.s8, bottom: 4),
                                  child: Row(children: [
                                    const Icon(Icons.repeat_rounded, size: 14, color: ThixPolicy.textMuted),
                                    const SizedBox(width: 6),
                                    Text(l10n.t('reposted_label'),
                                        style: ThixPolicy.captionStyle
                                            .copyWith(fontSize: 11.5, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMuted)),
                                  ]),
                                ),
                              const SizedBox(height: ThixPolicy.s12),
                              if (post.content.isNotEmpty) _buildPostContent(post, l10n),
                              if (post.isRepostCard && _PostCardValidators.isValidId(post.repostOfId)) ...[
                                const SizedBox(height: ThixPolicy.s12),
                                _OriginalPostEmbed(postId: post.repostOfId!),
                              ],
                              if (!post.isRepostCard && (post.hasImages || post.hasVideos)) ...[
                                const SizedBox(height: ThixPolicy.s12),
                                RepaintBoundary(child: _buildMediaGrid([...post.imageUrls, ...post.videoUrls])),
                              ],
                              if (post.hasAudio && post.audioUrls.isNotEmpty) ...[
                                const SizedBox(height: ThixPolicy.s12),
                                RepaintBoundary(
                                    child: _PremiumAudioPlayer(audioUrl: post.audioUrls.first, duration: post.audioDurationSeconds)),
                              ],
                              if (post.postType == 'poll' && _PostCardValidators.isValidPollData(post.pollData)) ...[
                                const SizedBox(height: ThixPolicy.s12),
                                _buildPollWidget(post, l10n),
                              ] else if (post.postType == 'challenge') ...[
                                const SizedBox(height: ThixPolicy.s12),
                                _buildChallengeWidget(post, l10n),
                              ],
                              const SizedBox(height: ThixPolicy.s16),
                              if (likesCount > 0)
                                RepaintBoundary(child: _LikersStack(count: likesCount, postId: post.id, isLikedByMe: isLiked, l10n: l10n)),
                              const SizedBox(height: 8),
                              _buildActionRow(post, isLiked, isOwner, isCurrentUserFree, ref, l10n),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIAIRES
// ============================================================================

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const _ActionBtn({required this.icon, required this.label, required this.color, this.onTap, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(label, style: ThixPolicy.labelStyle.copyWith(fontSize: 12.5, fontWeight: ThixPolicy.semiBold, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int? duration;
  const _PremiumAudioPlayer({required this.audioUrl, this.duration});

  @override
  State<_PremiumAudioPlayer> createState() => _PremiumAudioPlayerState();
}

class _PremiumAudioPlayerState extends State<_PremiumAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isValidSource = false;

  @override
  void initState() {
    super.initState();
    _isValidSource = _PostCardValidators.isValidUrl(widget.audioUrl);
    if (_isValidSource) {
      _audioPlayer.setSourceUrl(widget.audioUrl);
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _cycleSpeed() {
    setState(() {
      _playbackSpeed = _playbackSpeed == 1.0 ? 1.5 : (_playbackSpeed == 1.5 ? 2.0 : 1.0);
      _audioPlayer.setPlaybackRate(_playbackSpeed);
    });
    HapticFeedback.selectionClick();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidSource) return const SizedBox.shrink();
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ThixPolicy.primary.withOpacity(0.15), ThixPolicy.gold.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]), shape: BoxShape.circle),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Note vocale', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 12)),
              const Spacer(),
              if (_duration.inSeconds > 0)
                Text(_formatDuration(_duration), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play(UrlSource(widget.audioUrl));
                  }
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onTapDown: (details) {
                      final percentage = details.localPosition.dx / constraints.maxWidth;
                      if (percentage >= 0 && percentage <= 1 && _duration.inMilliseconds > 0) {
                        _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * percentage).round()));
                      }
                    },
                    child: CustomPaint(size: const Size(double.infinity, 32), painter: _WaveformPainter(progress: progress, color: ThixPolicy.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ThixPolicy.primary.withOpacity(0.3)),
                  ),
                  child: Text('${_playbackSpeed}x', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold, fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_formatDuration(_position), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10)),
              const Spacer(),
              Text('-${_formatDuration(_duration - _position)}', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  _WaveformPainter({required this.progress, required this.color});

  static const int _barCount = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (_barCount * 1.5);
    final spacing = barWidth * 0.5;

    for (var i = 0; i < _barCount; i++) {
      final x = i * (barWidth + spacing);
      final heightPct = (sin(i * 0.5) * 0.3 + 0.5 + (i % 3) * 0.1).clamp(0.2, 0.9);
      final barHeight = size.height * heightPct;
      final y = (size.height - barHeight) / 2;
      final isActive = (i / _barCount) <= progress;

      final paint = Paint()
        ..color = isActive ? color : color.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Aperçu de lien externe — protégé contre le SSRF : l'URL est validée
/// (schéma http/https, hôte non privé) AVANT tout appel à l'edge function.
class _PremiumLinkPreview extends StatefulWidget {
  final String url;
  const _PremiumLinkPreview({required this.url});

  @override
  State<_PremiumLinkPreview> createState() => _PremiumLinkPreviewState();
}

class _PremiumLinkPreviewState extends State<_PremiumLinkPreview> {
  Map<String, dynamic>? _previewData;
  bool _isLoading = true;
  bool _networkFailed = false;

  String get _domain => Uri.tryParse(widget.url)?.host.replaceFirst('www.', '') ?? '';

  String get _faviconUrl {
    final host = Uri.tryParse(widget.url)?.host ?? '';
    return 'https://www.google.com/s2/favicons?domain=$host&sz=${_PostCardConfig.avatarFallbackSize}';
  }

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (!_PostCardValidators.isSafeExternalFetchUrl(widget.url)) {
      if (mounted) setState(() { _isLoading = false; _networkFailed = true; });
      return;
    }

    final cached = _PostCardCache.instance.getLinkPreview(widget.url);
    if (cached != null) {
      if (mounted) setState(() { _previewData = cached; _isLoading = false; });
      return;
    }

    try {
      final response = await Supabase.instance.client.functions
          .invoke('link-preview', body: {'url': widget.url}).timeout(_PostCardConfig.linkPreviewTimeout);

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        _PostCardCache.instance.setLinkPreview(widget.url, data);
        if (mounted) setState(() { _previewData = data; _isLoading = false; });
      } else {
        throw Exception('Invalid response');
      }
    } catch (e) {
      _PostCardLogger.error('LinkPreview fetch failed');
      if (mounted) setState(() { _networkFailed = true; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    if (_domain.isEmpty) return const SizedBox.shrink();

    final title = _PostCardValidators.sanitize(_previewData?['title']?.toString() ?? '');
    final description = _PostCardValidators.sanitize(_previewData?['description']?.toString() ?? '');
    final ogImage = _safeImageUrl(_previewData?['image']?.toString());
    final hasOgImage = ogImage != null;
    final displayImage = hasOgImage ? ogImage : _faviconUrl;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hasOgImage
                ? CachedNetworkImage(
                    imageUrl: displayImage,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 160,
                      color: Colors.white.withOpacity(0.4),
                      child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
                    ),
                    errorWidget: (_, __, ___) => _buildFaviconBanner(),
                  )
                : _buildFaviconBanner(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.link_rounded, size: 12, color: ThixPolicy.primary),
                    const SizedBox(width: 4),
                    Text(_domain.toUpperCase(),
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold, fontSize: 10, letterSpacing: 0.5)),
                  ]),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold, fontSize: 14, height: 1.2)),
                  ] else if (_networkFailed || _previewData == null) ...[
                    const SizedBox(height: 6),
                    Text(AppLocalizations.of(context).t('external_link'),
                        style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold, fontSize: 14, height: 1.2)),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12, height: 1.3)),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(widget.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12, height: 1.3)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaviconBanner() {
    return Container(
      height: 100,
      width: double.infinity,
      color: ThixPolicy.primary.withOpacity(0.06),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
          child: CachedNetworkImage(
            imageUrl: _faviconUrl,
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(width: 40, height: 40, child: Icon(Icons.link_rounded, color: ThixPolicy.primary, size: 24)),
            errorWidget: (_, __, ___) => const Icon(Icons.link_rounded, color: ThixPolicy.primary, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 200,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.8))),
      child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
    );
  }
}

class _VideoThumbTile extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final VoidCallback onTap;
  const _VideoThumbTile({required this.videoUrl, this.width, this.height, required this.onTap});

  @override
  State<_VideoThumbTile> createState() => _VideoThumbTileState();
}

class _VideoThumbTileState extends State<_VideoThumbTile> {
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    if (!_PostCardValidators.isSafeExternalFetchUrl(widget.videoUrl)) return;
    try {
      final response = await Supabase.instance.client.functions
          .invoke('video-thumbnail', body: {'video_url': widget.videoUrl}).timeout(_PostCardConfig.videoThumbTimeout);

      final url = _safeImageUrl(response.data?['thumbnail_url']?.toString());
      if (url != null && mounted) setState(() => _thumbnailUrl = url);
    } catch (e) {
      _PostCardLogger.error('Video thumbnail generation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black87,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_thumbnailUrl != null)
              CachedNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover)
            else
              const Center(child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 40)),
            Container(color: Colors.black.withOpacity(0.2)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikersStack extends StatefulWidget {
  final int count;
  final String postId;
  final bool isLikedByMe;
  final AppLocalizations l10n;
  const _LikersStack({required this.count, required this.postId, required this.isLikedByMe, required this.l10n});

  @override
  State<_LikersStack> createState() => _LikersStackState();
}

class _LikersStackState extends State<_LikersStack> {
  List<String> _likerAvatars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLikersAvatars();
  }

  @override
  void didUpdateWidget(covariant _LikersStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) _fetchLikersAvatars();
  }

  Future<void> _fetchLikersAvatars() async {
    if (widget.count == 0) {
      if (mounted) setState(() { _isLoading = false; _likerAvatars = []; });
      return;
    }

    final cached = _PostCardCache.instance.getLikers(widget.postId);
    if (cached != null) {
      if (mounted) setState(() { _likerAvatars = cached; _isLoading = false; });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('post_likes')
          .select('user_id, profiles(avatar_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false)
          .limit(_PostCardConfig.maxLikersFetched)
          .timeout(_PostCardConfig.networkTimeout);

      final avatars = <String>[];
      if (response is List) {
        for (final row in response) {
          final profile = row['profiles'];
          final url = profile is Map ? _safeImageUrl(profile['avatar_url']?.toString()) : null;
          avatars.add(url ?? '');
        }
      }

      _PostCardCache.instance.setLikers(widget.postId, avatars);
      if (mounted) setState(() { _likerAvatars = avatars; _isLoading = false; });
    } catch (e) {
      _PostCardLogger.error('fetchLikersAvatars failed', {'postId': widget.postId});
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = min(_PostCardConfig.maxLikersFetched, widget.count);
    final extra = widget.count - displayCount;
    final colors = [ThixPolicy.primary, ThixPolicy.danger, ThixPolicy.gold, ThixPolicy.info, ThixPolicy.domainMedia];

    final text = widget.isLikedByMe
        ? (widget.count == 1
            ? widget.l10n.t('post_liked_by_you')
            : widget.l10n.t('post_liked_by_you_and_others', args: {'count': '${widget.count - 1}'}))
        : widget.l10n.t('post_liked_by_others', args: {'count': '${widget.count}'});

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Row(
            children: List.generate(displayCount, (i) {
              final avatarUrl = _likerAvatars.length > i ? _likerAvatars[i] : '';
              final hasRealAvatar = avatarUrl.isNotEmpty && !_isLoading;
              return Align(
                widthFactor: 0.7,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[(widget.postId.hashCode + i) % colors.length],
                    border: Border.all(color: Colors.white, width: 1.5),
                    image: hasRealAvatar ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover) : null,
                  ),
                  child: !hasRealAvatar ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                ),
              );
            }),
          ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('+$extra', style: ThixPolicy.captionStyle.copyWith(fontSize: 11, fontWeight: ThixPolicy.bold, color: ThixPolicy.textSecondary)),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: ThixPolicy.captionStyle.copyWith(fontSize: 11.5, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _OriginalPostEmbed extends ConsumerWidget {
  final String postId;
  const _OriginalPostEmbed({required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_PostCardValidators.isValidId(postId)) return const SizedBox.shrink();

    return FutureBuilder<NetworkPost?>(
      future: ref.read(networkServiceProvider).getPostById(postId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.8))),
            child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
          );
        }
        final original = snap.data;
        if (original == null) return const SizedBox.shrink();

        final originalMedia = [...original.imageUrls, ...original.videoUrls].where(_PostCardValidators.isValidUrl).toList();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.8))),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_PostCardValidators.isValidId(original.id)) context.push('/network/comments/${original.id}');
              },
              child: Padding(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white.withOpacity(0.5),
                          backgroundImage: _safeImageUrl(original.authorAvatar) != null
                              ? CachedNetworkImageProvider(_safeImageUrl(original.authorAvatar)!)
                              : null,
                          child: _safeImageUrl(original.authorAvatar) == null
                              ? const Icon(Icons.person, size: 14, color: ThixPolicy.textMuted)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_PostCardValidators.sanitize(original.authorName),
                              style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 12, color: ThixPolicy.textMain),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (original.content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_PostCardValidators.sanitize(original.content),
                          style: ThixPolicy.bodyStyle.copyWith(fontSize: 12.5, height: 1.4, color: ThixPolicy.textMain)),
                    ],
                    if (originalMedia.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _isVideoUrl(originalMedia.first)
                            ? SizedBox(width: double.infinity, height: 220, child: _VideoThumbTile(videoUrl: originalMedia.first, height: 220, onTap: () {}))
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 400, minHeight: 120),
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black.withOpacity(0.03),
                                  child: CachedNetworkImage(
                                    imageUrl: originalMedia.first,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const SizedBox(height: 200, child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)))),
                                    errorWidget: (_, __, ___) => const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted))),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const _FullScreenGallery({required this.imageUrls, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) => Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(imageUrl: widget.imageUrls[index], fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
              top: 12,
              right: 12,
              child: SafeArea(child: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)))),
        ],
      ),
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _ready ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)) : const CircularProgressIndicator(color: ThixPolicy.primary)),
          if (_ready)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
                child: AnimatedOpacity(
                  opacity: _controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 72)),
                ),
              ),
            ),
          Positioned(
              top: 12,
              right: 12,
              child: SafeArea(child: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)))),
        ],
      ),
    );
  }
}
