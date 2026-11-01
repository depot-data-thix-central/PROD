// lib/presentation/thix_weeding/pages/guest/livre_or_page.dart
// ============================================================================
// LIVRE D'OR — Feed social élégant (Web + Mobile)
// ✅ Modèles de vœux prêts à poster
// ✅ Enregistrement / upload vidéo ≤ 50 min AVEC PREVIEWlecteur intégré
// ✅ Feed type réseau social SANS commentaires (réactions ❤️ uniquement)
// ✅ Temps réel Supabase (nouvelles publications / modération staff)
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/failure.dart';
import '../../providers/wedding_provider.dart';
import 'guestbook_repository.dart';

part 'livre_or_page.g.dart';

// ============================================================
// PALETTE — Charte THIX MARIAGE
// ============================================================
class _P {
  static const bg = Color(0xFFFFFBFC);
  static const surface = Colors.white;
  static const primary = Color(0xFFE31C4E);
  static const primarySoft = Color(0xFFFFE3EA);
  static const accent = Color(0xFFD4AF37);
  static const accentSoft = Color(0xFFFDF6E3);
  static const ink = Color(0xFF241521);
  static const inkSoft = Color(0xFF8A7580);

  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE31C4E), Color(0xFFFF6B8B)],
  );

  static final shadow = [
    BoxShadow(color: const Color(0xFFE31C4E).withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
  ];
}

// ============================================================
// MODÈLES DE VŒUX
// ============================================================
const List<String> _kWishTemplates = [
  'Félicitations pour votre union ! Que cette journée soit le début d\'une vie pleine de bonheur. ❤️',
  'Longue vie à vous deux ! Que l\'amour qui vous unit aujourd\'hui grandisse chaque jour davantage.',
  'Merci pour ce moment magique, vous étiez resplendissants ! Tous nos vœux de bonheur. 🌸',
  'Aujourd\'hui, deux cœurs ne font plus qu\'un. Quelle magnifique célébration !',
  'Que votre amour soit votre plus belle aventure. On vous aime fort ! ✨',
];

// ============================================================
// PROVIDERS
// ============================================================
/// TODO: brancher sur l'auth THIX Hub (profiles.thix_id)
@riverpod
String currentThixId(CurrentThixIdRef ref) => 'THIX_GUEST_001';

@riverpod
class GuestbookFeed extends _$GuestbookFeed {
  @override
  Future<List<GuestbookPost>> build(String weddingId) async {
    final repo = ref.read(guestbookRepositoryProvider);
    final posts = await repo.getPosts(weddingId, ref.read(currentThixIdProvider));
    _subscribeRealtime(weddingId);
    return posts;
  }

  /// Temps réel : nouvelles publications + modération staff
  void _subscribeRealtime(String weddingId) {
    try {
      final channel = Supabase.instance.client.channel('gb_$weddingId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'thix_weeding_guestbook',
            callback: (payload) {
              final row = Map<String, dynamic>.from(payload.newRecord);
              if (row['wedding_id']?.toString() != weddingId) return;
              final current = state.valueOrNull ?? const [];
              final post = GuestbookPost.fromJson(row);
              if (current.any((p) => p.id == post.id)) return;
              state = AsyncData([post, ...current]);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'thix_weeding_guestbook',
            callback: (payload) {
              final current = state.valueOrNull ?? const [];
              final old = payload.oldRecord['id'] as String?;
              if (old == null) return;
              state = AsyncData(current.where((p) => p.id != old).toList());
            },
          )
          .subscribe();
      ref.onDispose(() => Supabase.instance.client.removeChannel(channel));
    } catch (_) {}
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Réaction ❤️ optimiste (rollback si erreur)
  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx < 0) return;

    final post = current[idx];
    state = AsyncData([...current]
      ..[idx] = post.copyWith(
        likedByMe: !post.likedByMe,
        likesCount: post.likesCount + (post.likedByMe ? -1 : 1),
      ));

    try {
      await ref.read(guestbookRepositoryProvider).toggleLike(
            postId,
            ref.read(currentThixIdProvider),
            currentlyLiked: post.likedByMe,
          );
    } catch (_) {
      state = AsyncData(current); // rollback
    }
  }
}

@riverpod
class GuestbookComposer extends _$GuestbookComposer {
  @override
  FutureOr<void> build() => null;

  Future<bool> publish({
    required String weddingId,
    required String authorName,
    required String message,
    Uint8List? videoBytes,
    String? videoFileName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final post = await ref.read(guestbookRepositoryProvider).createPost(
            weddingId: weddingId,
            authorName: authorName,
            message: message,
            videoBytes: videoBytes,
            videoFileName: videoFileName,
            guestThixId: ref.read(currentThixIdProvider),
          );
      final current = ref.read(guestbookFeedProvider(weddingId)).valueOrNull ?? const [];
      ref.read(guestbookFeedProvider(weddingId).notifier).state = AsyncData([post, ...current]);
    });
    return !state.hasError;
  }
}

// ============================================================
// PAGE
// ============================================================
class LivreOrPage extends ConsumerWidget {
  final String weddingId;
  const LivreOrPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(guestbookFeedProvider(weddingId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.surface,
        foregroundColor: _P.ink,
        elevation: 0,
        title: const Text('Livre d\'Or',
            style: TextStyle(fontFamily: 'Serif', fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, fontSize: 22)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: feedAsync.when(
        data: (posts) => RefreshIndicator(
          color: _P.primary,
          onRefresh: () => ref.read(guestbookFeedProvider(weddingId).notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Banner(weddingId: weddingId),
              const SizedBox(height: 16),
              _ComposerTeaser(onTap: () => _openComposer(context)),
              const SizedBox(height: 24),
              if (posts.isEmpty) const _EmptyView() else ...posts.map((p) => _PostCard(post: p, weddingId: weddingId)),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: _P.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 56, color: _P.inkSoft),
                const SizedBox(height: 12),
                Text(e is Failure ? e.message : 'Erreur de chargement',
                    textAlign: TextAlign.center, style: const TextStyle(color: _P.ink)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(guestbookFeedProvider(weddingId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                  style: FilledButton.styleFrom(backgroundColor: _P.primary),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: InkWell(
        onTap: () => _openComposer(context),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: _P.gradPrimary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Écrire un vœu', maxLines: 1, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  void _openComposer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposerSheet(weddingId: weddingId),
    );
  }
}

// ============================================================
// BANNIÈRE
// ============================================================
class _Banner extends ConsumerWidget {
  final String weddingId;
  const _Banner({required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(guestWeddingProvider(weddingId)).valueOrNull?.coupleNames;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _P.accent.withOpacity(0.45)),
        boxShadow: _P.shadow,
      ),
      child: Stack(
        children: [
          Positioned(top: 0, right: 0, child: Icon(Icons.local_florist_rounded, size: 54, color: _P.primary.withOpacity(0.08))),
          Positioned(bottom: 0, left: 0, child: Icon(Icons.local_florist_rounded, size: 54, color: _P.accent.withOpacity(0.10))),
          Column(
            children: [
              const Text('NOTRE LIVRE D\'OR', style: TextStyle(fontSize: 10, letterSpacing: 2.4, color: _P.inkSoft, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text('Livre d\'Or',
                  style: TextStyle(fontFamily: 'Serif', fontStyle: FontStyle.italic, fontSize: 34, color: _P.ink, fontWeight: FontWeight.w600, height: 1.1)),
              const SizedBox(height: 10),
              Container(width: 56, height: 1.5, color: _P.accent),
              const SizedBox(height: 12),
              if (couple != null && couple.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('de $couple', style: const TextStyle(fontFamily: 'Serif', fontStyle: FontStyle.italic, fontSize: 15, color: _P.accent)),
                ),
              const Text(
                'Un vœu, une pensée, un souvenir vidéo…\nLaissez-nous un peu de vous, merci du fond du cœur.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _P.inkSoft, height: 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TEASER COMPOSER
// ============================================================
class _ComposerTeaser extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposerTeaser({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: _P.primarySoft)),
                child: const Text('Partagez un vœu ou un souvenir vidéo…', style: TextStyle(color: _P.inkSoft, fontSize: 13.5)),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.videocam_rounded, color: _P.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARTE DE PUBLICATION
// ============================================================
class _PostCard extends ConsumerWidget {
  final GuestbookPost post;
  final String weddingId;
  const _PostCard({required this.post, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
                child: Text(post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _P.ink)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(_timeAgo(post.createdAt), style: const TextStyle(fontSize: 11, color: _P.inkSoft)),
                        if (post.hasVideo) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _P.primarySoft, borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_rounded, size: 10, color: _P.primary),
                                SizedBox(width: 3),
                                Text('Souvenir vidéo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _P.primary)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!post.isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _P.accentSoft, borderRadius: BorderRadius.circular(8)),
                  child: const Text('En validation', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _P.accent)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.message, style: const TextStyle(fontSize: 14, color: _P.ink, height: 1.5)),
          const SizedBox(height: 12),
          if (post.hasVideo) ...[
            _FeedVideo(url: post.mediaUrl!),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              InkWell(
                onTap: () => ref.read(guestbookFeedProvider(weddingId).notifier).toggleLike(post.id),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: post.likedByMe ? _P.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: post.likedByMe ? _P.primary.withOpacity(0.4) : _P.primarySoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: post.likedByMe ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 17, color: _P.primary),
                      ),
                      const SizedBox(width: 6),
                      Text('${post.likesCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.primary)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text('Souvenir #${post.id.substring(0, 4)}', style: const TextStyle(fontSize: 10, color: _P.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return 'il y a ${d.inDays} j';
    if (d.inHours > 0) return 'il y a ${d.inHours} h';
    if (d.inMinutes > 0) return 'il y a ${d.inMinutes} min';
    return 'à l\'instant';
  }
}

// ============================================================
// LECTEUR VIDÉO INLINE (preview 1ère image + play + plein écran)
// ============================================================
class _FeedVideo extends StatefulWidget {
  final String url;
  const _FeedVideo({required this.url});

  @override
  State<_FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<_FeedVideo> {
  VideoPlayerController? _ctrl;
  bool _initFailed = false;
  bool _initializing = false;

  Future<void> _ensureInit({bool autoplay = false}) async {
    if (_ctrl != null || _initFailed || _initializing) return;
    setState(() => _initializing = true);
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      c.addListener(() => setState(() {}));
      if (autoplay) await c.play();
      if (mounted) setState(() => _ctrl = c);
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black87,
          child: _initFailed
              ? const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40))
              : c == null || !c.value.isInitialized
                  ? InkWell(
                      onTap: () => _ensureInit(),
                      child: Center(
                        child: _initializing
                            ? const CircularProgressIndicator(color: _P.primary)
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
                                  SizedBox(height: 6),
                                  Text('Lire le souvenir vidéo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
                        if (!c.value.isPlaying)
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
                            onPressed: () => c.play(),
                          )
                        else
                          GestureDetector(onTap: () => c.pause(), child: const SizedBox.expand()),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton(
                            icon: Icon(c.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 20),
                            onPressed: () => c.setVolume(c.value.volume == 0 ? 1 : 0),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: IconButton(
                            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 26),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FullscreenVideoPage(url: widget.url))),
                          ),
                        ),
                        if (c.value.isPlaying && c.value.duration.inSeconds > 0)
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 6,
                            child: VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.only(top: 24)),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

// ============================================================
// PLEIN ÉCRAN
// ============================================================
class _FullscreenVideoPage extends StatefulWidget {
  final String url;
  const _FullscreenVideoPage({required this.url});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late VideoPlayerController _ctrl;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
        _ctrl.play();
      }
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _failed
                ? const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 56)
                : !_ready
                    ? const CircularProgressIndicator(color: _P.primary)
                    : AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)),
          ),
          GestureDetector(onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(), child: const SizedBox.expand()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  if (_ready)
                    IconButton(
                      icon: Icon(_ctrl.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
                      onPressed: () => _ctrl.setVolume(_ctrl.value.volume == 0 ? 1 : 0),
                    ),
                  if (_ready)
                    IconButton(
                      icon: Icon(_ctrl.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                      onPressed: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
                    ),
                ],
              ),
            ),
          ),
          if (_ready)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Column(
                children: [
                  VideoProgressIndicator(_ctrl, allowScrubbing: true),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_ctrl.value.position), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(_fmt(_ctrl.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// COMPOSER — vœu + modèles + vidéo ≤ 50 min AVEC PREVIEW
// ============================================================
class _ComposerSheet extends ConsumerStatefulWidget {
  final String weddingId;
  const _ComposerSheet({required this.weddingId});

  @override
  ConsumerState<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends ConsumerState<_ComposerSheet> {
  final _nameCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _picker = ImagePicker();

  XFile? _video;
  Duration? _videoDuration;
  VideoPlayerController? _previewCtrl;
  String? _videoError;
  bool _probing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    _previewCtrl?.dispose();
    super.dispose();
  }

  /// Controller de preview compatible Web (blob) + Mobile (fichier)
  Future<VideoPlayerController> _newPreviewController(XFile x) async {
    // Web + mobile: networkUrl works for picker paths / blob URLs
    return VideoPlayerController.networkUrl(Uri.parse(x.path));
  }

  Future<void> _pickVideo({required bool camera}) async {
    setState(() {
      _probing = true;
      _videoError = null;
    });
    try {
      final picked = camera
          ? await _picker.pickVideo(source: ImageSource.camera, maxDuration: GuestbookRepository.maxVideoDuration)
          : await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      final ctrl = await _newPreviewController(picked);
      try {
        await ctrl.initialize();
      } catch (_) {
        await ctrl.dispose();
        setState(() => _videoError = 'Impossible de lire cette vidéo.');
        return;
      }

      final dur = ctrl.value.duration;
      if (dur > GuestbookRepository.maxVideoDuration) {
        await ctrl.dispose();
        setState(() => _videoError = 'Vidéo trop longue (${GuestbookRepository.formatDuration(dur)}). Maximum 50 minutes.');
        return;
      }

      ctrl.addListener(() => setState(() {}));
      await _previewCtrl?.dispose();
      setState(() {
        _video = picked;
        _videoDuration = dur;
        _previewCtrl = ctrl;
      });
    } catch (_) {
      setState(() => _videoError = 'Impossible de lire cette vidéo.');
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  void _removeVideo() {
    _previewCtrl?.dispose();
    setState(() {
      _video = null;
      _videoDuration = null;
      _previewCtrl = null;
      _videoError = null;
    });
  }

  Future<void> _publish() async {
    final name = _nameCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (name.length < 2 || msg.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom (min 2) et message (min 3) requis')));
      return;
    }

    Uint8List? bytes;
    String? fname;
    if (_video != null) {
      bytes = await _video!.readAsBytes();
      fname = _video!.name;
    }

    final ok = await ref.read(guestbookComposerProvider.notifier).publish(
          weddingId: widget.weddingId,
          authorName: name,
          message: msg,
          videoBytes: bytes,
          videoFileName: fname,
        );
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bytes != null ? '🎬 Souvenir vidéo publié !' : '❤️ Vœu publié, merci !')),
      );
    } else {
      final err = ref.read(guestbookComposerProvider).error;
      final msgErr = err is PostgrestException ? 'Supabase : ${err.message}' : (err?.toString() ?? 'Échec de publication.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msgErr), duration: const Duration(seconds: 6)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(guestbookComposerProvider);
    final busy = postState.isLoading || _probing;

    return Container(
      decoration: const BoxDecoration(color: _P.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Text('Laisser un souvenir', style: TextStyle(fontFamily: 'Serif', fontStyle: FontStyle.italic, fontSize: 24, color: _P.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Vos mots et vidéos resteront gravés pour les mariés.', style: TextStyle(fontSize: 12, color: _P.inkSoft)),
            const SizedBox(height: 18),

            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Votre nom *',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: _P.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: _P.bg,
              ),
            ),
            const SizedBox(height: 12),

            const Text('Modèles de vœux', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.inkSoft)),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kWishTemplates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(_kWishTemplates[i].split('!').first.trim(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _P.primary)),
                  backgroundColor: _P.primarySoft,
                  side: BorderSide.none,
                  onPressed: () => _msgCtrl.text = _kWishTemplates[i],
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Votre message *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: _P.bg,
              ),
            ),
            const SizedBox(height: 4),

            // ---- SECTION VIDÉO + PREVIEW ----
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.primarySoft)),
              child: _video == null
                  ? Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.videocam_rounded, color: _P.primary, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('Ajouter un souvenir vidéo (50 min max)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _P.ink))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => _pickVideo(camera: true),
                                icon: const Icon(Icons.fiber_manual_record_rounded, size: 14),
                                label: const Text('Enregistrer', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(foregroundColor: _P.primary, side: const BorderSide(color: _P.primary), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => _pickVideo(camera: false),
                                icon: const Icon(Icons.folder_open_rounded, size: 16),
                                label: const Text('Galerie', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(foregroundColor: _P.primary, side: const BorderSide(color: _P.primary), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                          ],
                        ),
                        if (_probing) ...[
                          const SizedBox(height: 10),
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary)),
                        ],
                        if (_videoError != null) ...[
                          const SizedBox(height: 8),
                          Text(_videoError!, style: const TextStyle(fontSize: 11, color: _P.primary, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        // PREVIEW VIDÉO RÉELLE
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_previewCtrl != null && _previewCtrl!.value.isInitialized)
                                  VideoPlayer(_previewCtrl!)
                                else
                                  Container(color: Colors.black87, child: const Center(child: CircularProgressIndicator(color: _P.primary))),
                                if (_previewCtrl != null && _previewCtrl!.value.isInitialized && !_previewCtrl!.value.isPlaying)
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 52),
                                    onPressed: () => _previewCtrl!.play(),
                                  ),
                                if (_previewCtrl != null && _previewCtrl!.value.isPlaying)
                                  GestureDetector(onTap: () => _previewCtrl!.pause(), child: const SizedBox.expand()),
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      _videoDuration != null ? GuestbookRepository.formatDuration(_videoDuration!) : '',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                    onPressed: _removeVideo,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Vidéo prête à publier', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink))),
                            TextButton(onPressed: () => _pickVideo(camera: false), child: const Text('Changer', style: TextStyle(fontSize: 12))),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: busy ? null : _publish,
                style: FilledButton.styleFrom(backgroundColor: _P.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(busy ? 'Publication…' : 'Publier mon souvenir', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ÉTAT VIDE
// ============================================================
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(20), boxShadow: _P.shadow),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _P.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.auto_stories_rounded, size: 44, color: _P.primary),
          ),
          const SizedBox(height: 16),
          const Text('Le livre est encore vierge', style: TextStyle(fontFamily: 'Serif', fontStyle: FontStyle.italic, fontSize: 20, color: _P.ink)),
          const SizedBox(height: 8),
          const Text('Soyez le premier à laisser un vœu ou un souvenir vidéo aux mariés.', textAlign: TextAlign.center, style: TextStyle(color: _P.inkSoft, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
