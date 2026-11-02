// lib/presentation/thix_weeding/pages/guest/guest_home_page.dart
// ============================================================================
// THIX WEDDING — ACCUEIL INVITÉ (PRODUCTION v4)
// ✅ Hero : 6 premières photos de la galerie, défilement automatique permanent
// ✅ Tout est compact (rien ne déborde) — feuilles de détail défilables
// ✅ « En un coup d'œil » supprimé → bande « Photos du mariage »
// ✅ Infos pratiques = uniquement ce que le staff PUBLIE (photos, tag, titre)
// ✅ Message d'invitation / table / place : visibles seulement par l'invité concerné
// ✅ Cartes infos & prestataires avec photos
// ✅ Temps réel (mariage, invité, table, messages) + verre dépoli
// ✅ MENU : lien vers préférences repas avec badge compteur de plats
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
import 'package:thix_id/presentation/thix_weeding/pages/staff/messages/message_media.dart';

part 'guest_home_page.g.dart';

// ============================================================
// PALETTE
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
      blurRadius: 14,
      offset: const Offset(0, 6),
    )
  ];
}

// ============================================================
// MENU
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

const List<_GuestMenuItem> _kGuestMenu = [
  _GuestMenuItem(title: 'Invitation', subtitle: 'Votre carte & QR code', icon: Icons.mail_outline_rounded, route: 'invitation'),
  _GuestMenuItem(title: 'Programme', subtitle: 'Déroulé de la journée', icon: Icons.event_note_outlined, route: 'programme'),
  _GuestMenuItem(title: 'Lieu & Accès', subtitle: 'Itinéraire & infos', icon: Icons.location_on_outlined, route: 'lieu'),
  _GuestMenuItem(title: 'RSVP', subtitle: 'Confirmer votre présence', icon: Icons.people_alt_outlined, route: 'rsvp', badgeType: _BadgeType.alert),
  // ✅ MODIFIÉ : route vers meal-preferences + badge compteur
  _GuestMenuItem(title: 'Menu', subtitle: 'Choisir mes plats', icon: Icons.restaurant_menu_rounded, route: 'meal-preferences', badgeType: _BadgeType.count),
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

const List<_GuestMenuItem> _kExtraMenu = [
  _GuestMenuItem(title: 'Remerciements', subtitle: 'Un mot pour vous', icon: Icons.volunteer_activism_outlined, route: 'remerciements'),
  _GuestMenuItem(title: 'Prestataires', subtitle: 'Ceux qui font la fête', icon: Icons.storefront_outlined, route: 'prestataires'),
];

// ============================================================
// PROVIDERS GÉNÉRÉS (inchangés — nécessaires au fichier .g.dart)
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
  return messages.where((m) => m.senderType.toLowerCase() == 'staff').toList();
}

// ============================================================
// NOUVEAUX PROVIDERS (sans génération de code)
// ============================================================
class GuestAnnouncement {
  final String id;
  final String content;
  final String? title;
  final String tag;
  final String sender;
  final List<String> images;
  final DateTime? createdAt;
  final String type;

  const GuestAnnouncement({
    required this.id,
    required this.content,
    required this.title,
    required this.tag,
    required this.sender,
    required this.images,
    required this.createdAt,
    required this.type,
  });
}

/// Uniquement les informations PUBLIÉES par le staff (jamais les messages privés).
final guestAnnouncementsProvider =
    FutureProvider.autoDispose.family<List<GuestAnnouncement>, String>((ref, weddingId) async {
  try {
    final rows = await Supabase.instance.client
        .from('thix_weeding_messages')
        .select('id, content, title, tag, image_urls, sender_name, created_at, message_type')
        .eq('wedding_id', weddingId)
        .eq('is_published', true)
        .filter('guest_id', 'is', 'null')
        .order('created_at', ascending: false)
        .limit(20);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return GuestAnnouncement(
        id: '${m['id']}',
        content: '${m['content'] ?? ''}',
        title: (m['title'] as String?)?.trim().isEmpty == true ? null : m['title'] as String?,
        tag: ((m['tag'] as String?) ?? 'INFO').toUpperCase(),
        sender: '${m['sender_name'] ?? 'Les mariés'}',
        images: parseImageUrls(m['image_urls']),
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal(),
        type: '${m['message_type'] ?? 'info'}',
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Photos des prestataires (colonne photo_url), indexées par nom.
final guestVendorPhotosProvider =
    FutureProvider.autoDispose.family<Map<String, String>, String>((ref, weddingId) async {
  try {
    final rows = await Supabase.instance.client
        .from('thix_weeding_vendors')
        .select('name, photo_url')
        .eq('wedding_id', weddingId);
    final out = <String, String>{};
    for (final r in (rows as List)) {
      final n = '${r['name'] ?? ''}'.trim().toLowerCase();
      final u = '${r['photo_url'] ?? ''}';
      if (n.isNotEmpty && u.isNotEmpty && u != 'null') out[n] = u;
    }
    return out;
  } catch (_) {
    return {};
  }
});

/// ✅ NOUVEAU : Compteur de plats publics pour le badge du menu
final guestMenuCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, weddingId) async {
  try {
    final service = ref.read(menuServiceProvider);
    final items = await service.getPublicByWedding(weddingId);
    return items.length;
  } catch (_) {
    return 0;
  }
});

// ── URL d'une photo de galerie (modèle inconnu → lecture tolérante) ──
String? _galleryUrl(dynamic g) {
  final getters = <dynamic Function()>[
    () => g.url,
    () => g.imageUrl,
    () => g.photoUrl,
    () => g.mediaUrl,
    () => g.fileUrl,
    () => g.publicUrl,
    () => g.thumbnailUrl,
  ];
  for (final get in getters) {
    try {
      final v = get();
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
  }
  try {
    final m = g.toJson();
    if (m is Map) {
      for (final k in ['url', 'image_url', 'photo_url', 'media_url', 'file_url', 'public_url']) {
        final v = m[k];
        if (v is String && v.isNotEmpty) return v;
      }
    }
  } catch (_) {}
  return null;
}

bool _isVideoUrl(String u) {
  final l = u.toLowerCase().split('?').first;
  return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.webm') || l.endsWith('.avi') || l.endsWith('.mkv');
}

String _fmtShort(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

Color tagColor(String tag) {
  switch (tag.toUpperCase()) {
    case 'URGENT':
      return _P.primary;
    case 'PARKING':
    case 'TRANSPORT':
      return _P.primaryDark;
    case 'PROGRAMME':
      return const Color(0xFF6B46C1);
    case 'MENU':
      return _P.accent;
    case 'DRESS CODE':
      return const Color(0xFFE91E63);
    default:
      return const Color(0xFF0B3B8F);
  }
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

  // Invité connecté (privé : visible uniquement par lui)
  Map<String, dynamic>? _guest;
  String _hallLabel = '';
  List<int> _seats = [];
  String? _inviteMsg;

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
        if (mounted) {
          setState(() {
            _guest = null;
            _inviteMsg = null;
          });
        }
        return;
      }
      final guest = Map<String, dynamic>.from(g);
      var label = '';
      final hid = guest['hall_table_id'];
      if (hid != null) {
        final t = await supa.from('thix_weeding_hall_items').select('label').eq('id', hid).maybeSingle();
        label = (t?['label'] as String?) ?? '';
      }
      final seats = ((guest['seat_indices'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList()
        ..sort();

      // Message d'invitation PRIVÉ (seulement pour cet invité)
      String? invite;
      try {
        final m = await supa
            .from('thix_weeding_messages')
            .select('content')
            .eq('wedding_id', widget.weddingId)
            .eq('guest_id', guest['id'])
            .eq('message_type', 'invitation')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        invite = m?['content'] as String?;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _guest = guest;
        _hallLabel = label;
        _seats = seats;
        _inviteMsg = invite;
      });
    } catch (_) {}
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
    ref.invalidate(guestVendorsProvider(id));
    ref.invalidate(guestVendorPhotosProvider(id));
    ref.invalidate(guestAnnouncementsProvider(id));
    ref.invalidate(galleryProvider(id));
    ref.invalidate(guestsProvider(id));
    ref.invalidate(messagesProvider(id));
    ref.invalidate(guestMenuCountProvider(id)); // ✅ AJOUTÉ
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

  // ───────────────────────── FEUILLES (défilables) ─────────────────────────
  void _glassSheet({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.78),
          child: ThixGlass(
            radius: 28,
            opacity: 0.82,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
                      child: Icon(icon, color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Text(subtitle,
                                style: GoogleFonts.inter(fontSize: 11.5, color: _P.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            radius: 28,
            opacity: 0.82,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Toutes les rubriques',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: all.length,
                    itemBuilder: (_, i) {
                      final it = all[i];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(color: _P.primarySoft, shape: BoxShape.circle),
                          child: Icon(it.icon, color: _P.primary, size: 19),
                        ),
                        title: Text(it.title,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _P.ink, fontSize: 13)),
                        subtitle: Text(it.subtitle, style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: _P.primary, size: 20),
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

  void _showAnnouncement(GuestAnnouncement a) {
    final text = a.content == '📷 Photo' && a.images.isNotEmpty ? '' : a.content;
    _glassSheet(
      icon: Icons.campaign_outlined,
      title: a.title ?? (a.type == 'announcement' ? 'Annonce' : 'Information'),
      subtitle: '${a.tag} · ${a.sender}${a.createdAt != null ? ' · ${_fmtShort(a.createdAt)}' : ''}',
      children: [
        if (a.images.isNotEmpty) ...[
          MessageImages(urls: a.images, radius: 16),
          const SizedBox(height: 10),
        ],
        if (text.isNotEmpty)
          Text(text, style: GoogleFonts.inter(fontSize: 13.5, color: _P.ink, height: 1.5)),
        const SizedBox(height: 4),
      ],
    );
  }

  void _showVendor(VendorModel v, String? photo) {
    _glassSheet(
      icon: Icons.storefront_outlined,
      title: v.name,
      subtitle: v.category,
      children: [
        if (photo != null) ...[
          MessageImages(urls: [photo], radius: 16),
          const SizedBox(height: 10),
        ],
        Row(children: [
          const Icon(Icons.person_outline_rounded, size: 16, color: _P.inkSoft),
          const SizedBox(width: 6),
          Text(v.contactName ?? 'Contact à venir',
              style: GoogleFonts.inter(fontSize: 13, color: _P.ink, fontWeight: FontWeight.w600)),
        ]),
        if (v.isBooked) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle_rounded, size: 16, color: _P.green),
            const SizedBox(width: 6),
            Text('Réservé', style: GoogleFonts.inter(fontSize: 13, color: _P.green, fontWeight: FontWeight.w800)),
          ]),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  void _showInviteMessage() {
    final m = _inviteMsg;
    if (m == null) return;
    _glassSheet(
      icon: Icons.mail_outline_rounded,
      title: 'Mon invitation',
      subtitle: 'Message privé · visible par vous seul(e)',
      children: [
        Text(m, style: GoogleFonts.inter(fontSize: 13, color: _P.ink, height: 1.5)),
        const SizedBox(height: 4),
      ],
    );
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(guestWeddingProvider(widget.weddingId));
    final vendorsAsync = ref.watch(guestVendorsProvider(widget.weddingId));
    final vendorPhotos = ref.watch(guestVendorPhotosProvider(widget.weddingId)).value ?? const <String, String>{};
    final annAsync = ref.watch(guestAnnouncementsProvider(widget.weddingId));
    final galleryRaw = ref.watch(galleryProvider(widget.weddingId)).value;
    final menuCount = ref.watch(guestMenuCountProvider(widget.weddingId)).value ?? 0; // ✅ AJOUTÉ
    final bottom = MediaQuery.of(context).padding.bottom;

    final photos = <String>[];
    for (final g in ((galleryRaw as List?) ?? const [])) {
      final u = _galleryUrl(g);
      if (u != null && !_isVideoUrl(u)) photos.add(u);
    }

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
                  photos: photos,
                  vendorsAsync: vendorsAsync,
                  vendorPhotos: vendorPhotos,
                  annAsync: annAsync,
                  menuCount: menuCount, // ✅ AJOUTÉ
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary)),
              error: (e, _) => Center(child: _ErrorView(error: e, onRetry: _invalidateAll)),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _glassHeader(context)),
          Positioned(
            left: 18,
            right: 18,
            bottom: 10 + bottom,
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

  // ───────────────────────── ENTÊTE COMPACT ─────────────────────────
  Widget _glassHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.38),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.75), width: 1.2)),
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: _P.gradPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'THIX WEDDING',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                      color: const Color(0xFF3B3B44).withOpacity(0.75),
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
                      const Icon(Icons.language_rounded, size: 13, color: _P.primary),
                      Text('FR',
                          style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.w900, color: _P.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                _GlassCircleBtn(
                  onTap: _openMore,
                  child: const Icon(Icons.menu_rounded, size: 18, color: _P.primary),
                ),
                const SizedBox(width: 12),
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
    required List<String> photos,
    required AsyncValue<List<VendorModel>> vendorsAsync,
    required Map<String, String> vendorPhotos,
    required AsyncValue<List<GuestAnnouncement>> annAsync,
    required int menuCount, // ✅ AJOUTÉ
  }) {
    final mq = MediaQuery.of(context);
    final headerH = mq.padding.top + 56;
    final contentH = (mq.size.height * 0.44).clamp(330.0, 440.0).toDouble();
    final photoH = contentH + 30;
    final announcements = annAsync.value ?? const <GuestAnnouncement>[];
    final heroPhotos = photos.take(6).toList();

    return Stack(
      children: [
        // HERO : 6 premières photos de la galerie, défilement automatique
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: photoH,
          child: _HeroPhotos(urls: heroPhotos, fallback: wedding.coverImageUrl),
        ),

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
                  padding: EdgeInsets.fromLTRB(16, headerH + 8, 16, 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GreetingChip(name: _firstName, vip: _guest?['is_vip'] == true),
                      const SizedBox(height: 8),
                      Text(
                        wedding.coupleNames,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 14)],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        wedding.welcomeMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 10)],
                        ),
                      ),
                      const SizedBox(height: 10),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 22, offset: const Offset(0, -5))],
                ),
                padding: EdgeInsets.fromLTRB(14, 20, 14, 100 + mq.padding.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_invitationActive) ...[
                      _DisabledBanner(),
                      const SizedBox(height: 12),
                    ],
                    _placeCard(),
                    if (_guest != null) const SizedBox(height: 20),

                    const _SectionHeader(title: 'Toutes les rubriques'),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _kGuestMenu.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 6,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final item = _kGuestMenu[index];
                        var type = item.badgeType;
                        int? count;
                        if (item.route == 'rsvp') {
                          type = _rsvpPending ? _BadgeType.alert : _BadgeType.none;
                        } else if (item.route == 'annonces') {
                          count = announcements.length;
                          type = announcements.isNotEmpty ? _BadgeType.count : _BadgeType.none;
                        } else if (item.route == 'meal-preferences') {
                          // ✅ AJOUTÉ : badge pour le menu
                          count = menuCount;
                          type = menuCount > 0 ? _BadgeType.count : _BadgeType.none;
                        }
                        return _GuestMenuTile(
                          item: item,
                          badge: type,
                          badgeCount: count,
                          onTap: () => _go(item.route),
                        );
                      },
                    ),

                    if (photos.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _SectionHeader(title: 'Photos du mariage', onMore: () => _go('galerie')),
                      const SizedBox(height: 10),
                      _PhotoStrip(urls: photos.take(12).toList(), onTap: () => _go('galerie')),
                    ],

                    const SizedBox(height: 22),
                    const _SectionHeader(title: 'Nos prestataires'),
                    const SizedBox(height: 10),
                    vendorsAsync.when(
                      data: (vendors) => _VendorsList(
                        vendors: vendors,
                        photos: vendorPhotos,
                        onTap: _showVendor,
                      ),
                      loading: () => const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary)),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 22),
                    const _SectionHeader(title: 'Infos pratiques'),
                    const SizedBox(height: 10),
                    annAsync.when(
                      data: (items) => _UpdatesList(items: items, onTap: _showAnnouncement),
                      loading: () => const SizedBox(
                        height: 130,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary)),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),

                    if (wedding.hasAnnouncement) ...[
                      const SizedBox(height: 18),
                      _NewsBanner(text: wedding.announcement),
                    ],

                    const SizedBox(height: 20),
                    _HelpCard(onTap: () => _go('faq')),
                    const SizedBox(height: 16),
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

  // ───────────────────────── CARTE "MA PLACE" (privée) ─────────────────────────
  Widget _placeCard() {
    final g = _guest;
    if (g == null || !_invitationActive) return const SizedBox.shrink();
    final has = _tableName.isNotEmpty;
    final persons = (g['guests_count'] as num?)?.toInt() ?? 1;
    return ThixGlass(
      radius: 22,
      opacity: 0.55,
      borderColor: _P.primary.withOpacity(0.22),
      padding: const EdgeInsets.all(12),
      onTap: () => _go('invitation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: _P.gradPrimary,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.event_seat_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VOTRE PLACE',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _P.inkSoft)),
                    Text(
                      has ? _tableName : 'En cours d\'attribution',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink),
                    ),
                    Text('$persons personne${persons > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: _P.primarySoft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 16, color: _P.primary),
                    const SizedBox(width: 4),
                    Text('QR',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w900, color: _P.primary)),
                  ],
                ),
              ),
            ],
          ),
          if (has && _seats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _seats
                  .map((s) => Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: _P.primary, width: 1.8),
                        ),
                        child: Text('${s + 1}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: _P.primary)),
                      ))
                  .toList(),
            ),
          ] else if (!has)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Votre table et votre place apparaîtront ici dès que les mariés les auront choisies.',
                style: GoogleFonts.inter(fontSize: 11.5, color: _P.inkSoft, height: 1.35),
              ),
            ),
          if (_inviteMsg != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showInviteMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 16, color: _P.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Voir mon message d\'invitation',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: _P.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// HERO : PHOTOS EN DÉFILEMENT AUTOMATIQUE
// ============================================================
class _HeroPhotos extends StatefulWidget {
  final List<String> urls;
  final String fallback;
  const _HeroPhotos({required this.urls, required this.fallback});

  @override
  State<_HeroPhotos> createState() => _HeroPhotosState();
}

class _HeroPhotosState extends State<_HeroPhotos> {
  final PageController _ctrl = PageController();
  int _cur = 0;
  Timer? _t;

  List<String> get _urls => widget.urls.isEmpty ? [widget.fallback] : widget.urls;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _HeroPhotos old) {
    super.didUpdateWidget(old);
    if (_cur >= _urls.length) {
      _cur = 0;
      if (_ctrl.hasClients) _ctrl.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _start() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      final n = _urls.length;
      if (!mounted || n <= 1 || !_ctrl.hasClients) return;
      _ctrl.animateToPage(
        (_cur + 1) % n,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    final cur = _cur.clamp(0, urls.length - 1);
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _ctrl,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _cur = i),
          itemBuilder: (_, i) => TweenAnimationBuilder<double>(
            key: ValueKey('hero-$i-${urls[i]}'),
            tween: Tween(begin: 1.0, end: 1.08),
            duration: const Duration(seconds: 6),
            curve: Curves.easeOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Image.network(
              urls[i],
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: _P.gradPrimary),
                child: Center(child: Icon(Icons.favorite, size: 80, color: Colors.white.withOpacity(0.2))),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.18),
                Colors.transparent,
                const Color(0xFF3A0A18).withOpacity(0.58),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == cur;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: active ? 18 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// PETITS WIDGETS
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.1),
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
      radius: 18,
      blur: 14,
      opacity: 0.26,
      borderColor: Colors.white.withOpacity(0.55),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👋', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Bonjour $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          if (vip) ...[
            const SizedBox(width: 6),
            const Icon(Icons.star_rounded, size: 14, color: _P.accent),
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
    if (state == null) return const SizedBox(height: 66);
    return ThixGlass(
      radius: 20,
      blur: 18,
      opacity: 0.40,
      borderColor: Colors.white.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JOUR J DANS',
                    style: GoogleFonts.inter(
                        fontSize: 8.5,
                        color: _P.ink.withOpacity(0.7),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
                const SizedBox(height: 2),
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
          Text('$value', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17, color: _P.primaryDark)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 8.5, color: _P.ink.withOpacity(0.65), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const _SectionHeader({required this.title, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 17,
          decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: _P.ink, letterSpacing: -0.3)),
        ),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            child: Row(children: [
              Text('Voir tout', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: _P.primary)),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _P.primary),
            ]),
          ),
      ],
    );
  }
}

class _DisabledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ThixGlass(
      radius: 18,
      tint: const Color(0xFFFFE4E8),
      borderColor: _P.primary.withOpacity(0.45),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: _P.primary, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invitation désactivée',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _P.primary, fontSize: 13)),
                Text(
                  'Votre QR code n\'est plus valide. Contactez les mariés.',
                  style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, height: 1.3),
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
// TUILE DE MENU (compacte)
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
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFFFEFF4)],
                  ),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Icon(item.icon, color: _P.primary, size: 23),
              ),
              if (badge == _BadgeType.alert)
                const Positioned(
                  top: -1,
                  right: -1,
                  child: _DotBadge(child: Text('!', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800))),
                ),
              if (badge == _BadgeType.count)
                Positioned(
                  top: -1,
                  right: -1,
                  child: _DotBadge(
                    child: Text('${badgeCount ?? 0}',
                        style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              if (badge == _BadgeType.live)
                Positioned(
                  top: -4,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('LIVE',
                        style: TextStyle(fontSize: 7.5, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 10.5, color: _P.ink, height: 1.1),
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
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _P.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: child,
    );
  }
}

// ============================================================
// BANDE PHOTOS
// ============================================================
class _PhotoStrip extends StatelessWidget {
  final List<String> urls;
  final VoidCallback onTap;
  const _PhotoStrip({required this.urls, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => showPhotoViewer(context, urls, i),
          child: Container(
            width: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: _P.shadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              urls[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: _P.primarySoft),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// NOS PRESTATAIRES (avec photos)
// ============================================================
class _VendorsList extends StatelessWidget {
  final List<VendorModel> vendors;
  final Map<String, String> photos;
  final void Function(VendorModel, String?) onTap;
  const _VendorsList({required this.vendors, required this.photos, required this.onTap});

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
        height: 70,
        child: Center(child: Text('Aucun prestataire enregistré', style: GoogleFonts.inter(color: _P.inkSoft, fontSize: 12))),
      );
    }
    return SizedBox(
      height: 168,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final v = vendors[i];
          final photo = photos[v.name.trim().toLowerCase()];
          return InkWell(
            onTap: () => onTap(v, photo),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 146,
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _P.shadow,
                border: Border.all(color: _P.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 88,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (photo != null)
                          Image.network(photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: _P.gradPrimary)))
                        else
                          Container(
                            decoration: const BoxDecoration(gradient: _P.gradPrimary),
                            child: Center(child: Icon(_vendorIcon(v.category), size: 32, color: Colors.white54)),
                          ),
                        if (v.isBooked)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: ThixGlass(
                              radius: 9,
                              blur: 10,
                              opacity: 0.6,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 11, color: _P.green),
                                  const SizedBox(width: 3),
                                  Text('Réservé',
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: _P.ink)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: _P.ink)),
                        Text(v.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, color: _P.primary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 11, color: _P.inkSoft),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(v.contactName ?? 'Contact à venir',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 9.5, color: _P.inkSoft)),
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
// INFOS PRATIQUES — uniquement ce que le staff publie
// ============================================================
class _UpdatesList extends StatelessWidget {
  final List<GuestAnnouncement> items;
  final void Function(GuestAnnouncement) onTap;
  const _UpdatesList({required this.items, required this.onTap});

  IconData _icon(String tag) {
    switch (tag) {
      case 'PARKING':
        return Icons.local_parking_outlined;
      case 'DRESS CODE':
        return Icons.checkroom_outlined;
      case 'TRANSPORT':
        return Icons.directions_bus_outlined;
      case 'PROGRAMME':
        return Icons.event_note_outlined;
      case 'MENU':
        return Icons.restaurant_menu_rounded;
      case 'URGENT':
        return Icons.warning_amber_rounded;
      default:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: 64,
        child: Center(
          child: Text('Aucune information publiée pour le moment',
              style: GoogleFonts.inter(color: _P.inkSoft, fontSize: 12)),
        ),
      );
    }
    return SizedBox(
      height: 158,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = items[i];
          final tc = tagColor(a.tag);
          final firstLine = a.title ??
              (a.content == '📷 Photo' ? 'Photo' : a.content.split('\n').first);
          return InkWell(
            onTap: () => onTap(a),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 146,
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _P.shadow,
                border: Border.all(color: _P.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 74,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (a.images.isNotEmpty)
                          Image.network(a.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: _P.accentSoft))
                        else
                          Container(
                            color: _P.accentSoft,
                            child: Center(child: Icon(_icon(a.tag), size: 26, color: _P.accent)),
                          ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(color: tc, borderRadius: BorderRadius.circular(6)),
                            child: Text(a.tag,
                                style: const TextStyle(
                                    fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
                          ),
                        ),
                        if (a.images.length > 1)
                          Positioned(
                            right: 8,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: Text('+${a.images.length - 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _P.ink, height: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Text('${a.sender} · ${_fmtShort(a.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 9.5, color: _P.primary, fontWeight: FontWeight.w800)),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INFORMATION',
                    style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(text,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE ROSE « UNE QUESTION ? »
// ============================================================
class _HelpCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HelpCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD81B60), Color(0xFFB0124F)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.32), blurRadius: 18, offset: const Offset(0, 9))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Une question ?',
                      style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Contacter les mariés',
                      style: GoogleFonts.playfairDisplay(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700, height: 1.1)),
                  const SizedBox(height: 4),
                  Text('FAQ, messages et aide pour le jour J.',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.85))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

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
      radius: 20,
      opacity: 0.5,
      borderColor: _P.primary.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e['icon'] as IconData, size: 19, color: _P.primary),
              const SizedBox(height: 5),
              Text(e['label'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 9.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// BARRE DE NAVIGATION FLOTTANTE (verre dépoli, compacte)
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
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.64),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.1),
            boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.14), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Accueil', selected: true, onTap: onHome),
              _NavItem(icon: Icons.event_outlined, label: 'Agenda', onTap: onAgenda),
              GestureDetector(
                onTap: onHeart,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _P.gradPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 21),
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 1),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
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
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
      child: ThixGlass(
        radius: 26,
        opacity: 0.55,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: _P.primary),
            const SizedBox(height: 10),
            Text(
              error is Failure ? (error as Failure).message : 'Erreur de chargement',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _P.inkSoft),
            ),
            const SizedBox(height: 14),
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
