// lib/presentation/network/widgets/post_card_parts.dart
//
// Parties communes de PostCard : config, validateurs, cache, notifier,
// galerie, lecteur vidéo, badges, audio, aperçu de lien, miniature vidéo,
// likers, boutons, sélecteur de réactions.
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/services/media_saver.dart';

// ============================================================================
// PALETTE + CONFIG
// ============================================================================
class PcMono {
  PcMono._();
  static const Color accent = Color(0xFF3F3F46);
  static const Color accentDeep = Color(0xFF18181B);
  static const Color accentSoft = Color(0xFF71717A);
}

class PcConfig {
  PcConfig._();
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
  static const double dialogBlurSigma = 10;
  static const int maxLikersFetched = 5;
  static const int avatarFallbackSize = 256;
  static const double cardBottomBorderWidth = 1.2;
  static const double cardFirstTopBorderWidth = 2.0;
  static const int maxVideoFrameFallbacks = 3;
  static const String permalinkBase = 'https://thix.id/network/post/';

  // ✅ Ratios FIXES des médias → la carte ne change plus de hauteur au chargement
  static const double singleMediaRatio = 1.0; // 1 photo
  static const double videoRatio = 16 / 9; // 1 vidéo
  static const double twoMediaRatio = 1.6; // 2 médias
  static const double multiMediaRatio = 1.4; // 3 médias ou plus

  static const Set<String> knownRedirectDomains = {
    'facebook.com', 'fb.me', 'l.facebook.com', 'share.google', 'goo.gl', 'g.co',
  };
}

class PcLog {
  static const _tag = 'PostCard';
  static void info(String m, [Map<String, Object?>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, Object?>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, Object?>? d]) => _log('ERROR', m, d);
  static void _log(String level, String m, Map<String, Object?>? d) {
    if (!kDebugMode && level == 'INFO') return;
    final s = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag][$level] $m$s');
  }
}

// ============================================================================
// VALIDATEURS
// ============================================================================
class PcValidators {
  PcValidators._();
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _privateHost = RegExp(
    r'^(localhost|127\.|0\.|10\.|192\.168\.|169\.254\.|::1$|fc00:|fd00:)',
    caseSensitive: false,
  );

  static String sanitize(String? input, {int maxLength = PcConfig.maxSanitizedLength, bool multiline = true}) {
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

  static String sanitizeLine(String? input, {int maxLength = 200}) =>
      sanitize(input, maxLength: maxLength, multiline: false);

  static bool isValidId(String? id) => id != null && _uuid.hasMatch(id);

  static bool isValidUrl(String url) {
    if (url.length > 2048) return false;
    try {
      final u = Uri.parse(url);
      return (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty && !u.host.contains('..');
    } catch (_) {
      return false;
    }
  }

  static bool isSafeExternalFetchUrl(String url) {
    if (!isValidUrl(url)) return false;
    return !_privateHost.hasMatch(Uri.tryParse(url)?.host ?? '');
  }

  static bool isValidRichTextUrl(String url) => isValidUrl(url) && !url.toLowerCase().contains('javascript:');

  static bool isValidPollData(Map<String, dynamic>? p) {
    if (p == null) return false;
    final o = p['options'];
    if (o is! List || o.isEmpty) return false;
    return o.every((x) => x is Map && x.containsKey('text') && x.containsKey('votes'));
  }

  static bool isKnownRedirectDomain(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase().replaceFirst('www.', '') ?? '';
    return PcConfig.knownRedirectDomains.any((d) => host == d || host.endsWith('.$d'));
  }
}

// ============================================================================
// HELPERS
// ============================================================================
/// Groupes : 1-2 couleur · 3 gras · 4 italique · 5 @mention · 6 #tag · 7 lien
final RegExp kRichContentRegex = RegExp(
  r'\{c:(#[0-9A-Fa-f]{6,8})\}([\s\S]*?)\{c\}|'
  r'\*\*([\s\S]+?)\*\*|'
  r'\*([\s\S]+?)\*|'
  r'(?<![\w@])@([\p{L}\p{N}_]{1,32})|'
  r'(?<![\w#&])#([\p{L}\p{N}_]{1,64})|'
  r'((?:https?:\/\/|www\.)[^\s]+)',
  unicode: true,
);
final RegExp kUrlFinder = RegExp(r'((?:https?:\/\/|www\.)[^\s]+)');
final RegExp kUrlTrailingPunct = RegExp(r'[.,;:!?)\]]+$');

String pcNormalizeUrl(String url) => url.toLowerCase().startsWith('www.') ? 'https://$url' : url;

String pcPlainText(String content) {
  var s = content.replaceAll(RegExp(r'\{c:#[0-9A-Fa-f]{6,8}\}'), '').replaceAll('{c}', '');
  s = s.replaceAllMapped(RegExp(r'\*\*([\s\S]+?)\*\*'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'\*([\s\S]+?)\*'), (m) => m.group(1) ?? '');
  return s.trim();
}

/// ✅ Affiche toujours le nombre (0 inclus)
String pcCount(int count) {
  if (count <= 0) return '0';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

bool pcIsVideoUrl(String url) {
  try {
    final path = Uri.parse(url).path.toLowerCase();
    const ext = ['.mp4', '.mov', '.m4v', '.webm', '.avi', '.mkv'];
    return ext.any(path.endsWith) || path.contains('/videos/') || path.contains('/video/');
  } catch (_) {
    return false;
  }
}

String? pcSafeImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  return PcValidators.isValidUrl(url) ? url : null;
}

bool pcIsGhostRepost(NetworkPost post) => post.isRepostCard && post.content.trim().toLowerCase() == 'true';

String pcPostLink(String postId) => '${PcConfig.permalinkBase}$postId';

String pcFullDate(DateTime dt) {
  final d = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

String pcTr(AppLocalizations l10n, String key, String fallback) {
  final v = l10n.t(key);
  return (v.isEmpty || v == key) ? fallback : v;
}

bool _timeagoReady = false;

/// ✅ "il y a 18 jours" (fr) au lieu de "18 days ago"
String pcTimeAgo(BuildContext context, DateTime dt) {
  if (!_timeagoReady) {
    _timeagoReady = true;
    timeago.setLocaleMessages('fr', timeago.FrMessages());
  }
  final code = Localizations.localeOf(context).languageCode;
  return timeago.format(dt.toLocal(), locale: code == 'fr' ? 'fr' : 'en');
}

/// ✅ Largeur de décodage = largeur écran × densité (qualité nette)
int pcCacheWidth(BuildContext context, {double fraction = 1}) {
  final w = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context) * fraction;
  return w.clamp(300, 1600).round();
}

void pcToast(BuildContext context, String message, {Color? bg, int seconds = 2}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: seconds),
    ));
}

Future<void> pcCopy(BuildContext context, String text, String message) async {
  HapticFeedback.selectionClick();
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) pcToast(context, message, seconds: 1);
}

Future<void> pcDownloadMedia(BuildContext context, String url) async {
  if (!PcValidators.isValidUrl(url)) return;
  HapticFeedback.selectionClick();
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final isVideo = pcIsVideoUrl(url);
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
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, value: v > 0 ? v : null, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${pcTr(l10n, 'post_downloading', 'Téléchargement…')}${v > 0 ? ' ${(v * 100).round()}%' : ''}'),
          ),
        ]),
      ),
    ));
  final result = await MediaSaver.save(url, isVideo: isVideo, onProgress: (v) => progress.value = v);
  messenger.hideCurrentSnackBar();
  progress.dispose();
  final ok = result == MediaSaveResult.saved;
  final msg = switch (result) {
    MediaSaveResult.saved => pcTr(l10n, 'post_download_saved', 'Enregistré dans votre galerie'),
    MediaSaveResult.denied => pcTr(l10n, 'post_download_denied', 'Autorisez l’accès aux photos dans les réglages'),
    _ => pcTr(l10n, 'post_download_failed', 'Impossible de télécharger'),
  };
  messenger.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: ok ? ThixPolicy.success : ThixPolicy.danger,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ));
}

// ============================================================================
// CACHE
// ============================================================================
class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  _CacheEntry(this.value) : timestamp = DateTime.now();
}

class PcCache {
  PcCache._();
  static final PcCache instance = PcCache._();

  final LinkedHashMap<String, _CacheEntry<List<String>>> _likers = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<Map<String, dynamic>>> _linkPreviews = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<String>> _videoThumbs = LinkedHashMap();
  final Map<String, bool> optimisticLikes = {};
  final Map<String, int> optimisticLikeCounts = {};
  final Map<String, bool> optimisticSaves = {};
  final Map<String, bool> optimisticReposts = {};
  final Map<String, int> optimisticRepostCounts = {};

  /// postId → code de réaction (like, love, haha, wow, fire)
  final Map<String, String> myReactions = {};

  List<String>? getLikers(String id) => _get(_likers, id);
  void setLikers(String id, List<String> v) => _set(_likers, id, v);
  Map<String, dynamic>? getLinkPreview(String url) => _get(_linkPreviews, url);
  void setLinkPreview(String url, Map<String, dynamic> d) => _set(_linkPreviews, url, d);
  String? getVideoThumb(String url) => _get(_videoThumbs, url);
  void setVideoThumb(String url, String t) => _set(_videoThumbs, url, t);

  T? _get<T>(LinkedHashMap<String, _CacheEntry<T>> map, String key) {
    final e = map[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.timestamp) > PcConfig.cacheTtl) {
      map.remove(key);
      return null;
    }
    map.remove(key);
    map[key] = e;
    return e.value;
  }

  void _set<T>(LinkedHashMap<String, _CacheEntry<T>> map, String key, T value) {
    if (map.length >= PcConfig.cacheMaxSize) map.remove(map.keys.first);
    map[key] = _CacheEntry(value);
  }
}

// ============================================================================
// RÉACTIONS (appui long sur ⚡)
// ============================================================================
const List<MapEntry<String, String>> pcReactions = [
  MapEntry('like', '👍'),
  MapEntry('love', '❤️'),
  MapEntry('haha', '😂'),
  MapEntry('wow', '😮'),
  MapEntry('fire', '🔥'),
];

String? pcReactionEmoji(String? code) {
  if (code == null) return null;
  for (final r in pcReactions) {
    if (r.key == code) return r.value;
  }
  return null;
}

class PcReactionPicker {
  PcReactionPicker._();

  static Future<String?> show(BuildContext context, Rect anchor) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'reactions',
      barrierColor: Colors.black12,
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (ctx, _, __) {
  final size = MediaQuery.sizeOf(ctx);
  final w = pcReactions.length * 52.0 + 16;
  final double left = anchor.left
      .clamp(8.0, max(8.0, size.width - w - 8))
      .toDouble();
  final double top = max(anchor.top - 66, 48.0).toDouble();
  return Stack(children: [
    Positioned(left: left, top: top, child: const _ReactionPill()),
  ]);
},
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          alignment: Alignment.bottomLeft,
          child: child,
        ),
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in pcReactions)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(r.key);
                },
                child: SizedBox(
                  width: 52,
                  height: 48,
                  child: Center(child: Text(r.value, style: const TextStyle(fontSize: 30))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// POST ORIGINAL D'UN REPOST
// ============================================================================
final _originalPostProvider = FutureProvider.autoDispose.family<NetworkPost?, String>((ref, postId) async {
  ref.keepAlive();
  try {
    return await ref.read(networkServiceProvider).getPostById(postId).timeout(PcConfig.networkTimeout);
  } catch (e) {
    PcLog.warn('original post load failed', {'postId': postId, 'error': '$e'});
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
    final c = PcCache.instance;
    final hasOptimisticLike = c.optimisticLikes.containsKey(post.id);
    if (hasOptimisticLike) {
      newIsLiked = c.optimisticLikes[post.id]!;
      newLikesCount = c.optimisticLikeCounts[post.id] ?? state.likesCount;
      changed = true;
    }
    if (c.optimisticSaves.containsKey(post.id)) {
      newIsSaved = c.optimisticSaves[post.id]!;
      changed = true;
    }
    if (c.optimisticReposts.containsKey(post.id)) {
      newIsReposted = c.optimisticReposts[post.id]!;
      newRepostsCount = c.optimisticRepostCounts[post.id] ?? state.repostsCount;
      changed = true;
    }
    if (changed) {
      state = state.copyWith(
        isLiked: newIsLiked,
        likesCount: newLikesCount,
        isSaved: newIsSaved,
        isReposted: newIsReposted,
        repostsCount: newRepostsCount,
      );
    }
    if (!hasOptimisticLike && _isAuthenticated) _verifyLikeStatusFromServer(post.id);
  }

  final Ref ref;
  bool _likeBusy = false;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  bool get _isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  Future<void> _verifyLikeStatusFromServer(String postId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(PcConfig.likeVerifyTimeout);
      final reallyLiked = res != null;
      if (_isDisposed) return;
      if (reallyLiked != state.isLiked) state = state.copyWith(isLiked: reallyLiked);
      PcCache.instance.optimisticLikes[postId] = reallyLiked;
      PcCache.instance.optimisticLikeCounts[postId] = state.likesCount;

      // Réaction enregistrée (non bloquant : la table peut ne pas exister)
      if (reallyLiked && !PcCache.instance.myReactions.containsKey(postId)) {
        try {
          final r = await Supabase.instance.client
              .from('post_reactions')
              .select('reaction')
              .eq('post_id', postId)
              .eq('user_id', uid)
              .maybeSingle()
              .timeout(PcConfig.likeVerifyTimeout);
          final code = r?['reaction']?.toString();
          if (code != null && pcReactionEmoji(code) != null && !_isDisposed) {
            PcCache.instance.myReactions[postId] = code;
            state = state.copyWith(isLiked: true);
          }
        } catch (_) {}
      }
    } catch (e) {
      PcLog.warn('verifyLikeStatus failed', {'postId': postId, 'error': '$e'});
    }
  }

  Future<void> toggleLike() async {
    if (_likeBusy || !_isAuthenticated || _isDisposed) return;
    _likeBusy = true;
    final wasLiked = state.isLiked;
    final oldCount = state.likesCount;
    final newLiked = !wasLiked;
    final newCount = wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1;
    state = state.copyWith(isLiked: newLiked, likesCount: newCount);
    PcCache.instance.optimisticLikes[state.id] = newLiked;
    PcCache.instance.optimisticLikeCounts[state.id] = newCount;
    if (wasLiked) {
      PcCache.instance.myReactions.remove(state.id);
      _deleteReaction(state.id);
    }
    try {
      final service = ref.read(networkServiceProvider);
      try {
        final result = await service.togglePostLike(state.id).timeout(PcConfig.networkTimeout);
        if (_isDisposed) return;
        state = state.copyWith(isLiked: result.liked, likesCount: result.likesCount);
        PcCache.instance.optimisticLikes[state.id] = result.liked;
        PcCache.instance.optimisticLikeCounts[state.id] = result.likesCount;
      } catch (_) {
        if (_isDisposed) return;
        if (wasLiked) {
          await service.unlikePost(state.id).timeout(PcConfig.networkTimeout);
        } else {
          await service.likePost(state.id).timeout(PcConfig.networkTimeout);
        }
      }
    } catch (e) {
      PcLog.error('toggleLike failed', {'postId': state.id});
      if (!_isDisposed) {
        state = state.copyWith(isLiked: wasLiked, likesCount: oldCount);
        PcCache.instance.optimisticLikes[state.id] = wasLiked;
        PcCache.instance.optimisticLikeCounts[state.id] = oldCount;
      }
    } finally {
      if (!_isDisposed) _likeBusy = false;
    }
  }

  /// ✅ Réaction (👍 ❤️ 😂 😮 🔥) : like le post si besoin + enregistre la réaction
  Future<void> react(String code) async {
    if (!_isAuthenticated || _isDisposed || pcReactionEmoji(code) == null) return;
    final id = state.id;
    PcCache.instance.myReactions[id] = code;
    if (!state.isLiked) await toggleLike();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('post_reactions')
          .upsert({'post_id': id, 'user_id': uid, 'reaction': code}, onConflict: 'post_id,user_id')
          .timeout(PcConfig.networkTimeout);
    } catch (e) {
      PcLog.warn('react save failed (table post_reactions ?)', {'error': '$e'});
    }
  }

  Future<void> _deleteReaction(String postId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('post_reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid)
          .timeout(PcConfig.networkTimeout);
    } catch (_) {}
  }

  Future<void> toggleSave() async {
    if (!_isAuthenticated || _isDisposed) return;
    final was = state.isSaved;
    final newSaved = !was;
    state = state.copyWith(isSaved: newSaved);
    PcCache.instance.optimisticSaves[state.id] = newSaved;
    try {
      final service = ref.read(networkServiceProvider);
      if (was) {
        await service.unsavePost(state.id).timeout(PcConfig.networkTimeout);
      } else {
        await service.savePost(state.id).timeout(PcConfig.networkTimeout);
      }
    } catch (e) {
      PcLog.error('toggleSave failed', {'postId': state.id});
      if (!_isDisposed) {
        state = state.copyWith(isSaved: was);
        PcCache.instance.optimisticSaves[state.id] = was;
      }
    }
  }

  void updateContent(String content) {
    if (!_isDisposed) state = state.copyWith(content: PcValidators.sanitize(content));
  }

  void incrementRepost() {
    if (!_isDisposed) {
      final n = state.repostsCount + 1;
      state = state.copyWith(repostsCount: n, isReposted: true);
      PcCache.instance.optimisticReposts[state.id] = true;
      PcCache.instance.optimisticRepostCounts[state.id] = n;
    }
  }
}

// ============================================================================
// POST ORIGINAL (embed d'un repost)
// ============================================================================
class PcOriginalPostEmbed extends ConsumerWidget {
  final String postId;
  const PcOriginalPostEmbed({super.key, required this.postId});

  BoxDecoration get _box => BoxDecoration(
        color: PcMono.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PcMono.accent.withValues(alpha: 0.15)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_originalPostProvider(postId));
    return async.when(
      loading: () => Container(
        height: 90,
        decoration: _box,
        child: const Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: PcMono.accent)),
        ),
      ),
      error: (_, __) => _unavailable(context),
      data: (o) => o == null ? _unavailable(context) : _card(context, o),
    );
  }

  Widget _unavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _box,
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: ThixPolicy.textSecondary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            pcTr(l10n, 'post_original_unavailable', "Ce post n'est plus disponible"),
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
          ),
        ),
      ]),
    );
  }

  Widget _card(BuildContext context, NetworkPost original) {
    final l10n = AppLocalizations.of(context);
    final name = PcValidators.sanitizeLine(original.authorName, maxLength: 100);
    final avatar = pcSafeImageUrl(original.authorAvatar);
    final content = PcValidators.sanitize(pcPlainText(original.content), maxLength: 600);
    final media = <String>[
      ...original.imageUrls.where(PcValidators.isValidUrl),
      ...original.videoUrls.where(PcValidators.isValidUrl),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!PcValidators.isValidId(original.id)) return;
        HapticFeedback.selectionClick();
        context.push('/network/comments/${original.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _box,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              GestureDetector(
                onTap: () {
                  if (!PcValidators.isValidId(original.userId)) return;
                  HapticFeedback.selectionClick();
                  context.push('/network/profile/${original.userId}');
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ThixPolicy.surfaceSoft,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                  ),
                  child: ClipOval(
                    child: avatar != null
                        ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                        : const Icon(Icons.person_rounded, size: 15, color: ThixPolicy.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    name.isEmpty ? pcTr(l10n, 'post_user_fallback', 'Utilisateur') : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.titleStyle.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: ThixPolicy.textMain),
                  ),
                  Text(
                    pcTimeAgo(context, original.createdAt),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 10.5, color: ThixPolicy.textSecondary),
                  ),
                ]),
              ),
            ]),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, height: 1.4, color: ThixPolicy.textMain),
              ),
            ],
            if (media.isNotEmpty) ...[
              const SizedBox(height: 10),
              _media(context, media),
            ],
          ],
        ),
      ),
    );
  }

  Widget _media(BuildContext context, List<String> urls) {
    final first = urls.first;
    final imageOnly = urls.where((u) => !pcIsVideoUrl(u)).toList();
    final extra = urls.length - 1;
    Widget tile;
    if (pcIsVideoUrl(first)) {
      tile = PcVideoThumbTile(
        videoUrl: first,
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PcFullScreenVideoPlayer(videoUrl: first)));
        },
      );
    } else {
      tile = GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PcFullScreenGallery(
              imageUrls: imageOnly,
              initialIndex: imageOnly.indexOf(first).clamp(0, imageOnly.length - 1),
            ),
          ));
        },
        child: CachedNetworkImage(
          imageUrl: first,
          fit: BoxFit.cover,
          memCacheWidth: pcCacheWidth(context),
          filterQuality: FilterQuality.high,
          placeholder: (_, __) => Container(color: Colors.white.withValues(alpha: 0.5)),
          errorWidget: (_, __, ___) => Container(
            color: Colors.white.withValues(alpha: 0.5),
            child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          tile,
          if (extra > 0)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
                child: Text('+$extra',
                    style: ThixPolicy.captionStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ============================================================================
// BOUTON ROND SUR LES MÉDIAS
// ============================================================================
class PcMediaChipButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;
  const PcMediaChipButton({super.key, required this.icon, required this.onTap, required this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

// ============================================================================
// GALERIE PLEIN ÉCRAN — qualité ORIGINALE (aucune réduction)
// ============================================================================
class PcFullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const PcFullScreenGallery({super.key, required this.imageUrls, required this.initialIndex});

  @override
  State<PcFullScreenGallery> createState() => _PcFullScreenGalleryState();
}

class _PcFullScreenGalleryState extends State<PcFullScreenGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.imageUrls.isEmpty ? 0 : widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = widget.imageUrls.length;
    final current = total == 0 ? null : widget.imageUrls[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: total > 1 ? Text('${_index + 1} / $total', style: const TextStyle(color: Colors.white, fontSize: 14)) : null,
        actions: [
          if (current != null) ...[
            IconButton(
              tooltip: pcTr(l10n, 'post_copy_link', 'Copier le lien'),
              icon: const Icon(Icons.link_rounded),
              onPressed: () => pcCopy(context, current, pcTr(l10n, 'post_link_copied', 'Lien copié')),
            ),
            IconButton(
              tooltip: pcTr(l10n, 'post_download_photo', 'Télécharger la photo'),
              icon: const Icon(Icons.download_rounded),
              onPressed: () => pcDownloadMedia(context, current),
            ),
          ],
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrls[index],
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LECTEUR VIDÉO PLEIN ÉCRAN
// ============================================================================
class PcFullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const PcFullScreenVideoPlayer({super.key, required this.videoUrl});

  @override
  State<PcFullScreenVideoPlayer> createState() => _PcFullScreenVideoPlayerState();
}

class _PcFullScreenVideoPlayerState extends State<PcFullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null || !PcValidators.isValidUrl(widget.videoUrl)) {
      setState(() => _hasError = true);
      return;
    }
    final c = VideoPlayerController.networkUrl(uri, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
    _controller = c;
    try {
      await c.initialize();
      if (!mounted) return;
      await c.setLooping(false);
      await c.play();
      if (!mounted) return;
      setState(() => _initialized = true);
      _scheduleHide();
    } catch (e) {
      PcLog.error('video init failed', {'error': '$e'});
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !_initialized) return;
    HapticFeedback.selectionClick();
    final v = c.value;
    final ended = v.duration > Duration.zero && v.position >= v.duration;
    if (v.isPlaying) {
      await c.pause();
      _hideTimer?.cancel();
    } else {
      if (ended) await c.seekTo(Duration.zero);
      await c.play();
      _scheduleHide();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: pcTr(l10n, 'post_download_video', 'Télécharger la vidéo'),
            icon: const Icon(Icons.download_rounded),
            onPressed: () => pcDownloadMedia(context, widget.videoUrl),
          ),
        ],
      ),
      body: _body(l10n),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Text(pcTr(l10n, 'post_video_error', 'Impossible de lire cette vidéo'),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
      );
    }
    final c = _controller;
    if (!_initialized || c == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(fit: StackFit.expand, children: [
        Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (context, value, _) {
            final ended = value.duration > Duration.zero && value.position >= value.duration;
            final showCenter = _showControls || !value.isPlaying;
            return Stack(fit: StackFit.expand, children: [
              if (value.isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (showCenter && !value.isBuffering)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                      child: Icon(
                        ended ? Icons.replay_rounded : (value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              if (_showControls)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    top: false,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        colors: VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Row(children: [
                        Text(_fmt(value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const Spacer(),
                        Text(_fmt(value.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

// ============================================================================
// BADGES PREMIUM
// ============================================================================
class PcBadgeStyle {
  final Color color;
  final IconData icon;
  final bool pulse;
  const PcBadgeStyle(this.color, this.icon, {this.pulse = false});
}

class PcStaticBadgeChip extends StatelessWidget {
  final PcBadgeStyle style;
  final String label;
  const PcStaticBadgeChip({super.key, required this.style, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.6),
        boxShadow: [BoxShadow(color: style.color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(style.icon, size: 15, color: Colors.white),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.9, height: 1)),
      ]),
    );
  }
}

class PcPulsingBadge extends StatefulWidget {
  final PcBadgeStyle style;
  final String label;
  const PcPulsingBadge({super.key, required this.style, required this.label});

  @override
  State<PcPulsingBadge> createState() => _PcPulsingBadgeState();
}

class _PcPulsingBadgeState extends State<PcPulsingBadge> with SingleTickerProviderStateMixin {
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: widget.style.color,
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.8),
          boxShadow: [
            BoxShadow(color: widget.style.color.withValues(alpha: _glow.value), blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 2)),
          ],
        ),
        child: Transform.scale(
          scale: _scale.value,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.style.icon, size: 15, color: Colors.white),
            const SizedBox(width: 7),
            Text(widget.label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.9, height: 1)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// BOUTON D'ACTION (tap + appui long + emoji de réaction)
// ============================================================================
class PcActionBtn extends StatelessWidget {
  const PcActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.iconWidget,
    this.semanticsLabel,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? iconWidget;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            iconWidget ?? Icon(icon, size: 22, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: ThixPolicy.labelStyle.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// AUDIO
// ============================================================================
class PcAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int? duration;
  const PcAudioPlayer({super.key, required this.audioUrl, this.duration});

  @override
  State<PcAudioPlayer> createState() => _PcAudioPlayerState();
}

class _PcAudioPlayerState extends State<PcAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;
  bool _valid = false;
  StreamSubscription<PlayerState>? _s1;
  StreamSubscription<Duration>? _s2;
  StreamSubscription<Duration>? _s3;

  @override
  void initState() {
    super.initState();
    _valid = PcValidators.isValidUrl(widget.audioUrl);
    if (_valid) {
      _player.setSourceUrl(widget.audioUrl);
      _s1 = _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
      });
      _s2 = _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _s3 = _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
    }
  }

  @override
  void dispose() {
    _s1?.cancel();
    _s2?.cancel();
    _s3?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _cycleSpeed() {
    setState(() {
      _speed = _speed == 1.0 ? 1.5 : (_speed == 1.5 ? 2.0 : 1.0);
      _player.setPlaybackRate(_speed);
    });
    HapticFeedback.selectionClick();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;
    final remaining = _duration - _position;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PcMono.accent.withValues(alpha: 0.15), PcMono.accent.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PcMono.accent.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [PcMono.accent, PcMono.accentDeep]), shape: BoxShape.circle),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(pcTr(l10n, 'post_voice_note', 'Note vocale'),
              style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, color: ThixPolicy.textMain, fontSize: 12)),
          const Spacer(),
          if (_duration.inSeconds > 0)
            Text(_fmt(_duration), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play(UrlSource(widget.audioUrl));
              }
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [PcMono.accent, PcMono.accentDeep]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: PcMono.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) => GestureDetector(
                onTapDown: (d) {
                  final p = d.localPosition.dx / cons.maxWidth;
                  if (p >= 0 && p <= 1 && _duration.inMilliseconds > 0) {
                    _player.seek(Duration(milliseconds: (_duration.inMilliseconds * p).round()));
                  }
                },
                child: CustomPaint(size: const Size(double.infinity, 32), painter: _WaveformPainter(progress: progress, color: PcMono.accent)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PcMono.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PcMono.accent.withValues(alpha: 0.3)),
              ),
              child: Text('${_speed}x',
                  style: ThixPolicy.captionStyle.copyWith(color: PcMono.accent, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(_fmt(_position), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10)),
          const Spacer(),
          Text('-${_fmt(remaining.isNegative ? Duration.zero : remaining)}',
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  _WaveformPainter({required this.progress, required this.color});
  static const int _bars = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final bw = size.width / (_bars * 1.5);
    final sp = bw * 0.5;
    for (var i = 0; i < _bars; i++) {
      final x = i * (bw + sp);
      final hp = (sin(i * 0.5) * 0.3 + 0.5 + (i % 3) * 0.1).clamp(0.2, 0.9);
      final bh = size.height * hp;
      final y = (size.height - bh) / 2;
      final active = (i / _bars) <= progress;
      final paint = Paint()
        ..color = active ? color : color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), Radius.circular(bw / 2)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.progress != progress;
}

// ============================================================================
// ✅ APERÇU DE LIEN — hauteur STABLE, jamais de double image
//   • YouTube sans média  → grande vignette 16:9 (construite depuis l'ID)
//   • Autres cas          → carte horizontale compacte (hauteur fixe)
//   • Si le post a déjà une photo/vidéo → toujours la carte compacte
// ============================================================================
class PcLinkPreview extends StatefulWidget {
  final String url;
  final bool hasMedia;
  const PcLinkPreview({super.key, required this.url, this.hasMedia = false});

  @override
  State<PcLinkPreview> createState() => _PcLinkPreviewState();
}

class _PcLinkPreviewState extends State<PcLinkPreview> {
  Map<String, dynamic>? _data;

  String get _domain => Uri.tryParse(widget.url)?.host.replaceFirst('www.', '') ?? '';

  String get _favicon {
    final host = Uri.tryParse(widget.url)?.host ?? '';
    return 'https://www.google.com/s2/favicons?domain=$host&sz=${PcConfig.avatarFallbackSize}';
  }

  String? get _ytId {
    final u = Uri.tryParse(widget.url);
    if (u == null) return null;
    final host = u.host.toLowerCase().replaceFirst('www.', '').replaceFirst('m.', '');
    String? id;
    if (host == 'youtu.be') {
      id = u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
    } else if (host == 'youtube.com' || host == 'music.youtube.com') {
      id = u.queryParameters['v'];
      if (id == null && u.pathSegments.length >= 2 && const ['shorts', 'embed', 'live'].contains(u.pathSegments[0])) {
        id = u.pathSegments[1];
      }
    }
    if (id != null && RegExp(r'^[A-Za-z0-9_-]{6,15}$').hasMatch(id)) return id;
    return null;
  }

  String? get _ytThumb => _ytId == null ? null : 'https://i.ytimg.com/vi/$_ytId/hqdefault.jpg';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!PcValidators.isSafeExternalFetchUrl(widget.url)) return;
    final cached = PcCache.instance.getLinkPreview(widget.url);
    if (cached != null) {
      _data = cached;
      return;
    }
    try {
      final r = await Supabase.instance.client.functions
          .invoke('link-preview', body: <String, dynamic>{'url': widget.url}).timeout(PcConfig.linkPreviewTimeout);
      if (r.data is Map) {
        final d = Map<String, dynamic>.from(r.data as Map);
        PcCache.instance.setLinkPreview(widget.url, d);
        if (mounted) setState(() => _data = d);
      }
    } catch (_) {
      PcLog.warn('LinkPreview fetch failed');
    }
  }

  Future<void> _open() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  BoxDecoration get _deco => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      );

  Widget _faviconBox() => Container(
        color: PcMono.accent.withValues(alpha: 0.06),
        alignment: Alignment.center,
        child: CachedNetworkImage(
          imageUrl: _favicon,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const Icon(Icons.link_rounded, color: PcMono.accent, size: 26),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_domain.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    var title = PcValidators.sanitizeLine(_data?['title']?.toString() ?? '', maxLength: 300);
    final desc = PcValidators.sanitizeLine(_data?['description']?.toString() ?? '', maxLength: 500);
    final og = pcSafeImageUrl(_data?['image']?.toString());
    final yt = _ytThumb;
    if (title.isEmpty) title = yt != null ? 'YouTube' : _domain;

    return GestureDetector(
      onTap: _open,
      onLongPress: () => pcCopy(context, widget.url, pcTr(l10n, 'post_link_copied', 'Lien copié')),
      child: (yt != null && !widget.hasMedia) ? _big(title, og ?? yt) : _compact(title, desc, widget.hasMedia ? null : (og ?? yt), l10n),
    );
  }

  Widget _domainRow() => Row(children: [
        const Icon(Icons.link_rounded, size: 14, color: ThixPolicy.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(_domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]);

  Widget _big(String title, String image) {
    return Container(
      decoration: _deco,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: PcMono.accentDeep),
              errorWidget: (_, __, ___) => _faviconBox(),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.bold, fontSize: 14, height: 1.25)),
              _domainRow(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _compact(String title, String desc, String? image, AppLocalizations l10n) {
    return Container(
      height: 92,
      decoration: _deco,
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        SizedBox(
          width: 92,
          height: 92,
          child: image != null
              ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (_, __, ___) => _faviconBox())
              : _faviconBox(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.bold, fontSize: 13.5, height: 1.25)),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 4),
              _domainRow(),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ============================================================================
// MINIATURE VIDÉO (remplit son parent)
// ============================================================================
class PcVideoThumbTile extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final VoidCallback onTap;
  const PcVideoThumbTile({super.key, required this.videoUrl, this.width, this.height, required this.onTap});

  @override
  State<PcVideoThumbTile> createState() => _PcVideoThumbTileState();
}

class _PcVideoThumbTileState extends State<PcVideoThumbTile> {
  static int _activeFrameReaders = 0;
  String? _thumbnailUrl;
  VideoPlayerController? _frameController;
  bool _frameReady = false;
  bool _countedActive = false;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _thumbnailUrl = PcCache.instance.getVideoThumb(widget.videoUrl);
    if (_thumbnailUrl == null) _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (!PcValidators.isSafeExternalFetchUrl(widget.videoUrl)) return;
    try {
      final r = await Supabase.instance.client.functions
          .invoke('video-thumbnail', body: <String, dynamic>{'video_url': widget.videoUrl}).timeout(PcConfig.videoThumbTimeout);
      final data = r.data;
      final url = data is Map ? pcSafeImageUrl(data['thumbnail_url']?.toString()) : null;
      if (url != null) {
        PcCache.instance.setVideoThumb(widget.videoUrl, url);
        if (mounted) setState(() => _thumbnailUrl = url);
        return;
      }
    } catch (_) {
      PcLog.warn('Video thumbnail (server) failed, fallback to first frame');
    }
    await _loadFirstFrame();
  }

  Future<void> _loadFirstFrame() async {
    if (!mounted || _frameController != null) return;
    if (_activeFrameReaders >= PcConfig.maxVideoFrameFallbacks) return;
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null || !PcValidators.isValidUrl(widget.videoUrl)) return;
    _activeFrameReaders++;
    _countedActive = true;
    final c = VideoPlayerController.networkUrl(uri, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _frameController = c;
    try {
      await c.initialize().timeout(const Duration(seconds: 12));
      await c.setVolume(0);
      await c.seekTo(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _frameReady = true;
        _duration = c.value.duration;
      });
    } catch (_) {
      PcLog.warn('Video first frame failed');
      try {
        await c.dispose();
      } catch (_) {}
      if (_frameController == c) _frameController = null;
    }
  }

  @override
  void dispose() {
    _frameController?.dispose();
    if (_countedActive && _activeFrameReaders > 0) _activeFrameReaders--;
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  Widget _background() {
    if (_thumbnailUrl != null) {
      return CachedNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _placeholder());
    }
    final c = _frameController;
    if (_frameReady && c != null && c.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.size.width == 0 ? 16 : c.value.size.width,
          height: c.value.size.height == 0 ? 9 : c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [PcMono.accentDeep, PcMono.accent]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: PcMono.accentDeep,
        child: Stack(fit: StackFit.expand, children: [
          _background(),
          Container(color: Colors.black.withValues(alpha: 0.18)),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  (_duration != null && _duration! > Duration.zero) ? _fmt(_duration!) : pcTr(l10n, 'post_video_badge', 'VIDÉO'),
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: PcMediaChipButton(
              icon: Icons.download_rounded,
              semanticsLabel: pcTr(l10n, 'post_download_video', 'Télécharger la vidéo'),
              onTap: () => pcDownloadMedia(context, widget.videoUrl),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// LIKERS
// ============================================================================
class PcLikersStack extends StatefulWidget {
  final int count;
  final String postId;
  final bool isLikedByMe;
  final AppLocalizations l10n;
  const PcLikersStack({super.key, required this.count, required this.postId, required this.isLikedByMe, required this.l10n});

  @override
  State<PcLikersStack> createState() => _PcLikersStackState();
}

class _PcLikersStackState extends State<PcLikersStack> {
  List<String> _avatars = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant PcLikersStack old) {
    super.didUpdateWidget(old);
    if (widget.count != old.count) _fetch();
  }

  Future<void> _fetch() async {
    if (widget.count == 0) {
      if (mounted) setState(() { _loading = false; _avatars = []; });
      return;
    }
    final cached = PcCache.instance.getLikers(widget.postId);
    if (cached != null) {
      if (mounted) setState(() { _avatars = cached; _loading = false; });
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('post_likes')
          .select('user_id, profiles(avatar_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false)
          .limit(PcConfig.maxLikersFetched)
          .timeout(PcConfig.networkTimeout);
      final avatars = <String>[];
      if (res is List) {
        for (final row in res) {
          final p = row['profiles'];
          final url = p is Map ? pcSafeImageUrl(p['avatar_url']?.toString()) : null;
          avatars.add(url ?? '');
        }
      }
      PcCache.instance.setLikers(widget.postId, avatars);
      if (mounted) setState(() { _avatars = avatars; _loading = false; });
    } catch (_) {
      PcLog.error('fetchLikersAvatars failed', {'postId': widget.postId});
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = min(PcConfig.maxLikersFetched, widget.count);
    final extra = widget.count - shown;
    final colors = [PcMono.accent, ThixPolicy.danger, PcMono.accentDeep, ThixPolicy.info, ThixPolicy.domainMedia];
    final text = widget.isLikedByMe
        ? (widget.count == 1
            ? widget.l10n.t('post_liked_by_you')
            : widget.l10n.t('post_liked_by_you_and_others', args: ['${widget.count - 1}']))
        : widget.l10n.t('post_liked_by_others', args: ['${widget.count}']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Row(
          children: List.generate(shown, (i) {
            final url = _avatars.length > i ? _avatars[i] : '';
            final real = url.isNotEmpty && !_loading;
            return Align(
              widthFactor: 0.7,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[(widget.postId.hashCode + i).abs() % colors.length],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                  image: real ? DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover) : null,
                ),
                child: !real ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
              ),
            );
          }),
        ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('+$extra',
                style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: ThixPolicy.captionStyle.copyWith(fontSize: 12.5, color: ThixPolicy.textSecondary), overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}
