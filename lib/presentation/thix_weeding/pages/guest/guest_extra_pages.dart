// lib/presentation/thix_weeding/pages/guest/guest_extra_pages.dart
// ============================================================================
// THIX WEDDING — PAGES INVITÉ SUPPLÉMENTAIRES
// ✅ GuestMenuPage        : menu du repas (photos, tags)
// ✅ GuestInfoPage        : navette, dress code, FAQ, remerciements, live
// ✅ GuestAnnoncesPage    : annonces publiées par le staff (photos)
// ✅ GuestPrestatairesPage: prestataires du mariage (photos)
// Tout en temps réel, verre dépoli, uniquement le contenu PUBLIÉ.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/presentation/thix_weeding/pages/guest/guest_home_page.dart'
    show GuestAnnouncement, guestAnnouncementsProvider, guestVendorPhotosProvider;
import 'package:thix_id/presentation/thix_weeding/pages/staff/content/staff_content_pages.dart'
    show MenuEntry, InfoBlock, kMenuCourses, kMenuCourseIcons, kMenuTags, kInfoKinds;
import 'package:thix_id/presentation/thix_weeding/pages/staff/messages/message_media.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

class _G {
  static const rose = Color(0xFFD81B60);
  static const roseSoft = Color(0xFFFCE4EC);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF241521);
  static const ink2 = Color(0xFF8A7580);
  static const grad = LinearGradient(
    colors: [Color(0xFFE91E78), Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _GScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  const _GScaffold({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _G.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
      ),
      body: ThixGlassBackdrop(child: body),
    );
  }
}

Widget _emptyState(IconData icon, String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: _G.rose.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _G.ink2, height: 1.4)),
          ],
        ),
      ),
    );

Widget _chip(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _G.roseSoft, borderRadius: BorderRadius.circular(9)),
      child: Text(t, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _G.rose)),
    );

Future<void> _openUrl(BuildContext context, String url) async {
  final u = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
  if (u == null) return;
  try {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien impossible à ouvrir')));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MENU DU REPAS
// ═══════════════════════════════════════════════════════════════════════════
class GuestMenuPage extends StatefulWidget {
  final String weddingId;
  const GuestMenuPage({super.key, required this.weddingId});

  @override
  State<GuestMenuPage> createState() => _GuestMenuPageState();
}

class _GuestMenuPageState extends State<GuestMenuPage> {
  final _supa = Supabase.instance.client;
  List<MenuEntry> _items = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _ch;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _load();
    _ch = _supa
        .channel('guest-menu-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_menu_items',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 500), () {
              if (mounted) _load(silent: true);
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) _supa.removeChannel(_ch!);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final rows = await _supa
          .from('thix_weeding_menu_items')
          .select()
          .eq('wedding_id', widget.weddingId)
          .eq('is_published', true)
          .order('position', ascending: true);
      if (!mounted) return;
      setState(() {
        _items = (rows as List).map((e) => MenuEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GScaffold(
      title: 'Menu',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _G.rose))
          : _error != null
              ? _emptyState(Icons.error_outline_rounded, 'Menu indisponible pour le moment.')
              : _items.isEmpty
                  ? _emptyState(Icons.restaurant_menu_rounded,
                      'Le menu n\'est pas encore publié.\nLes mariés l\'afficheront bientôt.')
                  : RefreshIndicator(
                      color: _G.rose,
                      onRefresh: () => _load(silent: true),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
                        children: [
                          for (final c in kMenuCourses.keys)
                            if (_items.any((e) => e.course == c)) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                                child: Row(children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: const BoxDecoration(gradient: _G.grad, shape: BoxShape.circle),
                                    child: Icon(kMenuCourseIcons[c], size: 18, color: Colors.white),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(kMenuCourses[c]!,
                                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _G.ink)),
                                ]),
                              ),
                              ..._items.where((e) => e.course == c).map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _dish(e),
                                  )),
                            ],
                        ],
                      ),
                    ),
    );
  }

  Widget _dish(MenuEntry e) {
    return ThixGlass(
      radius: 22,
      opacity: 0.62,
      borderColor: _G.rose.withOpacity(0.15),
      padding: EdgeInsets.zero,
      onTap: e.imageUrl == null ? null : () => showPhotoViewer(context, [e.imageUrl!]),
      child: Row(
        children: [
          if (e.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
              child: SizedBox(
                width: 104,
                height: 104,
                child: Image.network(e.imageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _G.roseSoft)),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: _G.ink)),
                  if (e.description != null) ...[
                    const SizedBox(height: 3),
                    Text(e.description!, style: GoogleFonts.inter(fontSize: 12, color: _G.ink2, height: 1.35)),
                  ],
                  if (e.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 5, runSpacing: 4, children: e.tags.map((t) => _chip(kMenuTags[t] ?? t)).toList()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGES D'INFOS : navette, dress_code, faq, thanks, live
// ═══════════════════════════════════════════════════════════════════════════
class GuestInfoPage extends StatefulWidget {
  final String weddingId;
  final String kind;
  const GuestInfoPage({super.key, required this.weddingId, required this.kind});

  @override
  State<GuestInfoPage> createState() => _GuestInfoPageState();
}

class _GuestInfoPageState extends State<GuestInfoPage> {
  final _supa = Supabase.instance.client;
  List<InfoBlock> _blocks = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _ch;
  Timer? _deb;

  String get _kind => kInfoKinds.containsKey(widget.kind) ? widget.kind : 'navette';

  @override
  void initState() {
    super.initState();
    _load();
    _ch = _supa
        .channel('guest-info-${widget.weddingId}-$_kind')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_info_blocks',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 500), () {
              if (mounted) _load(silent: true);
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) _supa.removeChannel(_ch!);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final rows = await _supa
          .from('thix_weeding_info_blocks')
          .select()
          .eq('wedding_id', widget.weddingId)
          .eq('kind', _kind)
          .eq('is_published', true)
          .order('position', ascending: true);
      if (!mounted) return;
      setState(() {
        _blocks = (rows as List).map((e) => InfoBlock.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = kInfoKinds[_kind]!;
    return _GScaffold(
      title: meta.label,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _G.rose))
          : _error != null
              ? _emptyState(Icons.error_outline_rounded, 'Contenu indisponible pour le moment.')
              : _blocks.isEmpty
                  ? _emptyState(
                      meta.icon,
                      _kind == 'live'
                          ? 'Le direct n\'a pas encore commencé.\nLe lien apparaîtra ici le jour J.'
                          : 'Les mariés n\'ont pas encore publié d\'informations ici.',
                    )
                  : RefreshIndicator(
                      color: _G.rose,
                      onRefresh: () => _load(silent: true),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
                        itemCount: _blocks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _kind == 'faq' ? _faq(_blocks[i]) : _card(_blocks[i], meta.icon),
                      ),
                    ),
    );
  }

  Widget _faq(InfoBlock b) {
    return ThixGlass(
      radius: 20,
      opacity: 0.62,
      borderColor: _G.rose.withOpacity(0.15),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: _G.rose,
          collapsedIconColor: _G.rose,
          title: Text(b.title ?? 'Question',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _G.ink)),
          children: [
            if (b.body != null)
              Text(b.body!, style: GoogleFonts.inter(fontSize: 13, color: _G.ink, height: 1.45)),
            if (b.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              MessageImages(urls: b.images, radius: 14),
            ],
            if (b.linkUrl != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _openUrl(context, b.linkUrl!),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Ouvrir le lien'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(InfoBlock b, IconData icon) {
    final live = _kind == 'live';
    return ThixGlass(
      radius: 24,
      opacity: 0.62,
      borderColor: _G.rose.withOpacity(0.15),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.title != null)
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(gradient: _G.grad, shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(b.title!,
                    style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w900, color: _G.ink)),
              ),
            ]),
          if (b.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            MessageImages(urls: b.images, radius: 16),
          ],
          if (b.body != null) ...[
            const SizedBox(height: 12),
            Text(b.body!, style: GoogleFonts.inter(fontSize: 13.5, color: _G.ink, height: 1.5)),
          ],
          if (b.linkUrl != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _G.rose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _openUrl(context, b.linkUrl!),
                icon: Icon(live ? Icons.play_circle_fill_rounded : Icons.open_in_new_rounded, size: 20),
                label: Text(live ? 'Rejoindre le live' : 'Ouvrir le lien',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANNONCES (publiées par le staff)
// ═══════════════════════════════════════════════════════════════════════════
class GuestAnnoncesPage extends ConsumerWidget {
  final String weddingId;
  const GuestAnnoncesPage({super.key, required this.weddingId});

  String _date(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(guestAnnouncementsProvider(weddingId));
    return _GScaffold(
      title: 'Annonces',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _G.rose)),
        error: (e, _) => _emptyState(Icons.error_outline_rounded, 'Annonces indisponibles pour le moment.'),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: _G.rose,
              onRefresh: () async => ref.invalidate(guestAnnouncementsProvider(weddingId)),
              child: ListView(children: [
                SizedBox(
                  height: 400,
                  child: _emptyState(Icons.campaign_outlined, 'Aucune annonce pour le moment.'),
                ),
              ]),
            );
          }
          return RefreshIndicator(
            color: _G.rose,
            onRefresh: () async => ref.invalidate(guestAnnouncementsProvider(weddingId)),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _card(context, list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, GuestAnnouncement a) {
    final tc = tagColor(a.tag);
    final text = a.content == '📷 Photo' && a.images.isNotEmpty ? '' : a.content;
    return ThixGlass(
      radius: 24,
      opacity: 0.62,
      borderColor: _G.rose.withOpacity(0.15),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.images.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: GestureDetector(
                onTap: () => showPhotoViewer(context, a.images, 0),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(a.images.first, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: _G.roseSoft)),
                      if (a.images.length > 1)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                            child: Text('+${a.images.length - 1} photo(s)',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: tc, borderRadius: BorderRadius.circular(7)),
                    child: Text(a.tag,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                  const Spacer(),
                  Text(_date(a.createdAt), style: GoogleFonts.inter(fontSize: 10.5, color: _G.ink2)),
                ]),
                if (a.title != null) ...[
                  const SizedBox(height: 8),
                  Text(a.title!, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _G.ink)),
                ],
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(text, style: GoogleFonts.inter(fontSize: 13.5, color: _G.ink, height: 1.45)),
                ],
                const SizedBox(height: 8),
                Text(a.sender,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _G.rose)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRES
// ═══════════════════════════════════════════════════════════════════════════
class GuestPrestatairesPage extends ConsumerWidget {
  final String weddingId;
  const GuestPrestatairesPage({super.key, required this.weddingId});

  IconData _icon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('salle') || c.contains('lieu')) return Icons.villa_outlined;
    if (c.contains('traiteur') || c.contains('restau')) return Icons.restaurant_outlined;
    if (c.contains('photo') || c.contains('video')) return Icons.camera_alt_outlined;
    if (c.contains('deco') || c.contains('fleur')) return Icons.local_florist_outlined;
    if (c.contains('musique') || c.contains('dj')) return Icons.music_note_outlined;
    if (c.contains('robe') || c.contains('tenue') || c.contains('couture')) return Icons.checkroom_outlined;
    return Icons.store_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorsProvider(weddingId));
    final photos = ref.watch(guestVendorPhotosProvider(weddingId)).value ?? const <String, String>{};
    return _GScaffold(
      title: 'Prestataires',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _G.rose)),
        error: (e, _) => _emptyState(Icons.error_outline_rounded, 'Prestataires indisponibles pour le moment.'),
        data: (List<VendorModel> vendors) {
          if (vendors.isEmpty) {
            return _emptyState(Icons.storefront_outlined, 'Aucun prestataire enregistré pour ce mariage.');
          }
          return RefreshIndicator(
            color: _G.rose,
            onRefresh: () async {
              ref.invalidate(vendorsProvider(weddingId));
              ref.invalidate(guestVendorPhotosProvider(weddingId));
            },
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              itemCount: vendors.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (_, i) {
                final v = vendors[i];
                final photo = photos[v.name.trim().toLowerCase()];
                return GestureDetector(
                  onTap: () => _detail(context, v, photo),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFF3E1E6)),
                      boxShadow: [BoxShadow(color: _G.rose.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (photo != null)
                                  Image.network(photo, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: _G.grad)))
                                else
                                  Container(
                                    decoration: const BoxDecoration(gradient: _G.grad),
                                    child: Icon(_icon(v.category), size: 38, color: Colors.white54),
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
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.check_circle_rounded, size: 11, color: _G.green),
                                        const SizedBox(width: 3),
                                        Text('Réservé',
                                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: _G.ink)),
                                      ]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _G.ink)),
                              Text(v.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 11, color: _G.rose, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(v.contactName ?? 'Contact à venir',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 10, color: _G.ink2)),
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
        },
      ),
    );
  }

  void _detail(BuildContext context, VendorModel v, String? photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: ThixGlass(
          radius: 28,
          opacity: 0.85,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photo != null) ...[
                MessageImages(urls: [photo], radius: 18),
                const SizedBox(height: 12),
              ],
              Text(v.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _G.ink)),
              Text(v.category, style: GoogleFonts.inter(fontSize: 12.5, color: _G.rose, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 17, color: _G.ink2),
                const SizedBox(width: 6),
                Text(v.contactName ?? 'Contact à venir',
                    style: GoogleFonts.inter(fontSize: 13.5, color: _G.ink, fontWeight: FontWeight.w600)),
              ]),
              if (v.isBooked) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 17, color: _G.green),
                  const SizedBox(width: 6),
                  Text('Prestataire confirmé',
                      style: GoogleFonts.inter(fontSize: 13.5, color: _G.green, fontWeight: FontWeight.w800)),
                ]),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
