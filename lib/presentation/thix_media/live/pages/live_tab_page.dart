// lib/presentation/thix_media/live/pages/live_tab_page.dart
//
// LiveTabPage v2 — Découverte des lives (style TikTok Live)
// ✅ Live à la une (grand format) + grille 2 colonnes
// ✅ Filtres par catégorie
// ✅ Bannière « Retour à mon live / Vous regardez… » (live réduit)
// ✅ Actualisation automatique (15 s) + pull-to-refresh
// ✅ activeLivesProvider conservé (utilisé par la page d'accueil média)

import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../providers/go_live_provider.dart';
import '../services/live_room_manager.dart';
import '../services/live_service.dart';
import 'go_live_page.dart';
import 'live_room_view.dart';
import 'live_viewer_page.dart';

const Color _kRed = Color(0xFFE11D48);
const Duration _kThrottle = Duration(milliseconds: 500);
const Duration _kAutoRefresh = Duration(seconds: 15);
const int _kMaxLives = 50;

String _t(AppLocalizations l, String k, String fb) {
  final v = l.t(k);
  return (v.isEmpty || v == k) ? fb : v;
}

String _count(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _since(DateTime since) {
  final d = DateTime.now().difference(since);
  if (d.inMinutes < 1) return '< 1 min';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours}h' : '${d.inHours}h${m.toString().padLeft(2, '0')}';
}

// ============================================================================
// PROVIDER
// ============================================================================
final activeLivesProvider =
    FutureProvider.autoDispose<List<LiveSession>>((ref) async {
  final lives = await ref.watch(liveServiceProvider).listActiveLives();
  lives.sort((a, b) => b.viewerCount.compareTo(a.viewerCount));
  return lives.take(_kMaxLives).toList();
});

// ============================================================================
// PAGE
// ============================================================================
class LiveTabPage extends ConsumerStatefulWidget {
  const LiveTabPage({super.key});

  @override
  ConsumerState<LiveTabPage> createState() => _LiveTabPageState();
}

class _LiveTabPageState extends ConsumerState<LiveTabPage> {
  DateTime? _last;
  Timer? _auto;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(_kAutoRefresh, (_) {
      if (mounted) ref.invalidate(activeLivesProvider);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < _kThrottle) return false;
    _last = now;
    return true;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ThixPolicy.danger : ThixPolicy.domainMedia,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _refresh() async {
    HapticFeedback.selectionClick();
    ref.invalidate(activeLivesProvider);
    try {
      await ref.read(activeLivesProvider.future);
    } catch (_) {}
  }

  void _openGoLive(AppLocalizations l10n) {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    if (Supabase.instance.client.auth.currentUser == null) {
      _snack(_t(l10n, 'live_login_required', 'Connectez-vous pour lancer un live.'),
          error: true);
      return;
    }
    final m = LiveRoomManager.instance;
    if (m.isActive) {
      _snack('Un live est déjà en cours.', error: true);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GoLivePage()));
  }

  void _openViewer(LiveSession live) {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    final m = LiveRoomManager.instance;
    if (m.isActive && m.isHost) {
      _snack('Terminez d\'abord votre live en cours.', error: true);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveViewerPage(liveId: live.id)),
    );
  }

  void _resumeRoom() {
    final m = LiveRoomManager.instance;
    final s = m.session;
    if (s == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => LiveRoomView(isHost: m.isHost, liveId: s.id)),
    );
  }

  void _shareLive(AppLocalizations l10n, LiveSession live) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: liveShareUrl(live.id)));
    _snack(_t(l10n, 'live_link_copied', 'Lien copié'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(activeLivesProvider);
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kRed,
        foregroundColor: Colors.white,
        onPressed: () => _openGoLive(l10n),
        icon: const Icon(Icons.podcasts_rounded),
        label: Text(_t(l10n, 'live_go_live_btn', 'Passer en direct'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(l10n, async),
            _resumeBanner(),
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  retry: _t(l10n, 'common_retry', 'Réessayer'),
                  onRetry: _refresh,
                ),
                data: (lives) => _content(l10n, lives, uid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n, AsyncValue<List<LiveSession>> async) {
    final n = async.valueOrNull?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const _PulseBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              n > 0
                  ? '${_t(l10n, 'live_tab_title', 'Lives')} · $n'
                  : _t(l10n, 'live_tab_title', 'Lives'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _resumeBanner() {
    final m = LiveRoomManager.instance;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        if (!m.isActive || m.session == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: _resumeRoom,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [_kRed, Color(0xFF9F1239)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.isHost
                        ? 'Retour à mon live · ${m.session!.title}'
                        : 'Vous regardez · ${m.session!.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content(
      AppLocalizations l10n, List<LiveSession> lives, String? uid) {
    if (lives.isEmpty) {
      return _EmptyState(
        title: _t(l10n, 'live_empty_title', 'Aucun live pour le moment'),
        subtitle: _t(l10n, 'live_empty_subtitle',
            'Soyez le premier à passer en direct !'),
      );
    }

    final categories = <String>{
      for (final l in lives)
        if (l.category.isNotEmpty) l.category
    }.toList()
      ..sort();

    final filtered = _filter == 'all'
        ? lives
        : lives.where((l) => l.category == _filter).toList();

    final featured = filtered.isNotEmpty ? filtered.first : null;
    final rest = filtered.length > 1 ? filtered.sublist(1) : <LiveSession>[];

    return RefreshIndicator(
      color: _kRed,
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          if (categories.length > 1)
            SliverToBoxAdapter(child: _filters(categories)),
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: _FeaturedCard(
                  session: featured,
                  isOwn: uid != null && featured.hostId == uid,
                  onTap: () => _openViewer(featured),
                  onLongPress: () => _shareLive(l10n, featured),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final live = rest[i];
                  return _LiveCard(
                    key: ValueKey('live_${live.id}'),
                    session: live,
                    isOwn: uid != null && live.hostId == uid,
                    onTap: () => _openViewer(live),
                    onLongPress: () => _shareLive(l10n, live),
                  );
                },
                childCount: rest.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(List<String> categories) {
    Widget chip(String key, String label) {
      final sel = _filter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            setState(() => _filter = key);
          },
          selectedColor: _kRed,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide.none,
          labelStyle: TextStyle(
            color: sel ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          chip('all', 'Tous'),
          for (final c in categories) chip(c, c),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTES
// ============================================================================
class _FeaturedCard extends StatelessWidget {
  final LiveSession session;
  final bool isOwn;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FeaturedCard({
    required this.session,
    required this.isOwn,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    final hasCover = s.coverUrl != null && s.coverUrl!.isNotEmpty;
    final hasAvatar = s.hostAvatarUrl != null && s.hostAvatarUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover)
                CachedNetworkImage(
                  imageUrl: s.coverUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                )
              else
                const _CoverPlaceholder(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              const Positioned(top: 12, left: 12, child: _PulseBadge(small: true)),
              Positioned(
                top: 12,
                right: 12,
                child: _viewers(s.viewerCount),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Row(
                  children: [
                    if (hasAvatar)
                      Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _kRed, width: 2),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: s.hostAvatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white54),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            '${isOwn ? 'Vous' : s.hostUsername} · ${_since(s.startedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: _kRed,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Regarder',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _viewers(int n) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.black54, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.remove_red_eye_outlined,
            size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(_count(n),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
      ],
    ),
  );
}

class _LiveCard extends StatelessWidget {
  final LiveSession session;
  final bool isOwn;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LiveCard({
    super.key,
    required this.session,
    required this.isOwn,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    final hasCover = s.coverUrl != null && s.coverUrl!.isNotEmpty;
    final hasAvatar = s.hostAvatarUrl != null && s.hostAvatarUrl!.isNotEmpty;

    return Material(
      color: ThixPolicy.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              CachedNetworkImage(
                imageUrl: s.coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _CoverPlaceholder(),
              )
            else
              const _CoverPlaceholder(),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 110,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
            const Positioned(top: 8, left: 8, child: _PulseBadge(small: true)),
            Positioned(top: 8, right: 8, child: _viewers(s.viewerCount)),
            if (isOwn)
              Positioned(
                top: 36,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: _kRed, borderRadius: BorderRadius.circular(6)),
                  child: const Text('MOI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasAvatar)
                    Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _kRed, width: 2),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: s.hostAvatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 16),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                height: 1.2)),
                        const SizedBox(height: 2),
                        Text(
                          '${s.hostUsername} · ${_since(s.startedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseBadge extends StatefulWidget {
  final bool small;
  const _PulseBadge({this.small = false});

  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 8 : 10, vertical: widget.small ? 3 : 5),
        decoration: BoxDecoration(
          color: _kRed,
          borderRadius: BorderRadius.circular(widget.small ? 5 : 6),
          boxShadow: [
            BoxShadow(
              color: _kRed.withValues(alpha: 0.5 * _c.value),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text('LIVE',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: widget.small ? 10 : 12,
                letterSpacing: 0.5)),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1A28), Color(0xFF121218)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.live_tv_rounded, size: 42, color: Colors.white24),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off_rounded,
                size: 56, color: Colors.white.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String retry;
  final VoidCallback onRetry;
  const _ErrorState(
      {required this.message, required this.retry, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 14),
            TextButton(onPressed: onRetry, child: Text(retry)),
          ],
        ),
      ),
    );
  }
}
