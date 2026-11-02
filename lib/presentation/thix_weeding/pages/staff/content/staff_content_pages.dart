// lib/presentation/thix_weeding/pages/staff/content/staff_content_pages.dart
// ============================================================================
// THIX WEDDING — CONTENUS INVITÉS (STAFF) : MENU DU REPAS + PAGES D'INFOS
// ✅ StaffMenuPage : plats par catégorie, photo, tags, publier / masquer, ordre
// ✅ StaffInfoPage : navette, dress code, FAQ, remerciements, live (photos + lien)
// ✅ Modèles et constantes partagés avec les pages invité
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/messages/message_media.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

class _K {
  static const rose = Color(0xFFD81B60);
  static const roseSoft = Color(0xFFFCE4EC);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF111827);
  static const ink2 = Color(0xFF6B7280);
}

String? _nz(dynamic v) {
  final s = v == null ? '' : '$v'.trim();
  return (s.isEmpty || s == 'null') ? null : s;
}

// ═══════════════════════════════════════════════════════════════════════════
// CONSTANTES + MODÈLES PARTAGÉS
// ═══════════════════════════════════════════════════════════════════════════
const Map<String, String> kMenuCourses = {
  'entree': 'Entrées',
  'plat': 'Plats',
  'dessert': 'Desserts',
  'boisson': 'Boissons',
  'autre': 'Autres',
};

const Map<String, IconData> kMenuCourseIcons = {
  'entree': Icons.tapas_rounded,
  'plat': Icons.restaurant_rounded,
  'dessert': Icons.cake_outlined,
  'boisson': Icons.local_bar_outlined,
  'autre': Icons.more_horiz_rounded,
};

const Map<String, String> kMenuTags = {
  'vegetarien': 'Végétarien',
  'vegan': 'Vegan',
  'halal': 'Halal',
  'sans_gluten': 'Sans gluten',
  'sans_porc': 'Sans porc',
  'epice': 'Épicé',
};

class MenuEntry {
  final String id;
  String course;
  String name;
  String? description;
  String? imageUrl;
  List<String> tags;
  int position;
  bool published;

  MenuEntry({
    required this.id,
    required this.course,
    required this.name,
    this.description,
    this.imageUrl,
    this.tags = const [],
    this.position = 0,
    this.published = true,
  });

  factory MenuEntry.fromJson(Map<String, dynamic> j) => MenuEntry(
        id: '${j['id']}',
        course: '${j['course'] ?? 'plat'}',
        name: '${j['name'] ?? ''}',
        description: _nz(j['description']),
        imageUrl: _nz(j['image_url']),
        tags: ((j['tags'] as List?) ?? const []).map((e) => '$e').toList(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        published: (j['is_published'] as bool?) ?? true,
      );
}

class InfoKindMeta {
  final String label;
  final IconData icon;
  final String titleLabel;
  final String bodyLabel;
  final String example;
  final String linkLabel;
  const InfoKindMeta(this.label, this.icon, this.titleLabel, this.bodyLabel, this.example, this.linkLabel);
}

const Map<String, InfoKindMeta> kInfoKinds = {
  'navette': InfoKindMeta(
    'Navette & transport',
    Icons.directions_bus_outlined,
    'Trajet',
    'Horaires, point de rendez-vous, consignes…',
    'Ex : Hôtel → Salle, départ 15h00',
    'Lien de l\'itinéraire (optionnel)',
  ),
  'dress_code': InfoKindMeta(
    'Dress code',
    Icons.checkroom_outlined,
    'Titre',
    'Tenue souhaitée, couleurs à éviter…',
    'Ex : Tenue de soirée, couleurs pastel',
    'Lien d\'inspiration (optionnel)',
  ),
  'faq': InfoKindMeta(
    'FAQ',
    Icons.help_outline_rounded,
    'Question',
    'Réponse',
    'Ex : Y a-t-il un parking ?',
    'Lien utile (optionnel)',
  ),
  'thanks': InfoKindMeta(
    'Remerciements',
    Icons.volunteer_activism_outlined,
    'Titre',
    'Votre message de remerciement',
    'Ex : Merci d\'avoir partagé ce jour avec nous',
    'Lien (optionnel)',
  ),
  'live': InfoKindMeta(
    'Live',
    Icons.podcasts_outlined,
    'Titre',
    'Description (heure de début, instructions…)',
    'Ex : Cérémonie en direct',
    'Lien du direct (YouTube, Facebook, Zoom…)',
  ),
};

class InfoBlock {
  final String id;
  final String kind;
  String? title;
  String? body;
  String? linkUrl;
  List<String> images;
  int position;
  bool published;

  InfoBlock({
    required this.id,
    required this.kind,
    this.title,
    this.body,
    this.linkUrl,
    this.images = const [],
    this.position = 0,
    this.published = true,
  });

  factory InfoBlock.fromJson(Map<String, dynamic> j) => InfoBlock(
        id: '${j['id']}',
        kind: '${j['kind'] ?? 'navette'}',
        title: _nz(j['title']),
        body: _nz(j['body']),
        linkUrl: _nz(j['link_url']),
        images: parseImageUrls(j['image_urls']),
        position: (j['position'] as num?)?.toInt() ?? 0,
        published: (j['is_published'] as bool?) ?? true,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// BRIQUES UI
// ═══════════════════════════════════════════════════════════════════════════
class _GlassField extends StatelessWidget {
  final TextEditingController c;
  final String label;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  const _GlassField(this.c, this.label, this.icon, {this.maxLines = 1, this.maxLength});

  @override
  Widget build(BuildContext context) => TextField(
        controller: c,
        maxLines: maxLines,
        minLines: 1,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 19, color: _K.rose),
          filled: true,
          fillColor: Colors.white.withOpacity(0.65),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );
}

Widget _tagChip(String t, {Color color = _K.rose}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
    );

// ═══════════════════════════════════════════════════════════════════════════
// STAFF : MENU DU REPAS
// ═══════════════════════════════════════════════════════════════════════════
class StaffMenuPage extends StatefulWidget {
  final String weddingId;
  const StaffMenuPage({super.key, required this.weddingId});

  @override
  State<StaffMenuPage> createState() => _StaffMenuPageState();
}

class _StaffMenuPageState extends State<StaffMenuPage> {
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
        .channel('staff-menu-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_menu_items',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 400), () {
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
          .order('position', ascending: true)
          .order('created_at', ascending: true);
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

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? _K.rose : _K.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  List<MenuEntry> _course(String c) => _items.where((e) => e.course == c).toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  int _nextPos(String course) {
    final l = _course(course);
    return l.isEmpty ? 0 : l.last.position + 1;
  }

  Future<void> _togglePublished(MenuEntry e, bool v) async {
    try {
      await _supa.from('thix_weeding_menu_items').update({'is_published': v}).eq('id', e.id);
      setState(() => e.published = v);
    } catch (err) {
      _toast('Erreur : $err', error: true);
    }
  }

  Future<void> _move(MenuEntry e, int dir) async {
    final l = _course(e.course);
    final i = l.indexWhere((x) => x.id == e.id);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= l.length) return;
    try {
      await _supa.from('thix_weeding_menu_items').update({'position': j}).eq('id', l[i].id);
      await _supa.from('thix_weeding_menu_items').update({'position': i}).eq('id', l[j].id);
      await _load(silent: true);
    } catch (err) {
      _toast('Erreur : $err', error: true);
    }
  }

  Future<void> _delete(MenuEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer « ${e.name} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _K.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supa.from('thix_weeding_menu_items').delete().eq('id', e.id);
      await _load(silent: true);
    } catch (err) {
      _toast('Suppression impossible : $err', error: true);
    }
  }

  void _openEditor([MenuEntry? e]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuEditor(
        weddingId: widget.weddingId,
        existing: e,
        positionFor: _nextPos,
        onSaved: () => _load(silent: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final published = _items.where((e) => e.published).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _K.ink,
        title: Text('Menu du repas', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _K.rose,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: Text('Ajouter un plat', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ThixGlassBackdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _K.rose))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur : $_error\n(Avez-vous exécuté le SQL du menu ?)', textAlign: TextAlign.center),
                    ),
                  )
                : _items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Votre menu est vide.\nAjoutez les entrées, plats, desserts et boissons : vos invités les verront sur leur accueil.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: _K.ink2, height: 1.4),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(silent: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text('${_items.length} plat(s) · $published visible(s) par les invités',
                                  style: GoogleFonts.inter(fontSize: 12, color: _K.ink2, fontWeight: FontWeight.w700)),
                            ),
                            for (final c in kMenuCourses.keys)
                              if (_course(c).isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                                  child: Row(children: [
                                    Icon(kMenuCourseIcons[c], size: 18, color: _K.rose),
                                    const SizedBox(width: 8),
                                    Text(kMenuCourses[c]!,
                                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _K.ink)),
                                  ]),
                                ),
                                ..._course(c).map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _tile(e),
                                    )),
                              ],
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _tile(MenuEntry e) {
    return ThixGlass(
      radius: 18,
      opacity: e.published ? 0.62 : 0.35,
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      onTap: () => _openEditor(e),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 58,
              height: 58,
              child: e.imageUrl != null
                  ? Image.network(e.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: _K.roseSoft))
                  : Container(
                      color: _K.roseSoft,
                      child: Icon(kMenuCourseIcons[e.course], color: _K.rose, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: _K.ink)),
                if (e.description != null)
                  Text(e.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11.5, color: _K.ink2, height: 1.25)),
                if (e.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: e.tags.map((t) => _tagChip(kMenuTags[t] ?? t)).toList(),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch(value: e.published, activeColor: _K.green, onChanged: (v) => _togglePublished(e, v)),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (v) {
                  if (v == 'edit') _openEditor(e);
                  if (v == 'up') _move(e, -1);
                  if (v == 'down') _move(e, 1);
                  if (v == 'delete') _delete(e);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: 'up', child: Text('↑ Monter')),
                  PopupMenuItem(value: 'down', child: Text('↓ Descendre')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuEditor extends StatefulWidget {
  final String weddingId;
  final MenuEntry? existing;
  final int Function(String course) positionFor;
  final VoidCallback onSaved;
  const _MenuEditor({
    required this.weddingId,
    required this.existing,
    required this.positionFor,
    required this.onSaved,
  });

  @override
  State<_MenuEditor> createState() => _MenuEditorState();
}

class _MenuEditorState extends State<_MenuEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.existing?.description ?? '');
  late String _course = widget.existing?.course ?? 'plat';
  late final Set<String> _tags = {...?widget.existing?.tags};
  late bool _published = widget.existing?.published ?? true;
  PickedPhoto? _photo;
  bool _removePhoto = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final p = await pickPhotos(max: 1);
      if (p.isNotEmpty) setState(() { _photo = p.first; _removePhoto = false; });
    } catch (e) {
      setState(() => _error = 'Galerie inaccessible : $e');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom du plat est requis');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      String? url = widget.existing?.imageUrl;
      if (_removePhoto) url = null;
      if (_photo != null) {
        final urls = await uploadPhotos(widget.weddingId, [_photo!]);
        url = urls.first;
      }
      final supa = Supabase.instance.client;
      final row = {
        'wedding_id': widget.weddingId,
        'course': _course,
        'name': name,
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'tags': _tags.toList(),
        'image_url': url,
        'is_published': _published,
      };
      if (widget.existing == null) {
        row['position'] = widget.positionFor(_course);
        await supa.from('thix_weeding_menu_items').insert(row);
      } else {
        if (widget.existing!.course != _course) row['position'] = widget.positionFor(_course);
        await supa.from('thix_weeding_menu_items').update(row).eq('id', widget.existing!.id);
      }
      widget.onSaved();
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
    final hasOld = widget.existing?.imageUrl != null && !_removePhoto && _photo == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
        child: ThixGlass(
          radius: 28,
          opacity: 0.85,
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
                Text(widget.existing == null ? 'Ajouter un plat' : 'Modifier le plat',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _K.ink)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: kMenuCourses.entries
                      .map((e) => ChoiceChip(
                            label: Text(e.value, style: const TextStyle(fontSize: 12)),
                            selected: _course == e.key,
                            onSelected: (_) => setState(() => _course = e.key),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                _GlassField(_name, 'Nom du plat *', Icons.restaurant_rounded, maxLength: 80),
                const SizedBox(height: 4),
                _GlassField(_desc, 'Description (ingrédients, accompagnement…)', Icons.notes_rounded, maxLines: 4),
                const SizedBox(height: 10),
                Text('Régimes & infos',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _K.ink2)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: kMenuTags.entries
                      .map((e) => FilterChip(
                            label: Text(e.value, style: const TextStyle(fontSize: 11.5)),
                            selected: _tags.contains(e.key),
                            visualDensity: VisualDensity.compact,
                            onSelected: (v) => setState(() => v ? _tags.add(e.key) : _tags.remove(e.key)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (_photo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(_photo!.bytes, width: 70, height: 70, fit: BoxFit.cover),
                      )
                    else if (hasOld)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(widget.existing!.imageUrl!, width: 70, height: 70, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: _K.roseSoft)),
                      )
                    else
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(color: _K.roseSoft, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.image_outlined, color: _K.rose),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pick,
                            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                            label: Text(_photo != null || hasOld ? 'Changer' : 'Photo'),
                          ),
                          if (_photo != null || hasOld)
                            TextButton(
                              onPressed: () => setState(() { _photo = null; _removePhoto = true; }),
                              child: const Text('Retirer'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible par les invités'),
                  value: _published,
                  activeColor: _K.green,
                  onChanged: (v) => setState(() => _published = v),
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: _K.rose, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _K.rose,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Enregistrer', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
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

// ═══════════════════════════════════════════════════════════════════════════
// STAFF : PAGES D'INFOS (navette, dress_code, faq, thanks, live)
// ═══════════════════════════════════════════════════════════════════════════
class StaffInfoPage extends StatefulWidget {
  final String weddingId;
  final String kind;
  const StaffInfoPage({super.key, required this.weddingId, required this.kind});

  @override
  State<StaffInfoPage> createState() => _StaffInfoPageState();
}

class _StaffInfoPageState extends State<StaffInfoPage> {
  final _supa = Supabase.instance.client;
  List<InfoBlock> _blocks = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _ch;
  Timer? _deb;

  String get _kind => kInfoKinds.containsKey(widget.kind) ? widget.kind : 'navette';
  InfoKindMeta get _meta => kInfoKinds[_kind]!;

  @override
  void initState() {
    super.initState();
    _load();
    _ch = _supa
        .channel('staff-info-${widget.weddingId}-$_kind')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_info_blocks',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 400), () {
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
          .order('position', ascending: true)
          .order('created_at', ascending: true);
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

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? _K.rose : _K.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  int get _nextPos => _blocks.isEmpty ? 0 : _blocks.last.position + 1;

  Future<void> _toggle(InfoBlock b, bool v) async {
    try {
      await _supa.from('thix_weeding_info_blocks').update({'is_published': v}).eq('id', b.id);
      setState(() => b.published = v);
    } catch (e) {
      _toast('Erreur : $e', error: true);
    }
  }

  Future<void> _move(InfoBlock b, int dir) async {
    final i = _blocks.indexWhere((x) => x.id == b.id);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= _blocks.length) return;
    try {
      await _supa.from('thix_weeding_info_blocks').update({'position': j}).eq('id', _blocks[i].id);
      await _supa.from('thix_weeding_info_blocks').update({'position': i}).eq('id', _blocks[j].id);
      await _load(silent: true);
    } catch (e) {
      _toast('Erreur : $e', error: true);
    }
  }

  Future<void> _delete(InfoBlock b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet élément ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _K.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supa.from('thix_weeding_info_blocks').delete().eq('id', b.id);
      await _load(silent: true);
    } catch (e) {
      _toast('Suppression impossible : $e', error: true);
    }
  }

  void _openEditor([InfoBlock? b]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InfoEditor(
        weddingId: widget.weddingId,
        kind: _kind,
        meta: _meta,
        existing: b,
        nextPosition: _nextPos,
        onSaved: () => _load(silent: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _K.ink,
        title: Text(_meta.label, style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _K.rose,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: Text('Ajouter', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ThixGlassBackdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _K.rose))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur : $_error\n(Avez-vous exécuté le SQL des contenus ?)', textAlign: TextAlign.center),
                    ),
                  )
                : _blocks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_meta.icon, size: 44, color: _K.rose.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'Rien pour l\'instant.\nAjoutez du contenu : vos invités le verront dans « ${_meta.label} ».',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: _K.ink2, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(silent: true),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
                          itemCount: _blocks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _card(_blocks[i]),
                        ),
                      ),
      ),
    );
  }

  Widget _card(InfoBlock b) {
    return ThixGlass(
      radius: 20,
      opacity: b.published ? 0.62 : 0.35,
      padding: EdgeInsets.zero,
      onTap: () => _openEditor(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.images.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: Image.network(b.images.first, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _K.roseSoft)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b.title != null)
                  Text(b.title!,
                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: _K.ink)),
                if (b.body != null) ...[
                  const SizedBox(height: 4),
                  Text(b.body!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12.5, color: _K.ink, height: 1.4)),
                ],
                if (b.linkUrl != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.link_rounded, size: 15, color: _K.rose),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(b.linkUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: _K.rose, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 2, 6),
            child: Row(
              children: [
                Icon(b.published ? Icons.public_rounded : Icons.visibility_off_outlined,
                    size: 15, color: b.published ? _K.green : _K.ink2),
                const SizedBox(width: 6),
                Text(b.published ? 'Visible' : 'Masqué',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: b.published ? _K.green : _K.ink2)),
                const Spacer(),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(value: b.published, activeColor: _K.green, onChanged: (v) => _toggle(b, v)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  onPressed: () => _move(b, -1),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  onPressed: () => _move(b, 1),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: _K.rose),
                  onPressed: () => _delete(b),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoEditor extends StatefulWidget {
  final String weddingId;
  final String kind;
  final InfoKindMeta meta;
  final InfoBlock? existing;
  final int nextPosition;
  final VoidCallback onSaved;
  const _InfoEditor({
    required this.weddingId,
    required this.kind,
    required this.meta,
    required this.existing,
    required this.nextPosition,
    required this.onSaved,
  });

  @override
  State<_InfoEditor> createState() => _InfoEditorState();
}

class _InfoEditorState extends State<_InfoEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _body = TextEditingController(text: widget.existing?.body ?? '');
  late final TextEditingController _link = TextEditingController(text: widget.existing?.linkUrl ?? '');
  late List<String> _images = [...?widget.existing?.images];
  final List<PickedPhoto> _newPhotos = [];
  late bool _published = widget.existing?.published ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  int get _photoCount => _images.length + _newPhotos.length;

  Future<void> _pick() async {
    try {
      final p = await pickPhotos(max: kMaxMessagePhotos - _photoCount);
      if (p.isNotEmpty) setState(() => _newPhotos.addAll(p));
    } catch (e) {
      setState(() => _error = 'Galerie inaccessible : $e');
    }
  }

  Future<void> _save() async {
    final t = _title.text.trim(), b = _body.text.trim(), l = _link.text.trim();
    if (t.isEmpty && b.isEmpty && l.isEmpty && _photoCount == 0) {
      setState(() => _error = 'Ajoutez au moins un titre, un texte, un lien ou une photo.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final fresh = _newPhotos.isEmpty ? <String>[] : await uploadPhotos(widget.weddingId, _newPhotos);
      final row = {
        'wedding_id': widget.weddingId,
        'kind': widget.kind,
        'title': t.isEmpty ? null : t,
        'body': b.isEmpty ? null : b,
        'link_url': l.isEmpty ? null : l,
        'image_urls': [..._images, ...fresh],
        'is_published': _published,
      };
      final supa = Supabase.instance.client;
      if (widget.existing == null) {
        row['position'] = widget.nextPosition;
        await supa.from('thix_weeding_info_blocks').insert(row);
      } else {
        await supa.from('thix_weeding_info_blocks').update(row).eq('id', widget.existing!.id);
      }
      widget.onSaved();
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
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
        child: ThixGlass(
          radius: 28,
          opacity: 0.85,
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
                Row(children: [
                  Icon(widget.meta.icon, color: _K.rose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.meta.label,
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _K.ink)),
                  ),
                ]),
                Text(widget.meta.example, style: GoogleFonts.inter(fontSize: 11, color: _K.ink2)),
                const SizedBox(height: 12),
                _GlassField(_title, widget.meta.titleLabel, Icons.title_rounded, maxLength: 90),
                const SizedBox(height: 4),
                _GlassField(_body, widget.meta.bodyLabel, Icons.notes_rounded, maxLines: 6),
                const SizedBox(height: 10),
                _GlassField(_link, widget.meta.linkLabel, Icons.link_rounded),
                const SizedBox(height: 10),
                if (_images.isNotEmpty)
                  SizedBox(
                    height: 66,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_images[i], width: 66, height: 66, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () => setState(() => _images.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: _K.rose, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 13, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_images.isNotEmpty) const SizedBox(height: 8),
                PickedPhotoStrip(photos: _newPhotos, onRemove: (i) => setState(() => _newPhotos.removeAt(i))),
                if (_newPhotos.isNotEmpty) const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy || _photoCount >= kMaxMessagePhotos ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text('Photos ($_photoCount/$kMaxMessagePhotos)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible par les invités'),
                  value: _published,
                  activeColor: _K.green,
                  onChanged: (v) => setState(() => _published = v),
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: _K.rose, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _K.rose,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Enregistrer', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
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
