// lib/presentation/thix_weeding/pages/staff/messages/staff_messages_page.dart
// ============================================================================
// THIX WEDDING — MESSAGES STAFF (PRODUCTION v2)
// ✅ Onglet Discussions : nom réel de l'invité, non-lus, aperçu photo
// ✅ Onglet Annonces : informations publiées pour tous (photo, tag, type)
// ✅ Création d'une annonce / info pratique avec photos, publier / dépublier
// ✅ Temps réel + verre dépoli
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

import 'message_media.dart';

class _C {
  static const blue = Color(0xFF0B3B8F);
  static const rose = Color(0xFFE31C4E);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF111827);
  static const ink2 = Color(0xFF6B7280);
}

/// Conservé pour compatibilité avec d'autres écrans (ancienne version).
final conversationsProvider = FutureProvider.family<List<MessageModel>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client.from('thix_weeding_messages').select().eq('wedding_id', weddingId).order('created_at', ascending: false);
  final models = res.map((e) => MessageModel.fromJson(e)).toList();
  // group by guestId / senderName - garde dernier message
  final Map<String, MessageModel> grouped = {};
  for (var m in models) {
    final key = (m.guestId ?? m.senderName).toString();
    if (!grouped.containsKey(key)) grouped[key] = m;
  }
  return grouped.values.toList();
});

/// Discussions : une ligne par invité (dernier message, nom réel, non-lus).
final staffThreadsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  final supa = Supabase.instance.client;
  final res = await supa
      .from('thix_weeding_messages')
      .select()
      .eq('wedding_id', weddingId)
      .order('created_at', ascending: false);

  final names = <String, String>{};
  try {
    final gs = await supa.from('thix_weeding_guests').select('id, name').eq('wedding_id', weddingId);
    for (final g in (gs as List)) {
      names['${g['id']}'] = (g['name'] as String?) ?? '';
    }
  } catch (_) {}

  final grouped = <String, Map<String, dynamic>>{};
  for (final raw in (res as List)) {
    final m = Map<String, dynamic>.from(raw as Map);
    // les annonces publiées pour tous vont dans l'autre onglet
    if (m['guest_id'] == null && (m['is_published'] == true)) continue;
    final key = '${m['guest_id'] ?? m['sender_name']}';
    final entry = grouped.putIfAbsent(key, () {
      final copy = Map<String, dynamic>.from(m);
      final gid = m['guest_id'];
      copy['_key'] = key;
      copy['_name'] = (gid != null && (names['$gid'] ?? '').isNotEmpty)
          ? names['$gid']!
          : ((m['sender_name'] as String?) ?? 'Invité');
      copy['_unread'] = 0;
      return copy;
    });
    if (m['sender_type'] == 'guest' && m['is_read'] != true) {
      entry['_unread'] = (entry['_unread'] as int) + 1;
    }
  }
  return grouped.values.toList();
});

/// Annonces & infos pratiques (publiées ou brouillons).
final staffAnnouncementsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client
      .from('thix_weeding_messages')
      .select()
      .eq('wedding_id', weddingId)
      .filter('guest_id', 'is', 'null')
      .inFilter('message_type', ['announcement', 'info'])
      .order('created_at', ascending: false);
  return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

String _fmt(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class StaffMessagesPage extends ConsumerStatefulWidget {
  final String weddingId;
  const StaffMessagesPage({super.key, required this.weddingId});

  @override
  ConsumerState<StaffMessagesPage> createState() => _StaffMessagesPageState();
}

class _StaffMessagesPageState extends ConsumerState<StaffMessagesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  RealtimeChannel? _ch;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
    _ch = Supabase.instance.client
        .channel('staff-msgs-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: widget.weddingId,
          ),
          callback: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 400), _refresh);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) Supabase.instance.client.removeChannel(_ch!);
    _tab.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    ref.invalidate(staffThreadsProvider(widget.weddingId));
    ref.invalidate(staffAnnouncementsProvider(widget.weddingId));
    ref.invalidate(messagesProvider(widget.weddingId));
  }

  void _openComposer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Composer(weddingId: widget.weddingId, onDone: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(staffThreadsProvider(widget.weddingId));
    final anns = ref.watch(staffAnnouncementsProvider(widget.weddingId));
    final onAnn = _tab.index == 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _C.ink,
        title: Text('Messages', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _C.rose,
          labelColor: _C.rose,
          unselectedLabelColor: _C.ink2,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [Tab(text: 'Discussions'), Tab(text: 'Annonces & infos')],
        ),
      ),
      floatingActionButton: onAnn
          ? FloatingActionButton.extended(
              backgroundColor: _C.rose,
              foregroundColor: Colors.white,
              onPressed: _openComposer,
              icon: const Icon(Icons.campaign_rounded),
              label: Text('Nouvelle info', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            )
          : null,
      body: ThixGlassBackdrop(
        child: TabBarView(
          controller: _tab,
          children: [
            // ── Discussions ──
            threads.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Erreur: $e')),
              data: (list) {
                if (list.isEmpty) return const Center(child: Text('Aucune discussion'));
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(staffThreadsProvider(widget.weddingId)),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return _ThreadTile(
                        thread: c,
                        onTap: () => context.push(
                          '/thix-weeding/staff/${widget.weddingId}/messages/${c['_key']}',
                          extra: c['_name'],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // ── Annonces ──
            anns.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur: $e\n(Avez-vous exécuté le SQL des messages ?)', textAlign: TextAlign.center),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Aucune information publiée.\nAppuyez sur « Nouvelle info » pour informer vos invités (parking, dress code, navette…).',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: _C.ink2, height: 1.4),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(staffAnnouncementsProvider(widget.weddingId)),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _AnnCard(item: list[i], onChanged: _refresh),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================= INTERNES =================

class _ThreadTile extends StatelessWidget {
  final Map<String, dynamic> thread;
  final VoidCallback onTap;
  const _ThreadTile({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = '${thread['_name'] ?? 'Invité'}';
    final unread = (thread['_unread'] as int?) ?? 0;
    final imgs = parseImageUrls(thread['image_urls']);
    final content = '${thread['content'] ?? ''}'.trim();
    final fromStaff = thread['sender_type'] == 'staff';
    final type = '${thread['message_type'] ?? 'chat'}';
    final preview = content.isNotEmpty
        ? content
        : (imgs.isNotEmpty ? '📷 ${imgs.length} photo${imgs.length > 1 ? 's' : ''}' : '');

    return ThixGlass(
      radius: 18,
      opacity: 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: _C.blue.withOpacity(0.12),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: _C.blue, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 13.5, fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700)),
                  ),
                  if (type == 'invitation') ...[
                    const SizedBox(width: 6),
                    _mini('INVITATION', _C.rose),
                  ] else if (type == 'info') ...[
                    const SizedBox(width: 6),
                    _mini('INFO', _C.green),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  '${fromStaff ? 'Vous : ' : ''}$preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: unread > 0 ? _C.ink : _C.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(thread['created_at']), style: GoogleFonts.inter(fontSize: 10.5, color: _C.ink2)),
              const SizedBox(height: 4),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _C.rose, borderRadius: BorderRadius.circular(10)),
                  child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: TextStyle(color: c, fontSize: 8.5, fontWeight: FontWeight.w900)),
      );
}

class _AnnCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;
  const _AnnCard({required this.item, required this.onChanged});

  Future<void> _toggle(BuildContext context, bool v) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_messages')
          .update({'is_published': v}).eq('id', item['id']);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.rose));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette information ?'),
        content: const Text('Elle disparaîtra de l\'accueil de tous les invités.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('thix_weeding_messages').delete().eq('id', item['id']);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.rose));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgs = parseImageUrls(item['image_urls']);
    final tag = '${item['tag'] ?? 'INFO'}';
    final title = '${item['title'] ?? ''}'.trim();
    final published = item['is_published'] == true;
    final tc = tagColor(tag);

    return ThixGlass(
      radius: 20,
      opacity: 0.62,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imgs.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => showPhotoViewer(context, imgs, 0),
                      child: Image.network(imgs.first, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.black12)),
                    ),
                  ),
                  if (imgs.length > 1)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                        child: Text('+${imgs.length - 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: tc, borderRadius: BorderRadius.circular(7)),
                    child: Text(tag.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Text(item['message_type'] == 'announcement' ? 'Annonce' : 'Info pratique',
                      style: GoogleFonts.inter(fontSize: 10.5, color: _C.ink2, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(_fmt(item['created_at']), style: GoogleFonts.inter(fontSize: 10.5, color: _C.ink2)),
                ]),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(title, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: _C.ink)),
                ],
                const SizedBox(height: 6),
                Text('${item['content'] ?? ''}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.5, color: _C.ink, height: 1.4)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 4, 8),
            child: Row(
              children: [
                Icon(published ? Icons.public_rounded : Icons.visibility_off_outlined,
                    size: 16, color: published ? _C.green : _C.ink2),
                const SizedBox(width: 6),
                Text(published ? 'Visible par les invités' : 'Brouillon (masqué)',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: published ? _C.green : _C.ink2)),
                const Spacer(),
                Switch(value: published, activeColor: _C.green, onChanged: (v) => _toggle(context, v)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, color: _C.rose),
                  onPressed: () => _delete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Composer d'annonce ─────────────────────────
class _Composer extends StatefulWidget {
  final String weddingId;
  final VoidCallback onDone;
  const _Composer({required this.weddingId, required this.onDone});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _type = 'info';
  String _tag = 'INFO';
  bool _publish = true;
  bool _busy = false;
  String? _error;
  final List<PickedPhoto> _photos = [];

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    try {
      final p = await pickPhotos(max: kMaxMessagePhotos - _photos.length);
      if (p.isNotEmpty) setState(() => _photos.addAll(p));
    } catch (e) {
      setState(() => _error = 'Galerie inaccessible : $e');
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty && content.isEmpty && _photos.isEmpty) {
      setState(() => _error = 'Ajoutez un titre, un message ou une photo.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final urls = _photos.isEmpty ? <String>[] : await uploadPhotos(widget.weddingId, _photos);
      await Supabase.instance.client.from('thix_weeding_messages').insert({
        'wedding_id': widget.weddingId,
        'guest_id': null,
        'sender_name': 'Staff',
        'sender_type': 'staff',
        'message_type': _type,
        'tag': _tag,
        'title': title.isEmpty ? null : title,
        'content': content.isNotEmpty ? content : (title.isNotEmpty ? title : '📷 Photo'),
        'image_urls': urls,
        'is_published': _publish,
        'is_read': true,
      });
      widget.onDone();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Échec : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
        child: ThixGlass(
          radius: 28,
          opacity: 0.8,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Informer vos invités',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _C.ink)),
                Text('Publié sur l\'accueil de tous les invités.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: _C.ink2)),
                const SizedBox(height: 12),
                Row(children: [
                  ChoiceChip(
                    label: const Text('Info pratique'),
                    selected: _type == 'info',
                    onSelected: (_) => setState(() => _type = 'info'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Annonce'),
                    selected: _type == 'announcement',
                    onSelected: (_) => setState(() => _type = 'announcement'),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 0,
                  children: kInfoTags
                      .map((t) => ChoiceChip(
                            label: Text(t, style: const TextStyle(fontSize: 11)),
                            selected: _tag == t,
                            selectedColor: tagColor(t).withOpacity(0.2),
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _tag = t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _title,
                  maxLength: 70,
                  decoration: InputDecoration(
                    labelText: 'Titre (optionnel)',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _content,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                PickedPhotoStrip(photos: _photos, onRemove: (i) => setState(() => _photos.removeAt(i))),
                if (_photos.isNotEmpty) const SizedBox(height: 8),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: _busy || _photos.length >= kMaxMessagePhotos ? null : _addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text('Photos (${_photos.length}/$kMaxMessagePhotos)'),
                  ),
                  const Spacer(),
                  Text('Publier', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  Switch(value: _publish, activeColor: _C.green, onChanged: (v) => setState(() => _publish = v)),
                ]),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_error!, style: const TextStyle(color: _C.rose, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _C.rose,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(_publish ? 'Publier' : 'Enregistrer en brouillon',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
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
