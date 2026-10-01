import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../models/historical_figure.dart';
import '../providers/historical_figures_provider.dart';

// ════════════════════════════════════════════════════════════════
// PAGE LISTE COMPLÈTE
// ════════════════════════════════════════════════════════════════
class HistoricalFiguresPage extends ConsumerStatefulWidget {
  const HistoricalFiguresPage({super.key});

  @override
  ConsumerState<HistoricalFiguresPage> createState() =>
      _HistoricalFiguresPageState();
}

class _HistoricalFiguresPageState extends ConsumerState<HistoricalFiguresPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final figuresAsync = ref.watch(historicalFiguresProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: Text(
          l10n.t('mon_pays_figures_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: ThixPolicy.inkDeep,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Recherche ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              style: ThixPolicy.bodyStyle,
              decoration: InputDecoration(
                hintText: l10n.t('mon_pays_figures_search_hint'),
                hintStyle: ThixPolicy.bodySmallStyle,
                prefixIcon:
                    const Icon(Icons.search_rounded, color: ThixPolicy.inkDeep),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Liste ──
          Expanded(
            child: figuresAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 96,
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceStrong,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                ),
              ),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: ThixPolicy.danger, size: 40),
                    const SizedBox(height: 12),
                    Text(l10n.t('mon_pays_figures_error'),
                        style: ThixPolicy.bodySmallStyle),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.invalidate(historicalFiguresProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.t('common_retry')),
                    ),
                  ],
                ),
              ),
              data: (figures) {
                final filtered = _query.isEmpty
                    ? figures
                    : figures
                        .where((f) =>
                            f.fullName.toLowerCase().contains(_query) ||
                            f.role.toLowerCase().contains(_query) ||
                            f.category.toLowerCase().contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.t('mon_pays_figures_empty'),
                      style: ThixPolicy.bodySmallStyle,
                    ),
                  );
                }

                return RefreshIndicator(
                  color: ThixPolicy.primary,
                  onRefresh: () => ref.refresh(historicalFiguresProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final f = filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            showHistoricalFigureSheet(context, f);
                          },
                          borderRadius:
                              BorderRadius.circular(ThixPolicy.rMd),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThixPolicy.card,
                              borderRadius:
                                  BorderRadius.circular(ThixPolicy.rMd),
                              border: Border.all(color: ThixPolicy.border),
                              boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
                            ),
                            child: Row(
                              children: [
                                _avatar(f, 56),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f.fullName,
                                        style: ThixPolicy.titleStyle.copyWith(
                                          color: ThixPolicy.inkDeep,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        f.role,
                                        style: ThixPolicy.captionStyle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          _chip(f.era),
                                          const SizedBox(width: 6),
                                          _chip(f.category),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: ThixPolicy.textMuted, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: ThixPolicy.inkDeep,
        ),
      ),
    );
  }

  Widget _avatar(HistoricalFigure f, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ThixPolicy.gold, width: 2),
      ),
      child: ClipOval(
        child: f.photoUrl != null && f.photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: f.photoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.person_rounded, size: 28,
                        color: ThixPolicy.inkDeep),
              )
            : Container(
                color: ThixPolicy.surfaceSoft,
                child: const Icon(Icons.person_rounded,
                    size: 28, color: ThixPolicy.inkDeep),
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TUILE COMPACTE (homepage)
// ════════════════════════════════════════════════════════════════
class HistoricalFigureTile extends StatelessWidget {
  final HistoricalFigure figure;

  const HistoricalFigureTile({super.key, required this.figure});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        showHistoricalFigureSheet(context, figure);
      },
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.gold, width: 2.5),
              ),
              child: ClipOval(
                child: figure.photoUrl != null && figure.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: figure.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            size: 34,
                            color: ThixPolicy.inkDeep),
                      )
                    : Container(
                        color: ThixPolicy.surfaceSoft,
                        child: const Icon(Icons.person_rounded,
                            size: 34, color: ThixPolicy.inkDeep),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              figure.fullName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.inkDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              figure.era,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FICHE DÉTAIL (bottom sheet) — réutilisable homepage + page
// ════════════════════════════════════════════════════════════════
void showHistoricalFigureSheet(BuildContext context, HistoricalFigure f) {
  final l10n = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ThixPolicy.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── En-tête ──
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.gold, width: 2.5),
                ),
                child: ClipOval(
                  child: f.photoUrl != null && f.photoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: f.photoUrl!, fit: BoxFit.cover)
                      : Container(
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.person_rounded,
                              size: 32, color: ThixPolicy.inkDeep),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.fullName,
                      style: ThixPolicy.h3Style.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(f.role, style: ThixPolicy.captionStyle),
                    const SizedBox(height: 6),
                    Text(
                      f.era,
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Citation ──
          if (f.quote != null && f.quote!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThixPolicy.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.gold.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded,
                      color: ThixPolicy.gold, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '« ${f.quote} »',
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        fontStyle: FontStyle.italic,
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Biographie ──
          const SizedBox(height: 20),
          Text(
            l10n.t('mon_pays_figure_biography'),
            style: ThixPolicy.titleStyle.copyWith(
              color: ThixPolicy.inkDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            f.biography.isEmpty ? '—' : f.biography,
            style: ThixPolicy.bodyStyle.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
