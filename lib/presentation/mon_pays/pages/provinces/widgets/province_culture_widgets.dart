// lib/presentation/mon_pays/pages/provinces/widgets/province_culture_widgets.dart
//
// 🎭 CULTURE & PATRIMOINE : hymne (lecteur audio), langues, tribus,
//    monographie (histoire/climat/infra/éducation), gastronomie,
//    proverbes, personnalités célèbres.

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../../models/province.dart';
import '../../../providers/provinces_provider.dart';
import 'province_shortcut_bar.dart';

class ProvinceCultureSection extends ConsumerStatefulWidget {
  final Province province;
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceCultureSection({super.key, required this.province, required this.provinceId, required this.lang});

  @override
  ConsumerState<ProvinceCultureSection> createState() => _ProvinceCultureSectionState();
}

class _ProvinceCultureSectionState extends ConsumerState<ProvinceCultureSection> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _instrumental = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleHymn(Map<String, dynamic>? hymn) async {
    if (hymn == null) return;
    final url = (_instrumental ? hymn['instrumental_url'] : hymn['audio_url'])?.toString();
    if (url == null || url.isEmpty) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(url));
    }
    setState(() => _playing = !_playing);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.province;
    final lang = widget.lang;
    final hymnAsync = ref.watch(provinceHymnProvider(widget.provinceId));
    final tribes = p.tribes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.theater_comedy_rounded,
          color: ThixPolicy.gold,
          title: ProvinceTranslations.t('culture', lang),
          count: tribes.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───  HYMNE ───
                hymnAsync.whenOrNull(data: (hymn) {
                      if (hymn == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [ThixPolicy.gold.withOpacity(0.12), ThixPolicy.gold.withOpacity(0.03)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ThixPolicy.gold.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleHymn(hymn),
                              child: Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                  color: ThixPolicy.gold, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: ThixPolicy.gold.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
                                ),
                                child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(hymn['title']?.toString() ?? 'Hymne provincial',
                                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _verChip('Officielle', !_instrumental, () => setState(() => _instrumental = false)),
                                      const SizedBox(width: 6),
                                      _verChip('Instrumentale', _instrumental, () => setState(() => _instrumental = true)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }) ??
                    const SizedBox.shrink(),
                const SizedBox(height: 14),

                // ─── LANGUES & RESSOURCES ───
                if ((p.languages ?? '').isNotEmpty) _infoRow(Icons.forum_rounded, ThixPolicy.primary, 'Langues : ', p.languages!),
                if ((p.resources ?? '').isNotEmpty) _infoRow(Icons.diamond_rounded, ThixPolicy.gold, 'Ressources : ', p.resources!),
                if ((p.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(p.description!, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.5)),
                ],

                // ─── TRIBUS ───
                if (tribes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Peuples & Tribus', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: tribes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final t = tribes[i];
                        final name = t['name']?.toString() ?? 'Tribu';
                        final zone = t['zone']?.toString() ?? '';
                        final history = t['history']?.toString() ?? '';
                        return SizedBox(
                          width: 220,
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            radius: 16,
                            onTap: () => showGlassSheet(
                              context,
                              title: name,
                              subtitle: zone.isNotEmpty ? 'Zone : $zone' : null,
                              icon: Icons.groups_rounded,
                              children: [
                                if (history.isNotEmpty)
                                  Text(history, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.6)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.groups_rounded, color: ThixPolicy.primary, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (zone.isNotEmpty)
                                  Text('📍 $zone', maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Text(history, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ─── MONOGRAPHIE ───
                if ((p.history ?? p.climate ?? p.infrastructure ?? p.education ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Monographie', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if ((p.history ?? '').isNotEmpty) _monoTile('Histoire & Origines', p.history!, Icons.menu_book_rounded),
                  if ((p.climate ?? '').isNotEmpty) _monoTile('Climat & Relief', p.climate!, Icons.wb_sunny_rounded),
                  if ((p.infrastructure ?? '').isNotEmpty) _monoTile('Infrastructures', p.infrastructure!, Icons.bolt_rounded),
                  if ((p.education ?? '').isNotEmpty) _monoTile('Éducation & Santé', p.education!, Icons.school_rounded),
                ],

                // ─── GASTRONOMIE ───
                Consumer(builder: (context, ref, _) {
                  return ref.watch(provinceGastronomyProvider(widget.provinceId)).whenOrNull(data: (items) {
                        if (items.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Text('Gastronomie', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 190,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (_, i) {
                                  final g = items[i];
                                  final img = (g['image_url'] ?? '').toString();
                                  return SizedBox(
                                    width: 200,
                                    child: GlassCard(
                                      padding: EdgeInsets.zero,
                                      radius: 16,
                                      onTap: () {
                                        final ingredients = (g['ingredients'] is List)
                                            ? (g['ingredients'] as List).map((e) => e.toString()).toList()
                                            : (g['ingredients']?.toString() ?? '').split(',').where((e) => e.trim().isNotEmpty).toList();
                                        showGlassSheet(
                                          context,
                                          title: g['name']?.toString() ?? '',
                                          subtitle: g['description']?.toString(),
                                          imageUrl: img.isNotEmpty ? img : null,
                                          icon: Icons.restaurant_rounded,
                                          color: const Color(0xFFD81B60),
                                          children: [
                                            if (ingredients.isNotEmpty) ...[
                                              Text('Ingrédients', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6, runSpacing: 6,
                                                children: ingredients.map((ing) => Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(color: const Color(0xFFD81B60).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                                      child: Text(ing.trim(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD81B60))),
                                                    )).toList(),
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          img.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                  child: CachedNetworkImage(imageUrl: img, height: 90, width: double.infinity, fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) => Container(height: 90, color: ThixPolicy.surfaceSoft)))
                                              : Container(height: 90, color: ThixPolicy.surfaceSoft),
                                          Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(g['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                                                Text(g['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      }) ??
                      const SizedBox.shrink();
                }),

                // ─── PROVERBES ───
                Consumer(builder: (context, ref, _) {
                  return ref.watch(provinceProverbsProvider(widget.provinceId)).whenOrNull(data: (items) {
                        if (items.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Text('Proverbes & Contes', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 160,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (_, i) {
                                  final pr = items[i];
                                  return SizedBox(
                                    width: 240,
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(12),
                                      radius: 16,
                                      onTap: () => showGlassSheet(
                                        context,
                                        title: pr['text']?.toString() ?? '',
                                        subtitle: pr['translation']?.toString(),
                                        icon: Icons.format_quote_rounded,
                                        color: const Color(0xFF00897B),
                                        children: [
                                          if ((pr['meaning'] ?? '').toString().isNotEmpty)
                                            Text(pr['meaning'].toString(), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.6)),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF00897B)),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFF00897B).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                                child: Text(pr['language']?.toString() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF00897B))),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('"${pr['text'] ?? ''}"', maxLines: 2, overflow: TextOverflow.ellipsis,
                                              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
                                          const Spacer(),
                                          Text(pr['translation']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                              style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      }) ??
                      const SizedBox.shrink();
                }),

                // ─── PERSONNALITÉS ───
                Consumer(builder: (context, ref, _) {
                  return ref.watch(provinceFamousPeopleProvider(widget.provinceId)).whenOrNull(data: (items) {
                        if (items.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Text('Personnalités célèbres', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 190,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (_, i) {
                                  final f = items[i];
                                  final photo = (f['photo_url'] ?? '').toString();
                                  return SizedBox(
                                    width: 200,
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(12),
                                      radius: 16,
                                      onTap: () => showGlassSheet(
                                        context,
                                        title: f['name']?.toString() ?? '',
                                        subtitle: f['bio']?.toString(),
                                        imageUrl: photo.isNotEmpty ? photo : null,
                                        icon: Icons.emoji_events_rounded,
                                        color: ThixPolicy.gold,
                                        children: [
                                          if ((f['achievement'] ?? '').toString().isNotEmpty)
                                            sheetRow(Icons.workspace_premium_rounded, 'Distinction', f['achievement'].toString(), color: ThixPolicy.gold),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 62, height: 62,
                                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.gold, width: 2)),
                                            child: ClipOval(
                                              child: photo.isNotEmpty
                                                  ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: ThixPolicy.textMuted))
                                                  : const Icon(Icons.person, color: ThixPolicy.textMuted),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(f['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
                                          Text(f['field']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: FontWeight.w800)),
                                          const Spacer(),
                                          if ((f['achievement'] ?? '').toString().isNotEmpty)
                                            Text(f['achievement'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      }) ??
                      const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _verChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? ThixPolicy.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? ThixPolicy.gold : ThixPolicy.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: selected ? Colors.white : ThixPolicy.textSecondary)),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                    TextSpan(text: value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _monoTile(String label, String content, IconData icon) => InkWell(
        onTap: () => showGlassSheet(
          context,
          title: label,
          icon: icon,
          children: [Text(content, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.6))],
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: ThixPolicy.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: ThixPolicy.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              Text(content, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5)),
            ],
          ),
        ),
      );
}
