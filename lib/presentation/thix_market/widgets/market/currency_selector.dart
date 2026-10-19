// lib/presentation/thix_market/widgets/market/currency_selector.dart
// ============================================================================
// CURRENCY SELECTOR — Production Enterprise v5
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/african_currencies.dart';
import '../../providers/currency_provider.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class CurrencySelector extends ConsumerWidget {
  const CurrencySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(currencyProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final current = AfricanCurrencies.byCode(selected);

    return Semantics(
      button: true,
      label: 'Devise: ${current?.displayName(lang) ?? selected}',
      child: GestureDetector(
        onTap: () => _showPicker(context, ref, lang),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current?.symbol ?? '?',
                style: const TextStyle(
                  color: ThixPolicy.domainMarket,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                selected,
                style: const TextStyle(
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18, color: ThixPolicy.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, String lang) {
    final sorted = AfricanCurrencies.sorted(lang);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // ✅ SUPPRIMÉ : isScrollControlDisabled (n'existe pas dans Flutter)
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: ThixPolicy.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  lang == 'sw' ? 'Chagua sarafu' :
                  lang == 'en' ? 'Select currency' : 'Choisir la devise',
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final cur = sorted[i];
                    final isSelected = cur.code == ref.read(currencyProvider);
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ThixPolicy.primary.withOpacity(0.1)
                              : ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            cur.symbol,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? ThixPolicy.primary : ThixPolicy.textMain,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        cur.displayName(lang),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? ThixPolicy.primary : ThixPolicy.textMain,
                        ),
                      ),
                      subtitle: Text(cur.code, style: ThixPolicy.captionStyle),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: ThixPolicy.primary)
                          : null,
                      onTap: () {
                        ref.read(currencyProvider.notifier).select(cur.code);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
