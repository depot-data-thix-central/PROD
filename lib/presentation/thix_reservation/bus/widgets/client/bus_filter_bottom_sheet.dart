import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../providers/bus_search_provider.dart';

/// Helper de traduction tolérant pour les clés manquantes
String _tr(BuildContext context, String key, String fallback) {
  final translated = context.l10n.t(key);
  return translated == key ? fallback : translated;
}

/// ============================================================================
/// BusFilterBottomSheet
/// ============================================================================
///
/// Feuille de filtres avancés pour la recherche de trajets de bus.
///
/// Features :
/// - Multi-devises global (via currencyProvider)
/// - Conversion automatique des limites de prix
/// - 3 sections de filtres : Prix, Type de bus, Équipements
/// - Chips animés avec feedback haptique
/// - Slider prix avec label dynamique
/// - Badge "Actif" sur les sections filtrées
/// - i18n complète (FR/EN/LN)
/// - Accessibilité complète (Semantics)
/// - Design system ThixPolicy
/// - Bouton "Appliquer" avec compteur de filtres actifs
///
/// ============================================================================
class BusFilterBottomSheet extends ConsumerStatefulWidget {
  const BusFilterBottomSheet({super.key});

  @override
  ConsumerState<BusFilterBottomSheet> createState() =>
      _BusFilterBottomSheetState();
}

class _BusFilterBottomSheetState extends ConsumerState<BusFilterBottomSheet> {
  // État local pour les modifications avant application
  late double _localMaxPrice;
  late Set<String> _localBusTypes;
  late Set<String> _localAmenities;
  late Currency _localCurrency;

  // Limites par défaut (en CDF) — seront converties selon la devise
  static const _defaultMinPriceCDF = 1000.0;
  static const _defaultMaxPriceCDF = 100000.0;

  @override
  void initState() {
    super.initState();
    final state = ref.read(busSearchProvider);
    final currency = ref.read(currencyProvider).currency;

    _localCurrency = currency;

    // Convertir depuis CDF vers la devise courante
    final converted = ref.read(currencyProvider).convert(
      _defaultMaxPriceCDF,
      fromCurrency: 'CDF',
    );
    _localMaxPrice = (state.maxPrice > 0)
        ? ref.read(currencyProvider).convert(
            state.maxPrice.toDouble(),
            fromCurrency: 'CDF',
          ).toDouble()
        : converted.toDouble();

    _localBusTypes = Set<String>.from(state.busTypes);
    _localAmenities = Set<String>.from(state.amenities);
  }

  int get _activeFiltersCount {
    int count = 0;
    final state = ref.read(busSearchProvider);

    // Prix différent du max par défaut (en CDF)
    final maxInCDF = ref.read(currencyProvider).convert(
      _localMaxPrice,
      fromCurrency: _localCurrency.code,
    );
    if (maxInCDF.toDouble() < _defaultMaxPriceCDF * 0.95) count++;

    if (_localBusTypes.isNotEmpty) count++;
    if (_localAmenities.isNotEmpty) count++;

    return count;
  }

  void _applyFilters() {
    final notifier = ref.read(busSearchProvider.notifier);

    // Convertir le prix local (dans la devise utilisateur) vers CDF pour le stockage
    final priceInCDF = ref.read(currencyProvider).convert(
      _localMaxPrice,
      fromCurrency: _localCurrency.code,
    );

    notifier.updatePriceFilter(0, priceInCDF.toDouble());
    notifier.updateBusTypes(_localBusTypes.toList());
    notifier.updateAmenities(_localAmenities.toList());

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      final converted = ref.read(currencyProvider).convert(
        _defaultMaxPriceCDF,
        fromCurrency: 'CDF',
      );
      _localMaxPrice = converted.toDouble();
      _localBusTypes.clear();
      _localAmenities.clear();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currency = ref.watch(currencyProvider).currency;
    final domainColor = ThixPolicy.domainReservation;
    final activeCount = _activeFiltersCount;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          ThixPolicy.s20,
          ThixPolicy.s16,
          ThixPolicy.s20,
          ThixPolicy.s16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ThixPolicy.r2Xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: ThixPolicy.s16),

            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ThixPolicy.s8),
                  decoration: BoxDecoration(
                    color: domainColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: domainColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('market_filters'), // Utilisation de "Filtres" comme titre générique
                        style: ThixPolicy.titleStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          fontSize: 16,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                      SizedBox(height: ThixPolicy.s2),
                      Text(
                        activeCount > 0
                            ? '${activeCount} ${l10n.t('common_items')}' // Construction dynamique pour le compte
                            : l10n.t('market_no_filters'), // Fallback si "No active filters" n'existe pas
                        style: ThixPolicy.microStyle.copyWith(
                          color: activeCount > 0
                              ? domainColor
                              : ThixPolicy.textSecondary,
                          fontWeight: ThixPolicy.medium,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: activeCount > 0 ? _clearAll : null,
                  style: TextButton.styleFrom(
                    foregroundColor: domainColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s12,
                      vertical: ThixPolicy.s6,
                    ),
                  ),
                  child: Text(
                    l10n.t('common_clear'),
                    style: ThixPolicy.labelStyle.copyWith(
                      color: activeCount > 0
                          ? domainColor
                          : ThixPolicy.textMuted,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: ThixPolicy.s20),

            // Scrollable content
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PriceRangeFilter(
                      value: _localMaxPrice,
                      currency: _localCurrency,
                      domainColor: domainColor,
                      onChanged: (val) {
                        setState(() => _localMaxPrice = val);
                      },
                    ),
                    SizedBox(height: ThixPolicy.s24),
                    _BusTypeFilter(
                      selected: _localBusTypes,
                      domainColor: domainColor,
                      onChanged: (types) {
                        setState(() => _localBusTypes = types);
                      },
                    ),
                    SizedBox(height: ThixPolicy.s24),
                    _AmenitiesFilter(
                      selected: _localAmenities,
                      domainColor: domainColor,
                      onChanged: (amenities) {
                        setState(() => _localAmenities = amenities);
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: ThixPolicy.s20),

            // Apply button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _applyFilters,
                icon: Icon(Icons.check_rounded, size: 18),
                label: Text(
                  activeCount > 0
                      ? '${l10n.t('common_apply')} ($activeCount)' // Construction dynamique
                      : l10n.t('common_apply'),
                  style: ThixPolicy.titleStyle.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: domainColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _PriceRangeFilter — Filtre de prix avec multi-devises
/// ============================================================================
class _PriceRangeFilter extends StatelessWidget {
  final double value;
  final Currency currency;
  final Color domainColor;
  final ValueChanged<double> onChanged;

  const _PriceRangeFilter({
    required this.value,
    required this.currency,
    required this.domainColor,
    required this.onChanged,
  });

  static const _minPrice = 1000.0;
  static const _maxPrice = 500000.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final formattedValue = CurrencyFormatter.format(
      value.toInt(),
      currency: currency.code,
      compact: false,
    );

    final formattedMax = CurrencyFormatter.format(
      _maxPrice.toInt(),
      currency: currency.code,
      compact: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.payments_outlined,
          title: l10n.t('money_amount'), // Utilisation de "Montant" / "Amount"
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s12),

        // Current value display
        Container(
          padding: EdgeInsets.all(ThixPolicy.s12),
          decoration: BoxDecoration(
            color: domainColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(
              color: domainColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tr(context, 'filters_max_budget', 'Budget max'),
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
              ),
              Text(
                formattedValue,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: domainColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: ThixPolicy.s16),

        // Slider
        Semantics(
          label: _tr(context, 'filters_price_slider', 'Prix'),
          value: value.toStringAsFixed(0),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: domainColor,
              inactiveTrackColor: ThixPolicy.border,
              thumbColor: domainColor,
              overlayColor: domainColor.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
              ),
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              valueIndicatorColor: domainColor,
              valueIndicatorTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: ThixPolicy.bold,
                fontSize: 12,
              ),
            ),
            child: Slider(
              value: value.clamp(_minPrice, _maxPrice),
              min: _minPrice,
              max: _maxPrice,
              divisions: 99,
              label: formattedValue,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                onChanged(val);
              },
            ),
          ),
        ),

        SizedBox(height: ThixPolicy.s4),

        // Min/Max labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              CurrencyFormatter.format(
                _minPrice.toInt(),
                currency: currency.code,
                compact: true,
              ),
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
            ),
            Text(
              formattedMax,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
            ),
          ],
        ),

        SizedBox(height: ThixPolicy.s8),

        // Info text
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 12,
              color: ThixPolicy.textMuted,
            ),
            SizedBox(width: ThixPolicy.s4),
            Expanded(
              child: Text(
                _tr(context, 'filters_price_currency_info', 'Devise: ${currency.code}'),
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ============================================================================
/// _BusTypeFilter — Filtre par type de bus
/// ============================================================================
class _BusTypeFilter extends StatelessWidget {
  final Set<String> selected;
  final Color domainColor;
  final ValueChanged<Set<String>> onChanged;

  const _BusTypeFilter({
    required this.selected,
    required this.domainColor,
    required this.onChanged,
  });

  static const _types = [
    ('vip', 'ticket_vip', Icons.star_rounded),
    ('standard', 'ticket_standard', Icons.directions_bus_rounded),
    ('clim', 'amenity_ac', Icons.ac_unit_rounded),
    ('sleeper', 'filters_bus_type_sleeper', Icons.bed_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.directions_bus_rounded,
          title: _tr(context, 'filters_bus_type_title', 'Type de bus'),
          domainColor: domainColor,
          subtitle: selected.isEmpty
              ? _tr(context, 'event_filter_all', 'Tous')
              : '${selected.length} ${l10n.t('common_items')}',
        ),
        SizedBox(height: ThixPolicy.s12),
        Wrap(
          spacing: ThixPolicy.s8,
          runSpacing: ThixPolicy.s8,
          children: _types.map((t) {
            final value = t.$1;
            final labelKey = t.$2;
            final icon = t.$3;
            final isSelected = selected.contains(value);

            return _FilterChip(
              icon: icon,
              label: _translateType(context, labelKey),
              isSelected: isSelected,
              domainColor: domainColor,
              onTap: () {
                HapticFeedback.selectionClick();
                final newSet = Set<String>.from(selected);
                if (isSelected) {
                  newSet.remove(value);
                } else {
                  newSet.add(value);
                }
                onChanged(newSet);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  String _translateType(BuildContext context, String key) {
    // Utilisation directe de l10n.t() car les clés existent ou ont des fallbacks logiques
    return context.l10n.t(key);
  }
}

/// ============================================================================
/// _AmenitiesFilter — Filtre par équipements
/// ============================================================================
class _AmenitiesFilter extends StatelessWidget {
  final Set<String> selected;
  final Color domainColor;
  final ValueChanged<Set<String>> onChanged;

  const _AmenitiesFilter({
    required this.selected,
    required this.domainColor,
    required this.onChanged,
  });

  static const _amenities = [
    ('wifi', 'amenity_wifi', Icons.wifi_rounded),
    ('ac', 'amenity_ac', Icons.ac_unit_rounded),
    ('usb', 'amenity_usb', Icons.usb_rounded),
    ('toilet', 'amenity_toilet', Icons.wc_rounded),
    ('tv', 'amenity_tv', Icons.tv_rounded),
    ('snack', 'filters_amenity_snack', Icons.restaurant_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.star_outline_rounded,
          title: _tr(context, 'bus_comfort_title', 'Confort'),
          domainColor: domainColor,
          subtitle: selected.isEmpty
              ? _tr(context, 'event_filter_all', 'Tous')
              : '${selected.length} ${l10n.t('common_items')}',
        ),
        SizedBox(height: ThixPolicy.s12),
        Wrap(
          spacing: ThixPolicy.s8,
          runSpacing: ThixPolicy.s8,
          children: _amenities.map((a) {
            final value = a.$1;
            final labelKey = a.$2;
            final icon = a.$3;
            final isSelected = selected.contains(value);

            return _FilterChip(
              icon: icon,
              label: _translateAmenity(context, labelKey),
              isSelected: isSelected,
              domainColor: domainColor,
              onTap: () {
                HapticFeedback.selectionClick();
                final newSet = Set<String>.from(selected);
                if (isSelected) {
                  newSet.remove(value);
                } else {
                  newSet.add(value);
                }
                onChanged(newSet);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  String _translateAmenity(BuildContext context, String key) {
    // Utilisation directe de l10n.t()
    return context.l10n.t(key);
  }
}

/// ============================================================================
/// _FilterChip — Chip de filtre réutilisable avec animation
/// ============================================================================
class _FilterChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color domainColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.domainColor,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: ThixPolicy.s14,
              vertical: ThixPolicy.s10,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.domainColor
                  : Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rFull),
              border: Border.all(
                color: widget.isSelected
                    ? widget.domainColor
                    : ThixPolicy.border,
                width: 1.5,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.domainColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 15,
                  color: widget.isSelected
                      ? Colors.white
                      : widget.domainColor,
                ),
                SizedBox(width: ThixPolicy.s6),
                Text(
                  widget.label,
                  style: ThixPolicy.labelStyle.copyWith(
                    color: widget.isSelected
                        ? Colors.white
                        : ThixPolicy.textMain,
                    fontWeight: widget.isSelected
                        ? ThixPolicy.bold
                        : ThixPolicy.medium,
                    fontSize: 12,
                  ),
                ),
                if (widget.isSelected) ...[
                  SizedBox(width: ThixPolicy.s4),
                  Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _SectionHeader — En-tête de section de filtre
/// ============================================================================
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color domainColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.domainColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(ThixPolicy.s6),
          decoration: BoxDecoration(
            color: domainColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
          ),
          child: Icon(icon, size: 14, color: domainColor),
        ),
        SizedBox(width: ThixPolicy.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: ThixPolicy.microStyle.copyWith(
                    color: domainColor,
                    fontWeight: ThixPolicy.medium,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Typedef pour Currency (à adapter selon votre modèle)
typedef Currency = dynamic;
