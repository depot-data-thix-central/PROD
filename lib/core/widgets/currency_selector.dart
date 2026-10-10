import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/thix_design_policy.dart';
import '../extensions/context_ext.dart';
import '../providers/currency_provider.dart';
import '../utils/currency_registry.dart';

/// ============================================================================
/// CurrencySelector
/// ============================================================================
class CurrencySelector extends ConsumerWidget {
  final bool compact;

  const CurrencySelector({super.key, this.compact = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currencyProvider);
    final l10n = context.l10n;

    if (compact) {
      return InkWell(
        onTap: () => _showSheet(context),
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ThixPolicy.s10,
            vertical: ThixPolicy.s6,
          ),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                size: 14,
                color: ThixPolicy.domainReservation,
              ),
              SizedBox(width: ThixPolicy.s4),
              Text(
                state.currency.code,
                style: ThixPolicy.labelStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              SizedBox(width: ThixPolicy.s2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: ThixPolicy.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    // Utilisation directe du widget extrait
    return const _CurrencySheetContent();
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CurrencySheet(),
    );
  }
}

class _CurrencySheet extends ConsumerStatefulWidget {
  const _CurrencySheet();

  @override
  ConsumerState<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends ConsumerState<_CurrencySheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        // On passe le contrôleur de recherche et le scroll au contenu
        return _CurrencySheetContent(
          searchControllerValue: _search,
          onSearchChanged: (v) => setState(() => _search = v),
          scrollController: scrollController,
        );
      },
    );
  }
}

/// ============================================================================
/// _CurrencySheetContent — Contenu réutilisable de la feuille de sélection
/// ============================================================================
class _CurrencySheetContent extends ConsumerWidget {
  final String? searchControllerValue;
  final Function(String)? onSearchChanged;
  final ScrollController? scrollController;

  const _CurrencySheetContent({
    this.searchControllerValue,
    this.onSearchChanged,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(currencyProvider).currency;
    
    // Gestion de l'état de recherche : soit via callback (depuis _CurrencySheet), soit vide (depuis CurrencySelector non compact)
    final search = searchControllerValue ?? '';

    final filtered = search.isEmpty
        ? CurrencyRegistry.all
        : CurrencyRegistry.all.where((c) {
            final q = search.toLowerCase();
            return c.code.toLowerCase().contains(q) ||
                c.name.toLowerCase().contains(q) ||
                c.symbol.toLowerCase().contains(q) ||
                c.countries.any((co) => co.toLowerCase().contains(q));
          }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.r2Xl)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: EdgeInsets.only(top: ThixPolicy.s12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Title
          Padding(
            padding: EdgeInsets.all(ThixPolicy.s16),
            child: Row(
              children: [
                Icon(
                  Icons.currency_exchange_rounded,
                  color: ThixPolicy.domainReservation,
                ),
                SizedBox(width: ThixPolicy.s8),
                // CORRECTION: Suppression du 2ème argument (fallback) car la clé existe
                Text(
                  l10n.t('wallet_currency_title'), 
                  style: ThixPolicy.h3Style
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                // CORRECTION: Suppression du 2ème argument
                hintText: l10n.t('common_search_hint'),
                prefixIcon: Icon(Icons.search_rounded, color: ThixPolicy.textSecondary),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => onSearchChanged?.call(''),
                      )
                    : null,
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          SizedBox(height: ThixPolicy.s12),

          // Popular section (si pas de recherche)
          if (search.isEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  // CORRECTION: Suppression du 2ème argument
                  l10n.t('market_popular'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(height: ThixPolicy.s8),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                itemCount: CurrencyRegistry.popular.length,
                separatorBuilder: (_, __) => SizedBox(width: ThixPolicy.s8),
                itemBuilder: (ctx, i) {
                  final c = CurrencyRegistry.popular[i];
                  final isSelected = c.code == current.code;
                  return _PopularChip(
                    currency: c,
                    isSelected: isSelected,
                    onTap: () => _select(ref, c),
                  );
                },
              ),
            ),
            SizedBox(height: ThixPolicy.s16),
          ],

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      // CORRECTION: Suppression du 2ème argument
                      l10n.t('edu_no_result'),
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        color: ThixPolicy.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      final isSelected = c.code == current.code;
                      return _CurrencyTile(
                        currency: c,
                        isSelected: isSelected,
                        onTap: () => _select(ref, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, ThixCurrency c) {
    ref.read(currencyProvider.notifier).setCurrencyObj(c);
    // Vérifie si on est dans un contexte navigable avant de pop
    if (Navigator.canPop(ref.context)) {
      Navigator.pop(ref.context);
    }
  }
}

class _PopularChip extends StatelessWidget {
  final ThixCurrency currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _PopularChip({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s14, vertical: ThixPolicy.s10),
        decoration: BoxDecoration(
          color: isSelected ? ThixPolicy.domainReservation : ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          border: Border.all(
            color: isSelected ? ThixPolicy.domainReservation : ThixPolicy.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency.symbol,
              style: ThixPolicy.labelStyle.copyWith(
                color: isSelected ? Colors.white : ThixPolicy.textMain,
                fontWeight: ThixPolicy.bold,
              ),
            ),
            SizedBox(width: ThixPolicy.s6),
            Text(
              currency.code,
              style: ThixPolicy.labelStyle.copyWith(
                color: isSelected ? Colors.white : ThixPolicy.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  final ThixCurrency currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyTile({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      child: Container(
        padding: EdgeInsets.all(ThixPolicy.s12),
        margin: EdgeInsets.only(bottom: ThixPolicy.s4),
        decoration: BoxDecoration(
          color: isSelected ? ThixPolicy.tint : Colors.transparent,
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          border: isSelected ? Border.all(color: ThixPolicy.domainReservation) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? ThixPolicy.domainReservation.withValues(alpha: 0.15)
                    : ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: Center(
                child: Text(
                  currency.symbol,
                  style: ThixPolicy.h3Style.copyWith(
                    color: isSelected ? ThixPolicy.domainReservation : ThixPolicy.textMain,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${currency.code} • ${currency.name}',
                    style: ThixPolicy.bodyStyle.copyWith(
                      fontWeight: ThixPolicy.semiBold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ThixPolicy.s2),
                  Text(
                    currency.countries.join(', '),
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: ThixPolicy.domainReservation,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget inline pour intégrer le sélecteur dans une AppBar
class CurrencySelectorInline extends ConsumerWidget {
  const CurrencySelectorInline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CurrencySelector(compact: true);
  }
}
