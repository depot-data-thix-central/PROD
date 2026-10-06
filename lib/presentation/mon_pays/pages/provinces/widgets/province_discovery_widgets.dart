// lib/presentation/mon_pays/pages/provinces/widgets/province_discovery_widgets.dart
//
// 🌊 SECTIONS DÉCOUVERTE (fluides, horizontales) :
// news, projets, services, engagement, budget, démographie, documents,
// média, carte, galerie, villes, découpage, tourisme, économie, identité visuelle.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../../models/province.dart';
import '../../../providers/provinces_provider.dart';
import 'province_shortcut_bar.dart';

void _launch(String url) async {
  var u = url.trim();
  if (!u.startsWith('http')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Widget _img(String url, {double? h, double? w, BoxFit fit = BoxFit.cover, double radius = 0}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url, height: h, width: w, fit: fit,
        placeholder: (_, __) => Container(height: h, width: w, color: ThixPolicy.surfaceSoft),
        errorWidget: (_, __, ___) => Container(
          height: h, width: w, color: ThixPolicy.surfaceSoft,
          child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted),
        ),
      ),
    );

// ════════════════════════════════════════════════════════════════════════
// 📢 ACTUALITÉS
// ════════════════════════════════════════════════════════════════════════
class ProvinceNewsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceNewsSection({super.key, required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceNewsProvider(provinceId)).when(
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: HScroll(height: 210, itemWidth: 290, children: [
              SkeletonBox(width: 290, height: 210), SkeletonBox(width: 290, height: 210),
            ]),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  icon: Icons.newspaper_rounded,
                  color: const Color(0xFF1E88E5),
                  title: ProvinceTranslations.t('news', lang),
                  count: items.length,
                  onViewAll: () => showGlassSheet(
                    context,
                    title: ProvinceTranslations.t('news', lang),
                    icon: Icons.newspaper_rounded,
                    color: const Color(0xFF1E88E5),
                    children: items
                        .map((n) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                padding: const EdgeInsets.all(12),
                                onTap: () {
                                  final u = n['url']?.toString();
                                  if (u != null && u.isNotEmpty) _launch(u);
                                },
                                child: Row(
                                  children: [
                                    if ((n['image_url'] ?? '').toString().isNotEmpty)
                                      _img(n['image_url'].toString(), h: 56, w: 56, radius: 12),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(n['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                              style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
                                          Text(n['published_at']?.toString().split('T').first ?? '',
                                              style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                HScroll(
                  height: 210,
                  itemWidth: 290,
                  children: items.map((n) => _NewsCard(item: n)).toList(),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isAlert = item['is_alert'] == true;
    final img = (item['image_url'] ?? '').toString();
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () {
        final u = item['url']?.toString();
        if (u != null && u.isNotEmpty) _launch(u);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              img.isNotEmpty ? _img(img, h: 112, w: double.infinity) : Container(height: 112, color: ThixPolicy.surfaceSoft),
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: isAlert ? ThixPolicy.danger : const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(6)),
                  child: Text(item['category']?.toString() ?? 'INFO',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .8)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(item['summary']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(item['published_at']?.toString().split('T').first ?? '',
                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1E88E5)),
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

// ════════════════════════════════════════════════════════════════════════
// 🏗️ PROJETS EN COURS
// ════════════════════════════════════════════════════════════════════════
class ProvinceProjectsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceProjectsSection({super.key, required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceProjectsProvider(provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.construction_rounded, color: const Color(0xFFFB8C00),
                    title: ProvinceTranslations.t('projects', lang), count: items.length),
                HScroll(height: 200, itemWidth: 280, children: items.map((p) => _ProjectCard(item: p)).toList()),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}

class _ProjectCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProjectCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final progress = ((item['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final color = pct >= 75 ? const Color(0xFF43A047) : pct >= 50 ? const Color(0xFFFB8C00) : const Color(0xFF1E88E5);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showGlassSheet(
        context,
        title: item['name']?.toString() ?? '',
        subtitle: item['description']?.toString(),
        imageUrl: item['image_url']?.toString(),
        icon: Icons.construction_rounded,
        color: color,
        children: [
          sheetRow(Icons.payments_rounded, 'Budget', item['budget']?.toString() ?? '-'),
          sheetRow(Icons.event_rounded, 'Échéance', item['deadline']?.toString() ?? '-'),
          sheetRow(Icons.trending_up_rounded, 'Progression', '$pct%', color: color),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 46, height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 46, height: 46,
                      child: CircularProgressIndicator(value: progress, strokeWidth: 5, backgroundColor: color.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(color)),
                    ),
                    Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(item['category']?.toString() ?? 'PROJET',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: .8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('💰 ${item['budget'] ?? '-'}', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('📅 ${item['deadline'] ?? '-'}', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 🏛️ SERVICES PUBLICS
// ════════════════════════════════════════════════════════════════════════
class ProvinceServicesSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceServicesSection({super.key, required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceServicesProvider(provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.badge_rounded, color: const Color(0xFF43A047),
                    title: ProvinceTranslations.t('services', lang), count: items.length),
                HScroll(height: 165, itemWidth: 250, children: items.map((s) => _ServiceCard(item: s)).toList()),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ServiceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00), Color(0xFF8E24AA), Color(0xFFE53935)];
    final color = colors[(item['category']?.toString().hashCode ?? 0).abs() % colors.length];
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showGlassSheet(
        context,
        title: item['name']?.toString() ?? '',
        subtitle: item['description']?.toString(),
        icon: Icons.badge_rounded,
        color: color,
        children: [
          sheetRow(Icons.category_rounded, 'Catégorie', item['category']?.toString() ?? '-'),
          sheetRow(Icons.access_time_rounded, 'Horaires', item['hours']?.toString() ?? '-'),
          sheetRow(Icons.location_on_rounded, 'Adresse', item['address']?.toString() ?? '-'),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.badge_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item['category']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.microStyle.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: .8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: ThixPolicy.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(item['hours']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 🗳️ ENGAGEMENT CITOYEN
// ════════════════════════════════════════════════════════════════════════
class ProvinceEngagementSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceEngagementSection({super.key, required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceEngagementsProvider(provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.how_to_vote_rounded, color: const Color(0xFF8E24AA),
                    title: ProvinceTranslations.t('citizen', lang), count: items.length),
                HScroll(height: 200, itemWidth: 270, children: items.map((e) => _EngagementCard(item: e, provinceId: provinceId, ref: ref)).toList()),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}

class _EngagementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String provinceId;
  final WidgetRef ref;
  const _EngagementCard({required this.item, required this.provinceId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString() ?? 'SONDAGE';
    final color = type.toLowerCase() == 'vote'
        ? const Color(0xFF43A047)
        : type.toLowerCase() == 'pétition'
            ? const Color(0xFFFB8C00)
            : const Color(0xFF8E24AA);
    final participants = (item['participants_count'] as num?)?.toInt() ?? 0;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(type.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: .8)),
          ),
          const SizedBox(height: 8),
          Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(item['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          Row(
            children: [
              Icon(Icons.people_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(fmtNum(participants), style: ThixPolicy.captionStyle.copyWith(color: color, fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await ref.read(provincesServiceProvider).incrementParticipants(item['id'].toString());
                  ref.invalidate(provinceEngagementsProvider(provinceId));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                  child: const Text('Participer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 💰 BUDGET + 📈 DÉMOGRAPHIE
// ════════════════════════════════════════════════════════════════════════
class ProvinceBudgetSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceBudgetSection({super.key, required this.provinceId, required this.lang});

  static const _palette = [
    Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00),
    Color(0xFF8E24AA), Color(0xFFE53935), Color(0xFF5E35B1),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceBudgetChartProvider(provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            final total = items.fold<num>(0, (s, i) => s + ((i['amount'] as num?) ?? 0));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF43A047),
                    title: ProvinceTranslations.t('budget', lang), count: items.length),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              centerSpaceRadius: 42,
                              sectionsSpace: 2,
                              sections: items.asMap().entries.map((e) {
                                final pct = ((e.value['percentage'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0);
                                return PieChartSectionData(
                                  color: _palette[e.key % _palette.length],
                                  value: pct,
                                  radius: 48,
                                  title: '${pct.toInt()}%',
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10, runSpacing: 6,
                          children: items.asMap().entries.map((e) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 9, height: 9, decoration: BoxDecoration(color: _palette[e.key % _palette.length], borderRadius: BorderRadius.circular(3))),
                                const SizedBox(width: 5),
                                Text(e.value['sector']?.toString() ?? '',
                                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700)),
                              ],
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF43A047).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text('Total : ${fmtNum(total)} USD',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF43A047))),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}

class ProvinceDemographicsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceDemographicsSection({super.key, required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceDemographicsProvider(provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.length < 2) return const SizedBox.shrink();
            final maxY = items.fold<num>(0, (m, i) {
              final v = (i['population'] as num?)?.toDouble() ?? 0;
              return v > m ? v : m;
            }) * 1.15;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_rounded, size: 18, color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Text('Démographie', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          maxY: maxY,
                          alignment: BarChartAlignment.spaceAround,
                          barTouchData: BarTouchData(enabled: false),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    v.toInt() < items.length ? (items[v.toInt()]['year']?.toString() ?? '') : '',
                                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          barGroups: items.asMap().entries.map((e) {
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: (e.value['population'] as num?)?.toDouble() ?? 0,
                                  width: 26,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                  gradient: const LinearGradient(
                                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 📄 DOCUMENTS + 🎥 MÉDIA
// ════════════════════════════════════════════════════════════════════════
class ProvinceDocumentsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceDocumentsSection({super.key, required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceDocumentsProvider(provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.description_rounded, color: const Color(0xFF5E35B1),
                    title: ProvinceTranslations.t('docs', lang), count: items.length),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: items.map((d) {
                        return InkWell(
                          onTap: () {
                            final u = d['file_url']?.toString();
                            if (u != null && u.isNotEmpty) _launch(u);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(color: const Color(0xFF5E35B1).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.gavel_rounded, color: Color(0xFF5E35B1), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                                      Text('${d['type'] ?? ''} • ${d['published_at']?.toString().split('T').first ?? ''}',
                                          style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.download_rounded, size: 18, color: Color(0xFF5E35B1)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}

class ProvinceMediaSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const ProvinceMediaSection({super.key, required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provinceMediaProvider(provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.play_circle_rounded, color: const Color(0xFFE53935),
                    title: ProvinceTranslations.t('media', lang), count: items.length),
                HScroll(height: 190, itemWidth: 250, children: items.map((m) => _MediaCard(item: m)).toList()),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}

class _MediaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MediaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final thumb = (item['thumbnail_url'] ?? '').toString();
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () {
        final u = item['url']?.toString();
        if (u != null && u.isNotEmpty) _launch(u);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              thumb.isNotEmpty ? _img(thumb, h: 110, w: double.infinity) : Container(height: 110, color: ThixPolicy.surfaceSoft),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFE53935), size: 26),
              ),
              if ((item['duration'] ?? '').toString().isNotEmpty)
                Positioned(
                  bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                    child: Text(item['duration'].toString(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 🗺️ CARTE + 🖼️ GALERIE + 🎨 IDENTITÉ VISUELLE
// ════════════════════════════════════════════════════════════════════════
class ProvinceMapCard extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceMapCard({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final url = province.mapUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.map_rounded, color: ThixPolicy.primary, title: ProvinceTranslations.t('map', lang)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: EdgeInsets.zero,
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: GlassCard(
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    minScale: 1, maxScale: 4,
                    child: _img(url, h: 380, w: double.infinity),
                  ),
                ),
              ),
            ),
            child: Stack(
              children: [
                _img(url, h: 190, w: double.infinity, radius: 24),
                Positioned(
                  right: 10, bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ProvinceGallerySection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceGallerySection({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final media = province.galleryMedia;
    if (media.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.photo_library_rounded,
          color: ThixPolicy.primary,
          title: ProvinceTranslations.t('gallery', lang),
          count: media.length,
          onViewAll: () => showGlassSheet(
            context,
            title: ProvinceTranslations.t('gallery', lang),
            icon: Icons.photo_library_rounded,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: media.length,
                itemBuilder: (_, i) => _img(media[i]['url']?.toString() ?? '', h: 100, radius: 12),
              ),
            ],
          ),
        ),
        HScroll(height: 150, itemWidth: 160, children: media.map((m) => _img(m['url']?.toString() ?? '', h: 150, w: 160, radius: 20)).toList()),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ProvinceVisualIdentitySection extends StatelessWidget {
  final Province province;
  const ProvinceVisualIdentitySection({super.key, required this.province});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _thumb(context, 'Couverture', province.coverImageUrl, Icons.image_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _thumb(context, 'Blason', province.coatOfArmsUrl, Icons.shield_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _thumb(context, 'Drapeau', province.flagUrl, Icons.flag_outlined)),
              ],
            ),
            if ((province.website ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _launch(province.website!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.language_rounded, size: 15, color: ThixPolicy.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(province.website!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context, String label, String? url, IconData fallback) {
    final has = url != null && url.isNotEmpty;
    return GestureDetector(
      onTap: has ? () => showGlassSheet(context, title: label, imageUrl: url, children: const []) : null,
      child: Column(
        children: [
          Container(
            height: 70,
            decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)),
            child: has
                ? _img(url, h: 70, w: double.infinity, radius: 12)
                : Icon(fallback, color: ThixPolicy.textMuted.withOpacity(0.4), size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 🏙️ VILLES + 🧭 DÉCOUPAGE + ⛰️ TOURISME + 💼 ÉCONOMIE
// ════════════════════════════════════════════════════════════════════════
class ProvinceCitiesSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceCitiesSection({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.cities.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.location_city_rounded, color: const Color(0xFF1565C0),
            title: ProvinceTranslations.t('cities', lang), count: province.cities.length),
        HScroll(
          height: 185,
          itemWidth: 220,
          children: province.cities.map((c) {
            final dyn = c as dynamic;
            final img = (dyn.imageUrl ?? '').toString();
            return GlassCard(
              padding: EdgeInsets.zero,
              onTap: () => showGlassSheet(
                context,
                title: c.name,
                subtitle: c.isCapital ? 'Chef-lieu de la province' : null,
                imageUrl: img.isNotEmpty ? img : null,
                icon: Icons.location_city_rounded,
                color: const Color(0xFF1565C0),
                children: [
                  if (c.population != null) sheetRow(Icons.groups_rounded, 'Population', '${fmtNum(c.population!)} hab'),
                  if ((c.mayor ?? '').isNotEmpty) sheetRow(Icons.person_rounded, 'Maire', c.mayor!),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      img.isNotEmpty ? _img(img, h: 90, w: double.infinity) : Container(height: 90, color: const Color(0xFF1565C0).withOpacity(0.08), child: const Icon(Icons.location_city_rounded, color: Color(0xFF1565C0), size: 34)),
                      if (c.isCapital)
                        Positioned(
                          top: 6, left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFF8A6B00), borderRadius: BorderRadius.circular(6)),
                            child: const Text('CHEF-LIEU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .8)),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                        if (c.population != null)
                          Text('${fmtNum(c.population!)} hab', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ProvinceDivisionsSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceDivisionsSection({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.administrativeDivisions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.dashboard_customize_rounded, color: const Color(0xFF6A1B9A),
            title: 'Découpage administratif', count: province.administrativeDivisions.length),
        HScroll(
          height: 150,
          itemWidth: 230,
          children: province.administrativeDivisions.map((d) {
            final dyn = d as dynamic;
            return GlassCard(
              padding: const EdgeInsets.all(12),
              onTap: () => showGlassSheet(
                context,
                title: dyn.name?.toString() ?? '',
                icon: Icons.dashboard_customize_rounded,
                color: const Color(0xFF6A1B9A),
                children: [
                  sheetRow(Icons.category_rounded, 'Type', dyn.type?.toString() ?? '-'),
                  if ((dyn.capital ?? '').toString().isNotEmpty) sheetRow(Icons.star_rounded, 'Chef-lieu', dyn.capital.toString()),
                  if ((dyn.administrator ?? '').toString().isNotEmpty) sheetRow(Icons.person_rounded, 'Administrateur', dyn.administrator.toString()),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF6A1B9A), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(dyn.name?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(dyn.type?.toString() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6A1B9A))),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ProvinceTourismSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceTourismSection({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.tourismSites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.landscape_rounded, color: const Color(0xFF1565C0),
            title: ProvinceTranslations.t('tourism', lang), count: province.tourismSites.length),
        HScroll(
          height: 200,
          itemWidth: 240,
          children: province.tourismSites.map((s) {
            final dyn = s as dynamic;
            final media = (dyn.media as List?) ?? [];
            final img = media.isNotEmpty ? (media.first['url']?.toString() ?? '') : '';
            return GlassCard(
              padding: EdgeInsets.zero,
              onTap: () => showGlassSheet(
                context,
                title: dyn.name?.toString() ?? '',
                subtitle: dyn.description?.toString(),
                imageUrl: img.isNotEmpty ? img : null,
                icon: Icons.landscape_rounded,
                color: const Color(0xFF1565C0),
                children: [
                  if ((dyn.type ?? '').toString().isNotEmpty) sheetRow(Icons.category_rounded, 'Type', dyn.type.toString()),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      img.isNotEmpty ? _img(img, h: 110, w: double.infinity) : Container(height: 110, color: const Color(0xFF1565C0).withOpacity(0.08), child: const Icon(Icons.landscape_rounded, color: Color(0xFF1565C0), size: 34)),
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(6)),
                          child: Text(dyn.type?.toString() ?? 'SITE', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .8)),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(dyn.name?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ProvinceEconomySection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceEconomySection({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final resources = province.economicResources;
    if (resources.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.storefront_rounded, color: const Color(0xFF2E7D32),
            title: ProvinceTranslations.t('economy', lang), count: resources.length),
        HScroll(
          height: 165,
          itemWidth: 250,
          children: resources.map((r) {
            return GlassCard(
              padding: const EdgeInsets.all(12),
              onTap: () => showGlassSheet(
                context,
                title: r.name,
                subtitle: r.description,
                icon: Icons.monetization_on_rounded,
                color: const Color(0xFF2E7D32),
                children: const [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF2E7D32), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(r.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
