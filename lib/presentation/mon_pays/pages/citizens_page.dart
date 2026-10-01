// lib/presentation/mon_pays/pages/citizens_page.dart
//
// CitizensPage — "Fierté de la Nation" (liste complète + fiche détail)
// Design compact ThixPolicy, recherche, retry, détail en bottom sheet.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/mon_pays/models/exemplary_citizen.dart';
import 'package:thix_id/presentation/mon_pays/providers/citizens_provider.dart';

// ============================================================================
// PAGE LISTE
// ============================================================================
class CitizensPage extends ConsumerStatefulWidget {
  const CitizensPage({super.key});

  @override
  ConsumerState<CitizensPage> createState() => _CitizensPageState();
}

class _CitizensPageState extends ConsumerState<CitizensPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final citizensAsync = ref.watch(citizensProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: Text(
          l10n.t('mon_pays_citizens_title'),
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
          // ── Barre de recherche ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              style: ThixPolicy.bodyStyle,
              decoration: InputDecoration(
                hintText: l10n.t('mon_pays_citizens_search_hint'),
                hintStyle: ThixPolicy.bodySmallStyle,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: ThixPolicy.inkDeep, size: 20),
                filled: true,
                fillColor: ThixPolicy.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide:
                      const BorderSide(color: ThixPolicy.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Contenu ──
          Expanded(
            child: citizensAsync.when(
              loading: () => _buildSkeletonGrid(),
              error: (e, _) => _buildError(l10n),
              data: (citizens) {
                final filtered = _query.isEmpty
                    ? citizens
                    : citizens
                        .where((c) =>
                            c.fullName.toLowerCase().contains(_query) ||
                            c.domain.toLowerCase().contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 48, color: ThixPolicy.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            l10n.t('mon_pays_citizens_empty'),
                            textAlign: TextAlign.center,
                            style: ThixPolicy.bodyStyle
                                .copyWith(color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: ThixPolicy.primary,
                  onRefresh: () => ref.refresh(citizensProvider.future),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) =>
                        _CitizenCard(citizen: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceStrong,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: ThixPolicy.danger, size: 44),
            const SizedBox(height: 12),
            Text(
              l10n.t('mon_pays_citizens_error'),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle
                  .copyWith(color: ThixPolicy.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(citizensProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.t('common_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARTE CITOYEN
// ============================================================================
class _CitizenCard extends StatelessWidget {
  final ExemplaryCitizen citizen;

  const _CitizenCard({required this.citizen});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${citizen.fullName}, ${citizen.domain}',
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          showCitizenDetailSheet(context, citizen);
        },
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15)),
                  child: citizen.photoUrl != null &&
                          citizen.photoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: citizen.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              color: ThixPolicy.surfaceSoft),
                          errorWidget: (_, __, ___) => _fallbackAvatar(),
                        )
                      : _fallbackAvatar(),
                ),
              ),
              // Infos
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        citizen.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.inkDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThixPolicy.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          citizen.domain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: ThixPolicy.inkDeep,
                          ),
                        ),
                      ),
                      if (citizen.shortDescription != null &&
                          citizen.shortDescription!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          citizen.shortDescription!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.microStyle,
                        ),
                      ],
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

  Widget _fallbackAvatar() {
    return Container(
      color: ThixPolicy.surfaceSoft,
      child: Center(
        child: Icon(Icons.person_rounded,
            size: 40, color: ThixPolicy.inkDeep.withOpacity(0.4)),
      ),
    );
  }
}

// ============================================================================
// FICHE DÉTAIL (Bottom Sheet) — réutilisable depuis la homepage
// ============================================================================
void showCitizenDetailSheet(BuildContext context, ExemplaryCitizen c) {
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
      builder: (ctx, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // Poignée
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

          // En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.gold, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: ThixPolicy.surfaceSoft,
                  backgroundImage: c.photoUrl != null && c.photoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(c.photoUrl!)
                      : null,
                  child: c.photoUrl == null || c.photoUrl!.isEmpty
                      ? const Icon(Icons.person_rounded,
                          color: ThixPolicy.inkDeep, size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.fullName,
                      style: ThixPolicy.h3Style.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.domain,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (c.recognitionDate != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    size: 16, color: ThixPolicy.gold),
                const SizedBox(width: 6),
                Text(
                  '${l10n.t('mon_pays_citizen_recognition')} '
                  '${DateFormat('dd MMMM yyyy', 'fr_FR').format(c.recognitionDate!)}',
                  style: ThixPolicy.captionStyle,
                ),
              ],
            ),
          ],

          if (c.shortDescription != null &&
              c.shortDescription!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: Text(
                c.shortDescription!,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            l10n.t('mon_pays_citizen_biography'),
            style: ThixPolicy.titleStyle.copyWith(
              color: ThixPolicy.inkDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.biography.isEmpty ? '—' : c.biography,
            style: ThixPolicy.bodyStyle.copyWith(height: 1.5),
          ),

          if (c.media.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.t('mon_pays_citizen_media'),
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.inkDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.media.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final m = c.media[i];
                  final url = m['url']?.toString();
                  if (url == null || url.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 110,
                        height: 110,
                        color: ThixPolicy.surfaceSoft,
                        child: const Icon(Icons.broken_image_rounded,
                            color: ThixPolicy.textMuted),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
