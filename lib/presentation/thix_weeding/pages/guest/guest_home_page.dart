// lib/presentation/thix_weeding/pages/guest/guest_home_page.dart
// ============================================================================
// THIX WEDDING — ACCUEIL INVITÉ (PRODUCTION v2)
// ✅ Entête verre dépoli + photo plein écran + feuille blanche arrondie
// ✅ Synchronisé en direct avec le staff (mariage, invité, table, places, annonces)
// ✅ Carte "Ma place" + état de l'invitation (désactivée = bannière)
// ✅ Nouveaux boutons : Menu, Playlist, Ma table, Navette, Dress code
// ✅ Design premium rose + glassflou
// ============================================================================
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        Supabase,
        RealtimeChannel,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType;

import '../../core/failure.dart';
import '../../providers/wedding_provider.dart';
import '../../providers/countdown_provider.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../domain/entities/wedding_entity.dart';
import '../staff/providers/thix_weeding_providers.dart';
import '../staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

part 'guest_home_page.g.dart';

// ============================================================
// PALETTE — Charte THIX WEDDING (rose premium / verre dépoli)
// ============================================================
class _P {
  static const bg = Color(0xFFFFFBFC);
  static const surface = Colors.white;
  static const primary = Color(0xFFD81B60);
  static const primaryDark = Color(0xFFAD1457);
  static const primarySoft = Color(0xFFFCE4EC);
  static const rosePale = Color(0xFFFFF5F8);
  static const accent = Color(0xFFD4AF37);
  static const accentSoft = Color(0xFFFDF6E3);

  static const ink = Color(0xFF241521);
  static const inkSoft = Color(0xFF8A7580);
  static const border = Color(0xFFF3E1E6);
  static const green = Color(0xFF059669);

  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE91E78), Color(0xFFC2185B)],
  );

  static final shadow = [
    BoxShadow(
      color: const Color(0xFFD81B60).withOpacity(0.10),
      blurRadius: 18,
      offset: const Offset(0, 8),
    )
  ];
}

// ============================================================
// MODELE DES TUILES DU MENU INVITÉ
// ============================================================
enum _BadgeType { none, alert, count, live }

class _GuestMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final _BadgeType badgeType;

  const _GuestMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.badgeType = _BadgeType.none,
  });
}

// 16 boutons = 4 lignes de 4
const List<_GuestMenuItem> _kGuestMenu = [
  _GuestMenuItem(title: 'Invitation', subtitle: 'Votre carte & QR code', icon: Icons.mail_outline_rounded, route: 'invitation'),
  _GuestMenuItem(title: 'Programme', subtitle: 'Déroulé de la journée', icon: Icons.event_note_outlined, route: 'programme'),
  _GuestMenuItem(title: 'Lieu & Accès', subtitle: 'Itinéraire & infos', icon: Icons.location_on_outlined, route: 'lieu'),
  _GuestMenuItem(title: 'RSVP', subtitle: 'Confirmer votre présence', icon: Icons.people_alt_outlined, route: 'rsvp', badgeType: _BadgeType.alert),
  _GuestMenuItem(title: 'Menu', subtitle: 'Repas & boissons', icon: Icons.restaurant_menu_rounded, route: 'menu'),
  _GuestMenuItem(title: 'Playlist', subtitle: 'Proposer vos titres', icon: Icons.queue_music_rounded, route: 'playlist'),
  _GuestMenuItem(title: 'Ma table', subtitle: 'Votre table & voisins', icon: Icons.table_restaurant_outlined, route: 'ma-table'),
  _GuestMenuItem(title: 'Cadeaux', subtitle: 'Voir & contribuer', icon: Icons.card_giftcard_outlined, route: 'cadeaux'),
  _GuestMenuItem(title: 'Galerie', subtitle: 'Photos & vidéos', icon: Icons.photo_library_outlined, route: 'galerie'),
  _GuestMenuItem(title: 'Livre d\'or', subtitle: 'Laisser un message', icon: Icons.menu_book_outlined, route: 'livre-or'),
  _GuestMenuItem(title: 'Live', subtitle: 'Suivre en direct', icon: Icons.podcasts_outlined, route: 'live', badgeType: _BadgeType.live),
  _GuestMenuItem(title: 'Annonces', subtitle: 'Infos importantes', icon: Icons.campaign_outlined, route: 'annonces', badgeType: _BadgeType.count),
  _GuestMenuItem(title: 'Navette', subtitle: 'Transport & horaires', icon: Icons.directions_bus_outlined, route: 'navette'),
  _GuestMenuItem(title: 'Dress code', subtitle: 'Tenue souhaitée', icon: Icons.checkroom_outlined, route: 'dress-code'),
  _GuestMenuItem(title: 'FAQ', subtitle: 'Vos questions', icon: Icons.help_outline_rounded, route: 'faq'),
  _GuestMenuItem(title: 'Plus', subtitle: 'Autres options', icon: Icons.grid_view_rounded, route: 'plus'),
];

// Rubriques supplémentaires (feuille « Plus »)
const List<_GuestMenuItem> _kExtraMenu = [
  _GuestMenuItem(title: 'Remerciements', subtitle: 'Un mot pour vous', icon: Icons.volunteer_activism_outlined, route: 'remerciements'),
  _GuestMenuItem(title: 'Prestataires', subtitle: 'Ceux qui font la fête', icon: Icons.storefront_outlined, route: 'prestataires'),
];

// ============================================================
// PROVIDERS COMPLEMENTAIRES (SYNCHRONISES BACKEND / STAFF)
// ============================================================
@riverpod
Future<Map<String, int>> guestEventStats(GuestEventStatsRef ref, String weddingId) async {
  final guests = await ref.watch(guestsProvider(weddingId).future);
  final gallery = await ref.watch(galleryProvider(weddingId).future);
  final repo = ref.read(weddingRepositoryProvider);
  final gifts = await repo.getGifts(weddingId);

  final confirmed = guests.where((g) => g.rsvpStatus.toLowerCase() == 'yes' || g.rsvpStatus.toLowerCase() == 'confirmed').length;
  final pending = guests.where((g) => g.rsvpStatus.toLowerCase() == 'pending' || g.rsvpStatus.toLowerCase() == 'waiting').length;
  final giftsReceived = gifts.where((g) => g.isReserved).length;
  final photosShared = gallery.length;

  return {
    'Invités confirmés': confirmed,
    'En attente': pending,
    'Cadeaux reçus': giftsReceived,
    'Photos partagées': photosShared,
  };
}

@riverpod
Future<List<VendorModel>> guestVendors(GuestVendorsRef ref, String weddingId) async {
  return ref.watch(vendorsProvider(weddingId).future);
}

@riverpod
Future<List<MessageModel>> guestUpdates(GuestUpdatesRef ref, String weddingId) async {
  final messages = await ref.watch(messagesProvider(weddingId).future);
  // On ne remonte que les communications officielles de l'organisation (staff)
  return messages.where((m) => m.senderType.toLowerCase() == 'staff').toList();
}

// ============================================================
// PAGE
// ============================================================
class GuestHomePage extends ConsumerStatefulWidget {
  final String weddingId;
  const GuestHomePage({super.key, required this.weddingId});

  @override
  ConsumerState<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends ConsumerState<GuestHomePage> {
  final _scroll = ScrollController();

  // Invité connecté (lié au compte)
  Map<String, dynamic>? _guest;
  String _hallLabel = '';
  List<int> _seats = [];

  // Temps réel
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadGuest();
    _subscribe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    _scroll.dispose();
    super.dispose();
  }

  // ───────────────────────── DONNÉES INVITÉ ─────────────────────────
  Future<void> _loadGuest() async {
    try {
      final supa = Supabase.instance.client;
      final user = supa.auth.currentUser;
      if (user == null) return;
      final g = await supa
          .from('thix_weeding_guests')
          .select(
              'id, name, guests_count, is_vip, group_name, table_number, hall_table_id, seat_indices, invitation_active, rsvp_status')
          .eq('wedding_id', widget.weddingId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (g == null) {
        if (mounted) setState(() => _guest = null);
        return;
      }
      final guest = Map<String, dynamic>.from(g);
      var label = '';
      final hid = guest['hall_table_id'];
      if (hid != null) {
        final t = await supa
            .from('thix_weeding_hall_items')
            .select('label')
            .eq('id', hid)
            .maybeSingle();
        label = (t?['label'] as String?) ?? '';
      }
      final seats = ((guest['seat_indices'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _guest = guest;
        _hallLabel = label;
        _seats = seats;
      });
    } catch (_) {
      // on garde l'affichage actuel
    }
  }

  void _subscribe() {
    final supa = Supabase.instance.client;
    PostgresChangeFilter byWedding(String col) => PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: col,
          value: widget.weddingId,
        );
    _channel = supa
        .channel('guest-home-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_weddings',
          filter: byWedding('id'),
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_guests',
          filter: byWedding('wedding_id'),
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_hall_items',
          filter: byWedding('wedding_id'),
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_messages',
          filter: byWedding('wedding_id'),
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _invalidateAll();
      _loadGuest();
    });
  }

  void _invalidateAll() {
    final id = widget.weddingId;
    ref.invalidate(guestWeddingProvider(id));
    ref.invalidate(guestEventStatsProvider(id));
    ref.invalidate(guestVendorsProvider(id));
    ref.invalidate(guestUpdatesProvider(id));
    ref.invalidate(guestsProvider(id));
    ref.invalidate(messagesProvider(id));
  }

  Future<void> _onRefresh() async {
    _invalidateAll();
    await _loadGuest();
    await ref.read(guestWeddingProvider(widget.weddingId).future);
  }

  // ───────────────────────── GETTERS ─────────────────────────
  bool get _invitationActive => _guest == null || _guest!['invitation_active'] != false;

  bool get _rsvpPending {
    final s = ((_guest?['rsvp_status'] as String?) ?? '').toLowerCase();
    return s.isEmpty || s == 'pending' || s == 'waiting';
  }

  String get _firstName {
    final n = ((_guest?['name'] as String?) ?? '').trim();
    if (n.isEmpty) return 'Invité(e)';
    return n.split(' ').first;
  }

  String get _tableName {
    if (_hallLabel.isNotEmpty) return _hallLabel;
    final tn = _guest?['table_number'];
    return tn != null ? 'Table $tn' : '';
  }

  void _go(String route) {
    HapticFeedback.selectionClick();
    if (route == 'plus') {
      _openMore();
      return;
    }
    context.push('/thix-weeding/guest/${widget.weddingId}/$route');
  }

  // ───────────────────────── SHEETS ─────────────────────────
  void _openMore() {
    final all = [..._kGuestMenu.where((e) => e.route != 'plus'), ..._kExtraMenu];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.78),
          child: ThixGlass(
            radius: 30,
            opacity: 0.72,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _P.inkSoft.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Toutes les rubriques',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: _P.ink)),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: all.length,
                    itemBuilder: (_, i) {
                      final it = all[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: _P.primarySoft, shape: BoxShape.circle),
                          child: Icon(it.icon, color: _P.primary, size: 22),
                        ),
                        title: Text(it.title,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _P.ink, fontSize: 14)),
                        subtitle: Text(it.subtitle,
                            style: GoogleFonts.inter(fontSize: 11.5, color: _P.inkSoft)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: _P.primary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _go(it.route);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(dynamic item) {
    String title = 'Information';
    String subtitle = '';
    String body = '';
    IconData icon = Icons.info_outline_rounded;
    if (item is VendorModel) {
      title = item.name;
      subtitle = item.category;
      body = item.contactName ?? 'Contact à venir';
      icon = Icons.storefront_outlined;
    } else if (item is MessageModel) {
      title = 'Annonce officielle';
      subtitle = item.senderName;
      body = item.content.replaceAll(RegExp(r'^\[[A-Z0-9\s]+\]\s*'), '');
      icon = Icons.campaign_outlined;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: ThixGlass(
          radius: 28,
          opacity: 0.72,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
                        if (subtitle.isNotEmpty)
                          Text(subtitle,
                              style: GoogleFonts.inter(fontSize: 12, color: _P.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(body, style: GoogleFonts.inter(fontSize: 14, color: _P.ink, height: 1.45)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(guestWeddingProvider(widget.weddingId));
    final statsAsync = ref.watch(guestStatsAsync);
    final vendorsAsync = ref.watch(guestVendorsProvider(widget.weddingId));
    final updatesAsync = ref.watch(guestUpdatesProvider(widget.weddingId));
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _P.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: weddingAsync.when(
              data: (wedding) {
                final countdown = ref.watch(countdownProvider(wedding.date)).value;
                return _content(
                  wedding: wedding,
                  countdown: countdown,
                  statsAsync: statsAsync,
                  vendorsAsync: vendorsAsync,
                  updatesAsync: updatesAsync,
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary),
              ),
              error: (e, _) => Center(child: _ErrorView(error: e, onRetry: _invalidateAll)),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _glassHeader(context)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottom,
            child: _GlassNav(
              onHome: () => _scroll.animateTo(0,
                  duration: const Duration(milliseconds: 380), curve: Curves.easeOut),
              onAgenda: () => _go('programme'),
              onHeart: () => _go('invitation'),
              onMessages: () => _go('annonces'),
              onProfile: _openMore,
            ),
          ),
        ],
      ),
    );
  }

  ProviderListenable<AsyncValue<Map<String, int>>> get guestStatsAsync =>
      guestEventStatsProvider(widget.weddingId);

  // ───────────────────────── ENTÊTE VERRE DÉPOLI ─────────────────────────
  Widget _glassHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.38),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.75), width: 1.2),
            ),
          ),
          child: SizedBox(
            height: 74,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _P.gradPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _P.primary.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'THIX WEDDING',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      color: const Color(0xFF3B3B44).withOpacity(0.68),
                    ),
                  ),
                ),
                _GlassCircleBtn(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Langue : Français (autres langues bientôt)'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.language_rounded, size: 15, color: _P.primary),
                      Text('FR',
                          style: GoogleFonts.inter(
                              fontSize: 8.5, fontWeight: FontWeight.w900, color: _P.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _GlassCircleBtn(
                  onTap: _openMore,
                  child: const Icon(Icons.menu_rounded, size: 21, color: _P.primary),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── CONTENU ─────────────────────────
  Widget _content({
    required WeddingEntity wedding,
    required CountdownState? countdown,
    required AsyncValue<Map<String, int>> statsAsync,
    required AsyncValue<List<VendorModel>> vendorsAsync,
    required AsyncValue<List<MessageModel>> updatesAsync,
  }) {
    final mq = MediaQuery.of(context);
    final headerH = mq.padding.top + 74;
    final contentH = (mq.size.height * 0.52).clamp(400.0, 540.0).toDouble();
    final photoH = contentH + 44;
    final annCount = updatesAsync.value?.length ?? 0;

    return Stack(
      children: [
        // PHOTO PLEIN ÉCRAN (fixe)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: photoH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                wedding.coverImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(gradient: _P.gradPrimary),
                  child: Center(
                    child: Icon(Icons.favorite, size: 90, color: Colors.white.withOpacity(0.2)),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.10),
                      Colors.transparent,
                      const Color(0xFF3A0A18).withOpacity(0.55),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),

        // CONTENU QUI DÉFILE
        RefreshIndicator(
          color: _P.primary,
          edgeOffset: headerH,
          onRefresh: _onRefresh,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: contentH,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, headerH + 12, 18, 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GreetingChip(
                        name: _firstName,
                        vip: _guest?['is_vip'] == true,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        wedding.coupleNames,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 34,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.35), blurRadius: 14)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        wedding.welcomeMessage,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.35), blurRadius: 10)],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CountdownCard(state: countdown),
                    ],
                  ),
                ),
              ),

              // FEUILLE BLANCHE ARRONDIE
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, _P.rosePale],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 26,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(16, 26, 16, 130 + mq.padding.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_invitationActive) ...[
                      _DisabledBanner(),
                      const SizedBox(height: 16),
                    ],
                    _placeCard(),
                    if (_guest != null) const SizedBox(height: 26),

                    const _SectionHeader(title: 'En un coup d\'œil'),
                    const SizedBox(height: 14),
                    statsAsync.when(
                      data: (stats) => _StatsRow(stats: stats),
                      loading: () => const SizedBox(height: 96),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 28),
                    const _SectionHeader(title: 'Toutes les rubriques'),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _kGuestMenu.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (context, index) {
                        final item = _kGuestMenu[index];
                        var type = item.badgeType;
                        int? count;
                        if (item.route == 'rsvp') {
                          type = _rsvpPending ? _BadgeType.alert : _BadgeType.none;
                        } else if (item.route == 'annonces') {
                          count = annCount;
                          type = annCount > 0 ? _BadgeType.count : _BadgeType.none;
                        }
                        return _GuestMenuTile(
                          item: item,
                          badge: type,
                          badgeCount: count,
                          onTap: () => _go(item.route),
                        );
                      },
                    ),

                    const SizedBox(height: 28),
                    const _SectionHeader(title: 'Nos prestataires'),
                    const SizedBox(height: 14),
                    vendorsAsync.when(
                      data: (vendors) => _VendorsList(vendors: vendors, onTap: _showDetail),
                      loading: () => const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary)),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 28),
                    const _SectionHeader(title: 'Infos pratiques & Annonces'),
                    const SizedBox(height: 14),
                    updatesAsync.when(
                      data: (items) => _UpdatesList(items: items, onTap: _showDetail),
                      loading: () => const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary)),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),

                    if (wedding.hasAnnouncement) ...[
                      const SizedBox(height: 22),
                      _NewsBanner(text: wedding.announcement),
                    ],

                    const SizedBox(height: 24),
                    _HelpCard(onTap: () => _go('faq')),
                    const SizedBox(height: 20),
                    const _TrustRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── CARTE "MA PLACE" ─────────────────────────
  Widget _placeCard() {
    final g = _guest;
    if (g == null || !_invitationActive) return const SizedBox.shrink();
    final has = _tableName.isNotEmpty;
    final persons = (g['guests_count'] as num?)?.toInt() ?? 1;
    return ThixGlass(
      radius: 26,
      opacity: 0.55,
      borderColor: _P.primary.withOpacity(0.22),
      padding: const EdgeInsets.all(16),
      onTap: () => _go('invitation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: _P.gradPrimary,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: _P.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5)),
                  ],
                ),
                child: const Icon(Icons.event_seat_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VOTRE PLACE',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: _P.inkSoft)),
                    const SizedBox(height: 2),
                    Text(
                      has ? _tableName : 'En cours d\'attribution',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
                    ),
                    Text('$persons personne${persons > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 11.5, color: _P.inkSoft)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _P.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 18, color: _P.primary),
                    const SizedBox(width: 4),
                    Text('QR',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w900, color: _P.primary)),
                  ],
                ),
              ),
            ],
          ),
          if (has && _seats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _seats
                  .map((s) => Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: _P.primary, width: 2),
                          boxShadow: [
                            BoxShadow(color: _P.primary.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Text('${s + 1}',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900, fontSize: 14, color: _P.primary)),
                      ))
                  .toList(),
            ),
          ] else if (!has)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Votre table et votre place apparaîtront ici dès que les mariés les auront choisies.',
                style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PETITS WIDGETS D'ENTÊTE
// ============================================================
class _GlassCircleBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassCircleBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
          boxShadow: _P.shadow,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _GreetingChip extends StatelessWidget {
  final String name;
  final bool vip;
  const _GreetingChip({required this.name, required this.vip});

  @override
  Widget build(BuildContext context) {
    return ThixGlass(
      radius: 22,
      blur: 14,
      opacity: 0.26,
      borderColor: Colors.white.withOpacity(0.55),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👋', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Bonjour $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          if (vip) ...[
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded, size: 16, color: _P.accent),
          ],
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final CountdownState? state;
  const _CountdownCard({this.state});

  @override
  Widget build(BuildContext context) {
    if (state == null) return const SizedBox(height: 84);
    return ThixGlass(
      radius: 24,
      blur: 18,
      opacity: 0.40,
      borderColor: Colors.white.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JOUR J DANS',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _P.ink.withOpacity(0.7),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _CountItem(value: state!.days, label: 'Jours'),
                    _CountItem(value: state!.hours, label: 'Heures'),
                    _CountItem(value: state!.minutes, label: 'Min'),
                    _CountItem(value: state!.seconds, label: 'Sec'),
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

class _CountItem extends StatelessWidget {
  final int value;
  final String label;
  const _CountItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: _P.primaryDark)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 9.5, color: _P.ink.withOpacity(0.65), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800, fontSize: 18, color: _P.ink, letterSpacing: -0.3)),
      ],
    );
  }
}

// ============================================================
// BANNIÈRE INVITATION DÉSACTIVÉE
// ============================================================
class _DisabledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ThixGlass(
      radius: 22,
      tint: const Color(0xFFFFE4E8),
      borderColor: _P.primary.withOpacity(0.45),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: _P.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invitation désactivée',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _P.primary, fontSize: 14)),
                Text(
                  'Votre QR code n\'est plus valide. Contactez les mariés pour plus d\'informations.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: _P.inkSoft, height: 1.35),
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
// STATS ROW
// ============================================================
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  IconData _icon(String k) {
    final s = k.toLowerCase();
    if (s.contains('confirm')) return Icons.how_to_reg_rounded;
    if (s.contains('attente')) return Icons.hourglass_top_rounded;
    if (s.contains('cadeau')) return Icons.card_giftcard_rounded;
    return Icons.photo_camera_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final entries = stats.entries.toList();
    return Row(
      children: List.generate(entries.length, (i) {
        final e = entries[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == entries.length - 1 ? 0 : 8),
            child: ThixGlass(
              radius: 20,
              opacity: 0.55,
              borderColor: _P.primary.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Column(
                children: [
                  Icon(_icon(e.key), size: 18, color: _P.primary.withOpacity(0.75)),
                  const SizedBox(height: 6),
                  Text('${e.value}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 19, color: _P.primary)),
                  const SizedBox(height: 4),
                  Text(
                    e.key.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        color: _P.inkSoft,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 0.4),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================
// TUILE DE MENU — bouton rond premium
// ============================================================
class _GuestMenuTile extends StatelessWidget {
  final _GuestMenuItem item;
  final _BadgeType badge;
  final int? badgeCount;
  final VoidCallback onTap;
  const _GuestMenuTile({
    required this.item,
    required this.badge,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFFFEFF4)],
                  ),
                  border: Border.all(color: Colors.white, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: _P.primary.withOpacity(0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: _P.primary, size: 27),
              ),
              if (badge == _BadgeType.alert)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: _DotBadge(child: Text('!', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800))),
                ),
              if (badge == _BadgeType.count)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _DotBadge(
                    child: Text('${badgeCount ?? 0}',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              if (badge == _BadgeType.live)
                Positioned(
                  top: -4,
                  right: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('LIVE',
                        style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: _P.ink, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _DotBadge extends StatelessWidget {
  final Widget child;
  const _DotBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 19,
      height: 19,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _P.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child: child,
    );
  }
}

// ============================================================
// NOS PRESTATAIRES
// ============================================================
class _VendorsList extends StatelessWidget {
  final List<VendorModel> vendors;
  final void Function(dynamic) onTap;
  const _VendorsList({required this.vendors, required this.onTap});

  IconData _vendorIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('salle') || c.contains('lieu')) return Icons.villa_outlined;
    if (c.contains('traiteur') || c.contains('restau')) return Icons.restaurant_outlined;
    if (c.contains('photo') || c.contains('video')) return Icons.camera_alt_outlined;
    if (c.contains('deco') || c.contains('fleur')) return Icons.local_florist_outlined;
    if (c.contains('musique') || c.contains('dj')) return Icons.music_note_outlined;
    if (c.contains('robe') || c.contains('tenue')) return Icons.checkroom_outlined;
    return Icons.store_outlined;
  }

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return SizedBox(
        height: 110,
        child: Center(
          child: Text('Aucun prestataire enregistré',
              style: GoogleFonts.inter(color: _P.inkSoft)),
        ),
      );
    }
    return SizedBox(
      height: 222,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final v = vendors[i];
          return InkWell(
            onTap: () => onTap(v),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 172,
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: _P.shadow,
                border: Border.all(color: _P.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 110,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: _P.gradPrimary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                          ),
                          child: Center(child: Icon(_vendorIcon(v.category), size: 38, color: Colors.white54)),
                        ),
                        if (v.isBooked)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: ThixGlass(
                              radius: 10,
                              blur: 10,
                              opacity: 0.55,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 12, color: _P.green),
                                  const SizedBox(width: 4),
                                  Text('Réservé',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.ink)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 2),
                        Text(v.category,
                            style: GoogleFonts.inter(fontSize: 11, color: _P.primary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 12, color: _P.inkSoft),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(v.contactName ?? 'Contact à venir',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// INFOS PRATIQUES / ANNONCES
// ============================================================
class _UpdatesList extends StatelessWidget {
  final List<MessageModel> items;
  final void Function(dynamic) onTap;
  const _UpdatesList({required this.items, required this.onTap});

  IconData _messageIcon(String content) {
    final c = content.toLowerCase();
    if (c.contains('parking')) return Icons.local_parking_outlined;
    if (c.contains('tenue') || c.contains('dress')) return Icons.checkroom_outlined;
    if (c.contains('transport') || c.contains('navette')) return Icons.directions_bus_outlined;
    if (c.contains('urgent') || c.contains('important')) return Icons.warning_amber_rounded;
    return Icons.campaign_outlined;
  }

  String _extractTag(String content) {
    final match = RegExp(r'^\[([A-Z0-9\s]+)\]').firstMatch(content);
    if (match != null) return match.group(1)!.trim();
    final c = content.toLowerCase();
    if (c.contains('parking')) return 'PARKING';
    if (c.contains('tenue') || c.contains('dress')) return 'DRESS CODE';
    if (c.contains('transport')) return 'TRANSPORT';
    if (c.contains('urgent')) return 'URGENT';
    return 'INFO';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: 90,
        child: Center(
          child: Text('Aucune annonce pour le moment',
              style: GoogleFonts.inter(color: _P.inkSoft)),
        ),
      );
    }
    return SizedBox(
      height: 168,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final a = items[i];
          final tag = _extractTag(a.content);
          return InkWell(
            onTap: () => onTap(a),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 156,
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: _P.shadow,
                border: Border.all(color: _P.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 78,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: _P.accentSoft,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                          ),
                          child: Center(child: Icon(_messageIcon(a.content), size: 28, color: _P.accent)),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: _P.ink, borderRadius: BorderRadius.circular(6)),
                            child: Text(tag,
                                style: const TextStyle(
                                    fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.content.replaceAll(RegExp(r'^\[[A-Z0-9\s]+\]\s*'), ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink, height: 1.25),
                        ),
                        const SizedBox(height: 8),
                        Text(a.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, color: _P.primary, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// BANDEAU ANNONCE PRINCIPALE
// ============================================================
class _NewsBanner extends StatelessWidget {
  final String text;
  const _NewsBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _P.gradPrimary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _P.shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INFORMATION',
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(text,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE ROSE "BESOIN D'AIDE" (style Espace Prestataire)
// ============================================================
class _HelpCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HelpCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD81B60), Color(0xFFB0124F)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: _P.primary.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Une question ?',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Contacter les mariés',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 25, color: Colors.white, fontWeight: FontWeight.w700, height: 1.1)),
                  const SizedBox(height: 6),
                  Text('FAQ, messages et aide pour le jour J.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withOpacity(0.85))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BANDEAU DE CONFIANCE
// ============================================================
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  static const _items = [
    {'icon': Icons.favorite_border_rounded, 'label': 'Merci de\nvotre présence'},
    {'icon': Icons.lock_outline_rounded, 'label': 'Données\nprotégées'},
    {'icon': Icons.qr_code_rounded, 'label': 'Accès\nsécurisé'},
  ];

  @override
  Widget build(BuildContext context) {
    return ThixGlass(
      radius: 22,
      opacity: 0.5,
      borderColor: _P.primary.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e['icon'] as IconData, size: 22, color: _P.primary),
              const SizedBox(height: 8),
              Text(e['label'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// BARRE DE NAVIGATION FLOTTANTE EN VERRE DÉPOLI
// ============================================================
class _GlassNav extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onAgenda;
  final VoidCallback onHeart;
  final VoidCallback onMessages;
  final VoidCallback onProfile;
  const _GlassNav({
    required this.onHome,
    required this.onAgenda,
    required this.onHeart,
    required this.onMessages,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
            boxShadow: [
              BoxShadow(color: _P.primary.withOpacity(0.14), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Accueil', selected: true, onTap: onHome),
              _NavItem(icon: Icons.event_outlined, label: 'Agenda', onTap: onAgenda),
              GestureDetector(
                onTap: onHeart,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _P.gradPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _P.primary.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                ),
              ),
              _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Annonces', onTap: onMessages),
              _NavItem(icon: Icons.grid_view_rounded, label: 'Plus', onTap: onProfile),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? _P.primary : _P.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9.5, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERREUR
// ============================================================
class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
      child: ThixGlass(
        radius: 28,
        opacity: 0.55,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: _P.primary),
            const SizedBox(height: 12),
            Text(
              error is Failure ? (error as Failure).message : 'Erreur de chargement',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _P.inkSoft),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _P.primary),
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
