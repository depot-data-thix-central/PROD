import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

import '../../providers/bus_search_provider.dart';
import 'city_picker_sheet.dart';
import 'passenger_picker_sheet.dart';

/// ============================================================================
/// BusSearchBar
/// ============================================================================
///
/// Barre de recherche de trajets de bus (composant réutilisable).
///
/// Peut être utilisée sur la home ou toute autre page nécessitant
/// une recherche rapide de trajets.
///
/// Features :
/// - Riverpod (ConsumerWidget) — migration depuis Provider legacy
/// - i18n complète (FR/EN/LN) avec pluralisation
/// - ThixPolicy pour le design system
/// - Accessibilité complète (Semantics)
/// - Feedback haptique sur les interactions
/// - Formatage de date avec locale
/// - Bouton swap animé
/// - Validation visuelle des champs
/// - Responsive
///
/// ============================================================================
class BusSearchBar extends ConsumerWidget {
  final VoidCallback onSearch;
  final Color? domainColor;

  const BusSearchBar({
    super.key,
    required this.onSearch,
    this.domainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(busSearchProvider);
    final notifier = ref.read(busSearchProvider.notifier);
    final accent = domainColor ?? ThixPolicy.domainReservation;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row Départ ↔ Arrivée
          Row(
            children: [
              Expanded(
                child: _CityField(
                  label: l10n.t('reservation_check_out'),
                  value: state.departureCity,
                  placeholder: l10n.t('market_discover'),
                  icon: Icons.my_location_rounded,
                  accent: accent,
                  onTap: () => _showCityPicker(context, ref, isDeparture: true),
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              _SwapButton(
                accent: accent,
                onTap: () {
                  if (state.departureCity != null && state.arrivalCity != null) {
                    HapticFeedback.mediumImpact();
                    notifier.swapCities();
                  }
                },
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: _CityField(
                  label: l10n.t('reservation_check_in'),
                  value: state.arrivalCity,
                  placeholder: l10n.t('market_discover'),
                  icon: Icons.location_on_rounded,
                  accent: accent,
                  onTap: () => _showCityPicker(context, ref, isDeparture: false),
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s12),

          // Row Date + Passagers
          Row(
            children: [
              Expanded(
                child: _InfoField(
                  label: l10n.t('events_date'),
                  value: _formatDate(context, state.departureDate),
                  icon: Icons.calendar_today_rounded,
                  accent: accent,
                  onTap: () => _pickDate(context, ref),
                ),
              ),
              SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: _InfoField(
                  label: l10n.t('reservation_guests'),
                  // Construction dynamique car la clé spécifique n'existe pas
                  value: '${state.passengers} ${l10n.t('reservation_guests')}',
                  icon: Icons.person_outline_rounded,
                  accent: accent,
                  onTap: () => _showPassengerPicker(context),
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s16),

          // Bouton Rechercher
          Semantics(
            button: true,
            label: l10n.t('common_search'),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSearchEnabled(state) ? onSearch : null,
                icon: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                label: Text(
                  l10n.t('common_search'),
                  style: ThixPolicy.titleStyle.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  disabledBackgroundColor: ThixPolicy.textMuted,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSearchEnabled(BusSearchState state) {
    return state.departureCity != null &&
        state.arrivalCity != null &&
        state.departureCity != state.arrivalCity;
  }

  String _formatDate(BuildContext context, DateTime d) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMM yyyy', locale).format(d);
  }

  void _showCityPicker(BuildContext context, WidgetRef ref, {required bool isDeparture}) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CityPickerSheet(isDep: isDeparture),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final state = ref.read(busSearchProvider);
    final notifier = ref.read(busSearchProvider.notifier);

    final picked = await showDatePicker(
      context: context,
      initialDate: state.departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: Localizations.localeOf(context),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: domainColor ?? ThixPolicy.domainReservation),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      notifier.setDate(picked);
    }
  }

  void _showPassengerPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const PassengerPickerSheet(),
    );
  }
}

/// ============================================================================
/// _CityField — Champ de sélection de ville
/// ============================================================================
class _CityField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _CityField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Semantics(
          button: true,
          label: "$label: ${hasValue ? value : placeholder}",
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ThixPolicy.s12,
              vertical: ThixPolicy.s12,
            ),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                SizedBox(width: ThixPolicy.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                          fontWeight: ThixPolicy.semiBold,
                        ),
                      ),
                      SizedBox(height: ThixPolicy.s2),
                      Text(
                        hasValue ? value! : placeholder,
                        style: ThixPolicy.bodyStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          color: hasValue ? ThixPolicy.textMain : ThixPolicy.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasValue)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: ThixPolicy.success,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _InfoField — Champ d'information (date, passagers)
/// ============================================================================
class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _InfoField({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Semantics(
          button: true,
          label: "$label: $value",
          child: Container(
            padding: EdgeInsets.all(ThixPolicy.s12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                SizedBox(width: ThixPolicy.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                          fontWeight: ThixPolicy.semiBold,
                        ),
                      ),
                      SizedBox(height: ThixPolicy.s2),
                      Text(
                        value,
                        style: ThixPolicy.bodyStyle.copyWith(
                          fontWeight: ThixPolicy.semiBold,
                          fontSize: 13,
                          color: ThixPolicy.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

/// ============================================================================
/// _SwapButton — Bouton d'échange départ/arrivée avec rotation animée
/// ============================================================================
class _SwapButton extends StatefulWidget {
  final Color accent;
  final VoidCallback onTap;

  const _SwapButton({required this.accent, required this.onTap});

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _rotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.t('common_refresh'), // Utilisation de "Actualiser" comme sémantique pour Swap
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedBuilder(
            animation: _rotation,
            builder: (ctx, child) => RotationTransition(
              turns: _rotation,
              child: child,
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.swap_horiz_rounded,
                color: widget.accent,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// AnimatedBuilder — Polyfill
/// ============================================================================
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
