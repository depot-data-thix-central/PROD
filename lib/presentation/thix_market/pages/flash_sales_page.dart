// lib/presentation/thix_market/pages/flash_sales_page.dart
// ============================================================================
// FLASH SALES PAGE — Production Enterprise (Corrected & Optimized)
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/widgets/market/flash_sale_timer.dart';
import 'package:thix_id/presentation/thix_market/widgets/products/product_card.dart';

import '../providers/market_providers.dart';

// ============================================================================
// DESIGN TOKENS — palette "Vente Exclusive"
// ============================================================================
abstract class _FlashPalette {
  static const Color bordeaux = Color(0xFF800020);
  static const Color bordeauxDeep = Color(0xFF5A0016);
  static const Color bordeauxLight = Color(0xFFB02040);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bordeauxDeep, bordeaux, Color(0xFFB30030)],
    stops: [0.0, 0.55, 1.0],
  );
}

// ============================================================================
// CONSTANTES
// ============================================================================
const int _kMaxTitleLength = 120;

// ============================================================================
// SANITIZER
// ============================================================================
abstract class _FlashSanitizer {
  static String text(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    try {
      final doc = html_parser.parse(input);
      var s = doc.body?.text ?? input;
      s = s
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
          .trim();
      return s.length > maxLength ? s.substring(0, maxLength) : s;
    } catch (_) {
      return '';
    }
  }

  static double parsePrice(dynamic input) {
    if (input == null) return 0.0;
    if (input is num) return input.toDouble();
    if (input is String) {
      return double.tryParse(input) ?? 0.0;
    }
    return 0.0;
  }
}

// ============================================================================
// ÉTAT LOCAL — TRI
// ============================================================================
enum _FlashSort {
  urgency,
  priceAsc,
  priceDesc,
  newest,
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class FlashSalesPage extends ConsumerStatefulWidget {
  const FlashSalesPage({super.key});

  @override
  ConsumerState<FlashSalesPage> createState() => _FlashSalesPageState();
}

class _FlashSalesPageState extends ConsumerState<FlashSalesPage> {
  final ScrollController _scroll = ScrollController();
  String _selectedCategory = 'all';
  _FlashSort _sort = _FlashSort.urgency;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ─── Filtres clients ─────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    final now = DateTime.now();

    // Filtre des offres actives non expirées
    var list = items.where((p) {
      final exp = p['expires_at'];
      if (exp == null) return true;
      final dt = DateTime.tryParse(exp.toString());
      return dt == null || dt.isAfter(now);
    }).toList();

    // Filtre par catégorie
    if (_selectedCategory != 'all') {
      list = list
          .where((p) => (p['category']?.toString() ?? '') == _selectedCategory)
          .toList();
    }

    // Tri sécurisé
    list.sort((a, b) {
      switch (_sort) {
        case _FlashSort.urgency:
          final aExp = DateTime.tryParse(a['expires_at']?.toString() ?? '') ??
              DateTime(2100);
          final bExp = DateTime.tryParse(b['expires_at']?.toString() ?? '') ??
              DateTime(2100);
          return aExp.compareTo(bExp);
        case _FlashSort.priceAsc:
          final aP = _FlashSanitizer.parsePrice(a['discount_price'] ?? a['price']);
          final bP = _FlashSanitizer.parsePrice(b['discount_price'] ?? b['price']);
          return aP.compareTo(bP);
        case _FlashSort.priceDesc:
          final aP = _FlashSanitizer.parsePrice(a['discount_price'] ?? a['price']);
          final bP = _FlashSanitizer.parsePrice(b['discount_price'] ?? b['price']);
          return bP.compareTo(aP);
        case _FlashSort.newest:
          final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(2000);
          final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime(2000);
          return bDate.compareTo(aDate);
      }
    });

    return list;
  }

  Set<String> _extractCategories(List<Map<String, dynamic>> items) {
    final cats = <String>{};
    for (final p in items) {
      final c = p['category']?.toString();
      if (c != null && c.trim().isNotEmpty) cats.add(c);
    }
    return cats;
  }

  DateTime? _nearestExpiration(List<Map<String, dynamic>> items) {
    DateTime? nearest;
    final now = DateTime.now();
    for (final p in items) {
      final dt = DateTime.tryParse(p['expires_at']?.toString() ?? '');
      if (dt == null) continue;
      if (!dt.isAfter(now)) continue;
      if (nearest == null || dt.isBefore(nearest)) nearest = dt;
    }
    return nearest;
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    invalidateAllMarketProviders(ref);
    await ref.read(flashSalesProvider.future);
  }

  // ─── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final flashAsync = ref.watch(flashSalesProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      extendBodyBehindAppBar: true,
      body: flashAsync.when(
        loading: () => _buildLoadingState(l10n),
        error: (e, _) => _buildErrorState(l10n, e),
        data: (items) => _buildContent(l10n, items),
      ),
    );
  }

  // ─── LOADING ─────────────────────────────────────────────────────
  Widget _buildLoadingState(AppLocalizations l10n) {
    return Stack(
      children: [
        _buildHeader(l10n, null, const []),
        const Padding(
          padding: EdgeInsets.only(top: 200),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ─── ERROR ───────────────────────────────────────────────────────
  Widget _buildErrorState(AppLocalizations l10n, Object error) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(l10n, null, const [])),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: _FlashPalette.bordeaux, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('error_generic'),
                    style: const TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.t('common_retry')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _FlashPalette.bordeaux,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── CONTENT ─────────────────────────────────────────────────────
  Widget _buildContent(
      AppLocalizations l10n, List<Map<String, dynamic>> items) {
    final filtered = _applyFilters(items);
    final categories = _extractCategories(items);
    final nearest = _nearestExpiration(filtered);

    return RefreshIndicator(
      color: _FlashPalette.bordeaux,
      backgroundColor: Colors.white,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(l10n, nearest, items)),
          if (items.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildMarqueeBanner(l10n)),
            SliverToBoxAdapter(child: _buildFiltersBar(l10n, categories)),
            SliverToBoxAdapter(child: _buildSortBar(l10n, filtered.length)),
          ],
          if (filtered.isEmpty && items.isNotEmpty)
            SliverToBoxAdapter(child: _buildNoMatch(l10n))
          else if (items.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState(l10n))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildProductTap(filtered[i]),
                  childCount: filtered.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────
  Widget _buildHeader(AppLocalizations l10n, DateTime? nearest,
      List<Map<String, dynamic>> items) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: _FlashPalette.heroGradient,
        boxShadow: [
          BoxShadow(
            color: _FlashPalette.bordeaux.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(height: top),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Row(
              children: [
                _headerIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                  tooltip: 'Retour',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _FlashSanitizer.text(l10n.t('market_flash_offers'),
                            maxLength: _kMaxTitleLength),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${items.length} ${l10n.t('market_active_offers')}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _headerIconButton(
                  icon: Icons.notifications_active_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.t('market_coming_soon',
                            args: ['Notifications flash'])),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  tooltip: 'Notifications',
                ),
              ],
            ),
          ),
          if (nearest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: _buildCountdownCard(l10n, nearest, items.length),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(21),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  // ─── COUNTDOWN CARD ──────────────────────────────────────────────
  Widget _buildCountdownCard(
      AppLocalizations l10n, DateTime nearest, int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _FlashPalette.bordeaux.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: _FlashPalette.bordeaux, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('market_next_expiry'),
                  style: const TextStyle(
                    color: ThixPolicy.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                FlashSaleTimer(endTime: nearest),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _FlashPalette.bordeaux,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BANDEAU DÉFILANT ────────────────────────────────────────────
  Widget _buildMarqueeBanner(AppLocalizations l10n) {
    final label = _FlashSanitizer.text(
      l10n.t('market_flash_sale_banner'),
      maxLength: 120,
    );
    return Container(
      height: 36,
      color: _FlashPalette.bordeauxDeep,
      child: ClipRect(
        child: _MarqueeStrip(text: label),
      ),
    );
  }

  // ─── FILTRES BAR ─────────────────────────────────────────────────
  Widget _buildFiltersBar(AppLocalizations l10n, Set<String> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 16, color: ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Text(
                l10n.t('market_filters'),
                style: const TextStyle(
                  color: ThixPolicy.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_selectedCategory != 'all')
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (mounted) setState(() => _selectedCategory = 'all');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.t('common_reset'),
                        style: const TextStyle(
                          color: _FlashPalette.bordeaux,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.close_rounded,
                          size: 12, color: _FlashPalette.bordeaux),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isAll = i == 0;
                final value = isAll ? 'all' : categories.elementAt(i - 1);
                final label = isAll
                    ? l10n.t('common_all')
                    : _FlashSanitizer.text(value, maxLength: 30);
                final selected = _selectedCategory == value;
                return _FilterChip(
                  label: label,
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (mounted) setState(() => _selectedCategory = value);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── SORT BAR ────────────────────────────────────────────────────
  Widget _buildSortBar(AppLocalizations l10n, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            '$count ${l10n.t('market_results')}',
            style: const TextStyle(
              color: ThixPolicy.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showSortSheet(l10n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded,
                      size: 14, color: _FlashPalette.bordeaux),
                  const SizedBox(width: 5),
                  Text(
                    _sortLabel(l10n),
                    style: const TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: ThixPolicy.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(AppLocalizations l10n) {
    switch (_sort) {
      case _FlashSort.urgency:
        return l10n.t('sort_urgency');
      case _FlashSort.priceAsc:
        return l10n.t('sort_price_asc');
      case _FlashSort.priceDesc:
        return l10n.t('sort_price_desc');
      case _FlashSort.newest:
        return l10n.t('sort_newest');
    }
  }

  void _showSortSheet(AppLocalizations l10n) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(
        current: _sort,
        l10n: l10n,
        onPick: (s) {
          if (mounted) setState(() => _sort = s);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ─── EMPTY / NO MATCH ────────────────────────────────────────────
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _FlashPalette.bordeaux.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flash_off_rounded,
                color: _FlashPalette.bordeaux, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('market_no_flash'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ThixPolicy.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('market_no_flash_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ThixPolicy.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(l10n.t('common_retry')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _FlashPalette.bordeaux,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatch(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.filter_alt_off_rounded,
              color: ThixPolicy.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            l10n.t('market_no_match'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ThixPolicy.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              if (mounted) setState(() => _selectedCategory = 'all');
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(l10n.t('common_reset')),
          ),
        ],
      ),
    );
  }

  // ─── PRODUCT CARD ────────────────────────────────────────────────
  Widget _buildProductTap(Map<String, dynamic> product) {
    final id = product['id']?.toString() ?? '';
    final title = _FlashSanitizer.text(
      product['title']?.toString(),
      maxLength: _kMaxTitleLength,
    );
    return Semantics(
      button: true,
      label: title.isEmpty ? 'Produit' : title,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (id.isNotEmpty) context.push('/market/product/$id');
        },
        child: ProductCard(
          product: product,
          isFlashSale: true,
        ),
      ),
    );
  }
}

// ============================================================================
// FILTER CHIP
// ============================================================================
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? _FlashPalette.bordeaux : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _FlashPalette.bordeaux : ThixPolicy.border,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _FlashPalette.bordeaux.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : ThixPolicy.textMain,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SORT SHEET
// ============================================================================
class _SortSheet extends StatelessWidget {
  final _FlashSort current;
  final AppLocalizations l10n;
  final ValueChanged<_FlashSort> onPick;

  const _SortSheet({
    required this.current,
    required this.l10n,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_FlashSort, String>{
      _FlashSort.urgency: l10n.t('sort_urgency'),
      _FlashSort.priceAsc: l10n.t('sort_price_asc'),
      _FlashSort.priceDesc: l10n.t('sort_price_desc'),
      _FlashSort.newest: l10n.t('sort_newest'),
    };

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('market_sort_by'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 12),
          ...options.entries.map((e) => _SortRow(
                label: e.value,
                selected: current == e.key,
                onTap: () => onPick(e.key),
              )),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? _FlashPalette.bordeaux.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _FlashPalette.bordeaux : Colors.transparent,
          ),
        ),
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? _FlashPalette.bordeaux
                      : ThixPolicy.textMain,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: _FlashPalette.bordeaux, size: 18),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MARQUEE STRIP (Défilement fluide continu sans saut)
// ============================================================================
class _MarqueeStrip extends StatefulWidget {
  final String text;
  const _MarqueeStrip({required this.text});

  @override
  State<_MarqueeStrip> createState() => _MarqueeStripState();
}

class _MarqueeStripState extends State<_MarqueeStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return FractionalTranslation(
          translation: Offset(-_ctrl.value * 0.5, 0.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextItem(),
              _buildTextItem(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        widget.text,
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
