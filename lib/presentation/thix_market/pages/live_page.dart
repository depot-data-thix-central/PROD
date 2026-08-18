// lib/presentation/thix_market/pages/live_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:go_router/go_router.dart';
import '../providers/live_provider.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  Timer? _clockTimer;

  static const Color gold = Color(0xFFC9962C);
  static const Color navy = Color(0xFF1B2A4A);
  static const Color danger = Color(0xFFE53935);
  static const Color surface = Color(0xFF141824);
  static const Color surfaceCard = Color(0xFF1D2333);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
    // ✅ Rafraîchit l'UI chaque seconde pour faire vivre les countdowns d'enchères
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshData() async {
    final provider = context.read<LiveProvider>();
    await Future.wait([
      provider.loadLiveSessions(),
      provider.loadAuctions(),
      provider.loadMyLives(),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  Widget _networkImage(String? url, {double iconSize = 30, IconData icon = Icons.image_outlined}) {
    if (url == null || url.trim().isEmpty) {
      return Container(color: Colors.grey[850], child: Icon(icon, color: Colors.grey[600], size: iconSize));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[850],
        child: Icon(Icons.broken_image_outlined, color: Colors.grey[600], size: iconSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('THIX', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17)),
            Text(' LIVE', style: TextStyle(fontWeight: FontWeight.w800, color: gold, fontSize: 17)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En direct'),
            Tab(text: 'Enchères'),
            Tab(text: 'Mes lives'),
          ],
          indicatorColor: gold,
          indicatorWeight: 3,
          labelColor: gold,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelColor: Colors.grey[500],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _refreshData),
          IconButton(icon: const Icon(Icons.videocam_rounded, color: gold), onPressed: () => context.push('/market/live/create')),
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
      return const Center(child: CircularProgressIndicator(color: gold));
    }

    final liveSessions = provider.liveSessions;
    if (liveSessions.isEmpty) {
      return _buildEmptyState(
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
      color: gold,
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
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
                items: featuredLives.map((live) => _buildLiveCard(live, isFeatured: true)).toList(),
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
                (context, index) => _buildLiveCard(otherLives[index]),
                childCount: otherLives.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildLiveCard(Map<String, dynamic> live, {bool isFeatured = false}) {
    final thumbnail = live['thumbnail'] as String?;
    final title = (live['title'] as String?)?.trim();
    final shopName = (live['shop_name'] as String?)?.trim();
    final shopAvatar = live['shop_avatar'] as String?;
    final viewers = live['viewers'] ?? 0;
    final radius = isFeatured ? 18.0 : 14.0;

    return GestureDetector(
      onTap: () => context.push('/market/live/${live['id']}'),
      child: Container(
        margin: isFeatured ? const EdgeInsets.symmetric(horizontal: 4) : null,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), color: Colors.grey[900]),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: _networkImage(thumbnail, iconSize: 36, icon: Icons.live_tv_rounded),
            ),
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: danger, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text(_formatNumber(viewers), style: const TextStyle(color: Colors.white, fontSize: 10.5)),
                ]),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.88)]),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (title == null || title.isEmpty) ? 'Live sans titre' : title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      ClipOval(
                        child: SizedBox(
                          width: 18, height: 18,
                          child: (shopAvatar != null && shopAvatar.isNotEmpty)
                              ? _networkImage(shopAvatar, iconSize: 10)
                              : Container(color: navy, child: const Icon(Icons.store_rounded, size: 10, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          (shopName == null || shopName.isEmpty) ? 'Boutique' : shopName,
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB 2 : ENCHÈRES
  // ============================================================
  Widget _buildAuctionsTab(LiveProvider provider) {
    if (provider.isLoadingAuctions) {
      return const Center(child: CircularProgressIndicator(color: gold));
    }

    final auctions = provider.auctions;
    if (auctions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.gavel_rounded,
        title: 'Aucune enchère en cours',
        subtitle: 'Revenez plus tard pour participer',
        buttonText: 'Actualiser',
        onPressed: _refreshData,
      );
    }

    return RefreshIndicator(
      color: gold,
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: auctions.length,
        itemBuilder: (context, index) => _buildAuctionCard(auctions[index]),
      ),
    );
  }

  Widget _buildAuctionCard(Map<String, dynamic> auction) {
    final imageUrl = auction['image_url'] as String?;
    final title = (auction['title'] as String?)?.trim();
    final bidsCount = auction['bids_count'] ?? 0;
    final currentPrice = auction['current_price'] ?? 0;
    final currency = auction['currency'] ?? 'FC';

    DateTime endTime;
    try {
      endTime = auction['end_time'] != null
          ? DateTime.parse(auction['end_time'])
          : DateTime.now().add(const Duration(hours: 2));
    } catch (_) {
      endTime = DateTime.now().add(const Duration(hours: 2));
    }
    final timeLeft = endTime.difference(DateTime.now());
    final isEnded = timeLeft.isNegative;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: InkWell(
        onTap: () => context.push('/market/auction/${auction['id']}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 78, height: 78, child: _networkImage(imageUrl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (title == null || title.isEmpty) ? 'Enchère' : title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('$bidsCount enchères', style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prix actuel', style: TextStyle(color: Colors.grey[500], fontSize: 9.5)),
                            Text('$currentPrice $currency', style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 13.5)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(isEnded ? 'Terminée' : 'Temps restant', style: TextStyle(color: Colors.grey[500], fontSize: 9.5)),
                            isEnded
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(5)),
                                    child: const Text('CLÔTURÉE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                : _buildCountdownTimer(timeLeft),
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
    );
  }

  Widget _buildCountdownTimer(Duration duration) {
    final hours = duration.inHours.clamp(0, 99);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final urgent = duration.inMinutes < 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(5)),
      child: Text(
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        style: TextStyle(color: urgent ? danger : gold, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  // ============================================================
  // TAB 3 : MES LIVES
  // ============================================================
  Widget _buildMyLivesTab(LiveProvider provider) {
    if (provider.isLoadingMyLives) {
      return const Center(child: CircularProgressIndicator(color: gold));
    }

    final myLives = provider.myLives;
    if (myLives.isEmpty) {
      return _buildEmptyState(
        icon: Icons.videocam_off_rounded,
        title: 'Aucun live',
        subtitle: 'Créez votre premier live pour vendre en direct',
        buttonText: 'Créer un live',
        onPressed: () => context.push('/market/live/create'),
      );
    }

    return RefreshIndicator(
      color: gold,
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: myLives.length,
        itemBuilder: (context, index) => _buildMyLiveCard(myLives[index]),
      ),
    );
  }

  Widget _buildMyLiveCard(Map<String, dynamic> live) {
    final thumbnail = live['thumbnail'] as String?;
    final title = (live['title'] as String?)?.trim();
    final viewers = live['viewers'] ?? 0;
    final productsSold = live['products_sold'] ?? 0;
    final status = live['status'] ?? 'ended';
    final isLive = status == 'live';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLive ? danger.withOpacity(0.5) : Colors.grey[850]!),
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
                  child: SizedBox(width: 58, height: 58, child: _networkImage(thumbnail, iconSize: 24, icon: Icons.live_tv_rounded)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (title == null || title.isEmpty) ? 'Live' : title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('$viewers vues · $productsSold vendus', style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
                    ],
                  ),
                ),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: danger, borderRadius: BorderRadius.circular(5)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(isLive ? '/market/live/${live['id']}' : '/market/live/${live['id']}/replay'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[700]!),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: Text(isLive ? 'Rejoindre' : 'Replay'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/market/live/${live['id']}/stats'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: navy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const Text('Statistiques', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================
  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toString();
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            ),
            child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
