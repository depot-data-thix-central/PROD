// lib/presentation/thix_market/pages/live_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/live_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);

// ============================================================================
// VALIDATEURS
// ============================================================================
class _LiveValidators {
  _LiveValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id);
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static double safePrice(dynamic price) {
    if (price == null) return 0.0;
    final val = (price as num?)?.toDouble() ?? 0.0;
    return val < 0 || val.isNaN || val.isInfinite ? 0.0 : val;
  }

  static String formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Live] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Live] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Live] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    debugPrint('[Live] 🎬 Page opened');
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    final provider = context.read<LiveProvider>();

    try {
      await Future.wait([
        _withRetry(() => provider.loadLiveSessions(), label: 'loadLiveSessions'),
        _withRetry(() => provider.loadAuctions(), label: 'loadAuctions'),
        _withRetry(() => provider.loadMyLives(), label: 'loadMyLives'),
      ]);
      debugPrint('[Live] ✓ All data refreshed');
    } catch (e) {
      debugPrint('[Live] ❌ Refresh error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    debugPrint('[Live] 👋 Page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveProvider>();

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'THIX',
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
                color: Colors.white,
                fontSize: 17,
              ),
            ),
            Text(
              ' LIVE',
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.gold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.inkDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          tooltip: 'Retour',
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En direct'),
            Tab(text: 'Enchères'),
            Tab(text: 'Mes lives'),
          ],
          indicatorColor: ThixPolicy.gold,
          indicatorWeight: 3,
          labelColor: ThixPolicy.gold,
          labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13),
          unselectedLabelColor: ThixPolicy.textSecondary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Rafraîchir',
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: ThixPolicy.gold),
            tooltip: 'Créer un live',
            onPressed: () {
              HapticFeedback.mediumImpact();
              context.push('/market/live/create');
              debugPrint('[Live] ➕ Navigate to create live');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveNowTab(liveProvider),
          _buildAuctionsTab(liveProvider),
          _buildMyLivesTab(liveProvider),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1 : LIVES EN DIRECT
  // ============================================================
  Widget _buildLiveNowTab(LiveProvider provider) {
    if (provider.isLoading) {
      return const _SkeletonLiveGrid();
    }

    final liveSessions = provider.liveSessions;
    if (liveSessions.isEmpty) {
      return _EmptyState(
        icon: Icons.tv_off_rounded,
        title: 'Aucun live en cours',
        subtitle: 'Revenez plus tard pour découvrir des diffusions',
        buttonText: 'Actualiser',
        onPressed: _refreshData,
      );
    }

    final featuredLives = liveSessions.where((l) => l['is_featured'] == true).toList();
    final otherLives = liveSessions.where((l) => l['is_featured'] != true).toList();

    return RefreshIndicator(
      color: ThixPolicy.gold,
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (featuredLives.isNotEmpty)
            SliverToBoxAdapter(
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 360,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.9,
                  autoPlayInterval: const Duration(seconds: 5),
                ),
                items: featuredLives
                    .map((live) => _LiveCard(live: live, isFeatured: true))
                    .toList(),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _LiveCard(live: otherLives[index]),
                childCount: otherLives.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2 : ENCHÈRES
  // ============================================================
  Widget _buildAuctionsTab(LiveProvider provider) {
    if (provider.isLoadingAuctions) {
      return const _SkeletonList();
    }

    final auctions = provider.auctions;
    if (auctions.isEmpty) {
      return _EmptyState(
        icon: Icons.gavel_rounded,
        title: 'Aucune enchère en cours',
        subtitle: 'Revenez plus tard pour participer',
        buttonText: 'Actualiser',
        onPressed: _refreshData,
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.gold,
      onRefresh: _refreshData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: auctions.length,
        itemBuilder: (context, index) => _AuctionCard(auction: auctions[index]),
      ),
    );
  }

  // ============================================================
  // TAB 3 : MES LIVES
  // ============================================================
  Widget _buildMyLivesTab(LiveProvider provider) {
    if (provider.isLoadingMyLives) {
      return const _SkeletonList();
    }

    final myLives = provider.myLives;
    if (myLives.isEmpty) {
      return _EmptyState(
        icon: Icons.videocam_off_rounded,
        title: 'Aucun live',
        subtitle: 'Créez votre premier live pour vendre en direct',
        buttonText: 'Créer un live',
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/market/live/create');
        },
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.gold,
      onRefresh: _refreshData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: myLives.length,
        itemBuilder: (context, index) => _MyLiveCard(live: myLives[index]),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

/// Image réseau avec sanitization + fallback premium
class _NetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double iconSize;
  final IconData icon;

  const _NetworkImage(
    this.url, {
    this.fit = BoxFit.cover,
    this.iconSize = 30,
    this.icon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final safeUrl = _LiveValidators.sanitizeUrl(url);
    if (safeUrl == null) {
      return Container(
        color: ThixPolicy.inkDeep,
        child: Icon(icon, color: ThixPolicy.textMuted, size: iconSize),
      );
    }
    return CachedNetworkImage(
      imageUrl: safeUrl,
      fit: fit,
      placeholder: (_, __) => Container(
        color: ThixPolicy.inkDeep,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.gold),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: ThixPolicy.inkDeep,
        child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: iconSize),
      ),
    );
  }
}

/// Badge LIVE animé
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ThixPolicy.danger,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Opacity(
              opacity: 0.5 + _ctrl.value * 0.5,
              child: child,
            ),
            child: const Icon(Icons.fiber_manual_record_rounded, color: Colors.white, size: 8),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: ThixPolicy.microStyle.copyWith(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: ThixPolicy.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;
  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });
  @override
  Widget build(BuildContext context) => builder(context, child);
}

/// Countdown isolé dans son propre Stateful (évite rebuild global)
class _CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final Color activeColor;
  final Color urgentColor;

  const _CountdownTimer({
    required this.endTime,
    required this.activeColor,
    required this.urgentColor,
  });

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final diff = widget.endTime.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours.clamp(0, 99);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);
    final urgent = _remaining.inMinutes < 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        style: ThixPolicy.labelStyle.copyWith(
          color: urgent ? widget.urgentColor : widget.activeColor,
          fontWeight: ThixPolicy.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Carte Live (En direct)
class _LiveCard extends StatelessWidget {
  final Map<String, dynamic> live;
  final bool isFeatured;

  const _LiveCard({required this.live, this.isFeatured = false});

  @override
  Widget build(BuildContext context) {
    final id = live['id']?.toString() ?? '';
    final thumbnail = _LiveValidators.sanitizeUrl(live['thumbnail']?.toString());
    final title = _LiveValidators.sanitize(live['title']?.toString() ?? 'Live sans titre', maxLength: 80);
    final shopName = _LiveValidators.sanitize(live['shop_name']?.toString() ?? 'Boutique', maxLength: 60);
    final shopAvatar = _LiveValidators.sanitizeUrl(live['shop_avatar']?.toString());
    final viewers = _LiveValidators.safeInt(live['viewers']);
    final radius = isFeatured ? 18.0 : 14.0;

    return Semantics(
      button: true,
      label: 'Live "$title" par $shopName, $viewers spectateurs',
      child: GestureDetector(
        onTap: () {
          if (!_LiveValidators.isValidId(id)) {
            debugPrint('[Live] ⚠️ Invalid live ID: $id');
            return;
          }
          HapticFeedback.selectionClick();
          context.push('/market/live/$id');
          debugPrint('[Live] ▶️ Open live $id');
        },
        child: Container(
          margin: isFeatured ? const EdgeInsets.symmetric(horizontal: 4) : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: ThixPolicy.inkDeep,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: _NetworkImage(thumbnail, iconSize: 36, icon: Icons.live_tv_rounded),
              ),
              // Top badges
              Positioned(
                top: 8,
                left: 8,
                child: const _LiveBadge(),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        _LiveValidators.formatCount(viewers),
                        style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.88)],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ThixPolicy.labelStyle.copyWith(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: shopAvatar != null
                                  ? _NetworkImage(shopAvatar, iconSize: 10)
                                  : Container(
                                      color: ThixPolicy.primary,
                                      child: const Icon(Icons.store_rounded, size: 10, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              shopName,
                              style: ThixPolicy.microStyle.copyWith(color: Colors.white70, fontSize: 10.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Carte Enchère
class _AuctionCard extends StatelessWidget {
  final Map<String, dynamic> auction;

  const _AuctionCard({required this.auction});

  @override
  Widget build(BuildContext context) {
    final id = auction['id']?.toString() ?? '';
    final imageUrl = _LiveValidators.sanitizeUrl(auction['image_url']?.toString());
    final title = _LiveValidators.sanitize(auction['title']?.toString() ?? 'Enchère', maxLength: 80);
    final bidsCount = _LiveValidators.safeInt(auction['bids_count']);
    final currentPrice = _LiveValidators.safePrice(auction['current_price']);
    final currency = _LiveValidators.sanitize(auction['currency']?.toString() ?? 'FC', maxLength: 5);

    DateTime endTime;
    try {
      endTime = auction['end_time'] != null
          ? DateTime.parse(auction['end_time'].toString())
          : DateTime.now().add(const Duration(hours: 2));
    } catch (_) {
      endTime = DateTime.now().add(const Duration(hours: 2));
    }
    final isEnded = endTime.isBefore(DateTime.now());

    return Semantics(
      button: true,
      label: 'Enchère "$title", prix actuel $currentPrice $currency, '
          '${isEnded ? "clôturée" : "en cours"}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: InkWell(
          onTap: () {
            if (!_LiveValidators.isValidId(id)) return;
            HapticFeedback.selectionClick();
            context.push('/market/auction/$id');
            debugPrint('[Live] 🔨 Open auction $id');
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: _NetworkImage(imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ThixPolicy.labelStyle.copyWith(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                          fontSize: 13.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$bidsCount enchères',
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prix actuel',
                                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 9.5),
                              ),
                              Text(
                                '$currentPrice $currency',
                                style: ThixPolicy.labelStyle.copyWith(
                                  color: ThixPolicy.gold,
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isEnded ? 'Terminée' : 'Temps restant',
                                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 9.5),
                              ),
                              const SizedBox(height: 2),
                              isEnded
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'CLÔTURÉE',
                                        style: ThixPolicy.microStyle.copyWith(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: ThixPolicy.bold,
                                        ),
                                      ),
                                    )
                                  : _CountdownTimer(
                                      endTime: endTime,
                                      activeColor: ThixPolicy.gold,
                                      urgentColor: ThixPolicy.danger,
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte Mes Lives
class _MyLiveCard extends StatelessWidget {
  final Map<String, dynamic> live;

  const _MyLiveCard({required this.live});

  @override
  Widget build(BuildContext context) {
    final id = live['id']?.toString() ?? '';
    final thumbnail = _LiveValidators.sanitizeUrl(live['thumbnail']?.toString());
    final title = _LiveValidators.sanitize(live['title']?.toString() ?? 'Live', maxLength: 80);
    final viewers = _LiveValidators.safeInt(live['viewers']);
    final productsSold = _LiveValidators.safeInt(live['products_sold']);
    final status = live['status']?.toString() ?? 'ended';
    final isLive = status == 'live';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive ? ThixPolicy.danger.withOpacity(0.5) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: _NetworkImage(thumbnail, iconSize: 24, icon: Icons.live_tv_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ThixPolicy.labelStyle.copyWith(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$viewers vues · $productsSold vendus',
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (isLive) const _LiveBadge(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: isLive ? 'Rejoindre le live' : 'Voir le replay',
                    child: OutlinedButton(
                      onPressed: () {
                        if (!_LiveValidators.isValidId(id)) return;
                        HapticFeedback.selectionClick();
                        final route = isLive ? '/market/live/$id' : '/market/live/$id/replay';
                        context.push(route);
                        debugPrint('[Live] ${isLive ? "▶️ Join" : "⏪ Replay"} $id');
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      child: Text(isLive ? 'Rejoindre' : 'Replay'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Statistiques du live',
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_LiveValidators.isValidId(id)) return;
                        HapticFeedback.selectionClick();
                        context.push('/market/live/$id/stats');
                        debugPrint('[Live] 📊 Stats $id');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.gold,
                        foregroundColor: ThixPolicy.inkDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      child: const Text('Statistiques', style: TextStyle(fontWeight: ThixPolicy.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state premium (dark mode)
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: ThixPolicy.h3Style.copyWith(
                color: Colors.white,
                fontSize: 17,
                fontWeight: ThixPolicy.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Semantics(
              button: true,
              label: buttonText,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onPressed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.gold,
                  foregroundColor: ThixPolicy.inkDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                ),
                child: Text(buttonText, style: const TextStyle(fontWeight: ThixPolicy.bold, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton pour grid de lives
class _SkeletonLiveGrid extends StatelessWidget {
  const _SkeletonLiveGrid();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Featured placeholder
        SliverToBoxAdapter(
          child: Container(
            height: 360,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        // Grid placeholder
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton pour listes
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 180, color: Colors.white.withOpacity(0.08)),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 100, color: Colors.white.withOpacity(0.08)),
                  const SizedBox(height: 8),
                  Container(height: 16, width: 80, color: Colors.white.withOpacity(0.08)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
