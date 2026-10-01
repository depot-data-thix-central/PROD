// lib/presentation/mon_pays/pages/provinces/provinces_page.dart
//
// ProvincesPage — Production Enterprise (Portail Institutionnel RDC)
// Design System ThixPolicy + i18n + Accessibilité + Pull-to-refresh

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../../models/province.dart';
import '../../providers/provinces_provider.dart';

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ProvincesPage extends ConsumerStatefulWidget {
  const ProvincesPage({super.key});

  @override
  ConsumerState<ProvincesPage> createState() => _ProvincesPageState();
}

class _ProvincesPageState extends ConsumerState<ProvincesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRegion = 'Toutes';

  static const List<String> _regions = [
    'Toutes',
    'Centre',
    'Est',
    'Ouest',
    'Nord',
    'Sud',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final region = _selectedRegion == 'Toutes' ? null : _selectedRegion;
    final provincesAsync = ref.watch(provincesProvider(region));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('mon_pays_provinces_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.onBrand,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: ThixPolicy.primary,
        foregroundColor: ThixPolicy.onBrand,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── En-tête avec Recherche et Filtres ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: ThixPolicy.primary,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: ThixPolicy.shadowCard(opacity: 0.08),
            ),
            child: Column(
              children: [
                // Barre de recherche
                Semantics(
                  textField: true,
                  label: l10n.t('mon_pays_provinces_search_hint'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ThixPolicy.card,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: ThixPolicy.bodyStyle,
                      decoration: InputDecoration(
                        hintText: l10n.t('mon_pays_provinces_search_hint'),
                        hintStyle: ThixPolicy.bodySmallStyle.copyWith(
                          color: ThixPolicy.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: ThixPolicy.inkDeep,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: ThixPolicy.textMuted,
                                  size: 20,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filtres par région (Chips horizontaux)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _regions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final r = _regions[index];
                      final isSelected = _selectedRegion == r;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: r,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedRegion = r);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ThixPolicy.card
                                  : ThixPolicy.card.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                ThixPolicy.rFull,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? ThixPolicy.card
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                r,
                                style: ThixPolicy.labelStyle.copyWith(
                                  color: isSelected
                                      ? ThixPolicy.primary
                                      : ThixPolicy.onBrand,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Liste des provinces ──
          Expanded(
            child: provincesAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: ThixPolicy.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (err, stack) => _buildErrorState(l10n, region),
              data: (provinces) {
                final query = _searchController.text.trim().toLowerCase();
                List<Province> filtered = provinces;

                if (query.isNotEmpty) {
                  filtered = provinces
                      .where((p) =>
                          p.name.toLowerCase().contains(query) ||
                          p.capital.toLowerCase().contains(query) ||
                          p.code.toLowerCase().contains(query))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return _buildEmptyState(l10n, query);
                }

                return RefreshIndicator(
                  color: ThixPolicy.primary,
                  onRefresh: () =>
                      ref.refresh(provincesProvider(region).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final province = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProvinceCard(province),
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

  // ─── Carte Province ──────────────────────────────────────────────────
  Widget _buildProvinceCard(Province province) {
    final coatUrl = province.coatOfArmsUrl;

    return Semantics(
      button: true,
      label: 'Province: ${province.name}, Capitale: ${province.capital}',
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/mon-pays/provinces/${province.id}');
        },
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border, width: 1.5),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
          ),
          child: Row(
            children: [
              // Blason / Code
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surfaceSoft,
                  border: Border.all(color: ThixPolicy.border, width: 1.5),
                  image: coatUrl != null && coatUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(coatUrl),
                          fit: BoxFit.contain,
                        )
                      : null,
                ),
                child: (coatUrl == null || coatUrl.isEmpty)
                    ? Center(
                        child: Text(
                          province.code.substring(0, 2),
                          style: ThixPolicy.h3Style.copyWith(
                            color: ThixPolicy.inkDeep,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      province.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.titleStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      province.capital,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ThixPolicy.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            province.code,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: ThixPolicy.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (province.region != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ThixPolicy.gold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              province.region!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: ThixPolicy.inkDeep,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: ThixPolicy.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── État Erreur ─────────────────────────────────────────────────────
  Widget _buildErrorState(AppLocalizations l10n, String? region) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: ThixPolicy.danger,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('mon_pays_provinces_error'),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(provincesProvider(region)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: ThixPolicy.onBrand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── État Vide ───────────────────────────────────────────────────────
  Widget _buildEmptyState(AppLocalizations l10n, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: ThixPolicy.textMuted.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('mon_pays_provinces_empty'),
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.t('mon_pays_provinces_try_other'),
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
