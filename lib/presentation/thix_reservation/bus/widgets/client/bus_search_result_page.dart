import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../providers/bus_search_provider.dart';
import '../../widgets/client/agency_trip_card.dart';
import '../../widgets/client/bus_filter_bottom_sheet.dart';
import '../../widgets/client/skeleton/trip_card_skeleton.dart';

/// ============================================================================
/// BusSearchResultPage
/// ============================================================================
///
/// Page de résultats de recherche de trajets de bus.
///
/// Features :
/// - Migration complète Provider → Riverpod (ConsumerStatefulWidget)
/// - Skeleton loaders animés pendant le chargement
/// - Tri multi-critère (départ, prix, durée) avec chips animés
/// - Filtres avancés via bottom sheet
/// - Multi-devises global (currencyProvider)
/// - Pull-to-refresh natif
/// - États vides et erreurs élégants
/// - Hero transitions vers la page détail
/// - Accessibilité complète (Semantics)
/// - i18n intégrée (FR/EN/LN)
/// - Responsive (ThixPolicy)
///
/// ============================================================================
class BusSearchResultPage extends ConsumerStatefulWidget {
  const BusSearchResultPage({super.key});

  @override
  ConsumerState<BusSearchResultPage> createState() =>
      _BusSearchResultPageState();
}

class _BusSearchResultPageState extends ConsumerState<BusSearchResultPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(busSearchProvider);
      final notifier = ref.read(busSearchProvider.notifier);
      if (state.filteredResults.isEmpty && !state.isSearching) {
        notifier.search();
      }
    });
  }

  Future<void> _refresh() async {
    await ref.read(busSearchProvider.notifier).search();
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BusFilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(busSearchProvider);
    final domainColor = ThixPolicy.domainReservation;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: _buildAppBar(state, domainColor),
      body: Column(
        children: [
          _SortChipsBar(domainColor: domainColor),
          Expanded(
            child: RefreshIndicator(
              color: domainColor,
              backgroundColor: Colors.white,
              onRefresh: _refresh,
              child: _buildBody(state, domainColor),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BusSearchState state, Color domainColor) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    final dateFormatted = DateFormat('d MMM', locale).format(state.departureDate);
    final passengersLabel = l10n.busSearchResultsPassengers(state.passengers);
    final tripsLabel = l10n.busSearchResultsTrips(state.filteredResults.length);

    final routeLabel =
        '${state.departureCity ?? '-'} → ${state.arrivalCity ?? '-'}';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 68,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
        onPressed: () => context.pop(),
        tooltip: l10n.commonBack,
      ),
      title: Semantics(
        label: '$routeLabel, $dateFormatted, $passengersLabel, $tripsLabel',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routeLabel,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 15,
                color: ThixPolicy.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: ThixPolicy.s2),
            Text(
              '$dateFormatted • $passengersLabel • $tripsLabel',
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textSecondary,
                fontWeight: ThixPolicy.medium,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(ThixPolicy.s6),
            decoration: BoxDecoration(
              color: state.hasActiveFilters
                  ? domainColor.withValues(alpha: 0.12)
                  : ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(
                color: state.hasActiveFilters
                    ? domainColor.withValues(alpha: 0.3)
                    : ThixPolicy.border,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.tune_rounded, color: domainColor, size: 18),
                if (state.hasActiveFilters)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ThixPolicy.warning,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          onPressed: _openFilters,
          tooltip: l10n.busSearchFilters,
        ),
        SizedBox(width: ThixPolicy.s8),
      ],
    );
  }

  Widget _buildBody(BusSearchState state, Color domainColor) {
    final l10n = context.l10n;

    if (state.isSearching) {
      return _TripResultsSkeleton();
    }

    if (state.error != null) {
      return _ErrorResultsView(
        error: state.error!,
        onRetry: () => ref.read(busSearchProvider.notifier).search(),
      );
    }

    if (state.filteredResults.isEmpty) {
      return _EmptyResultsView(
        hasFilters: state.hasActiveFilters,
        onClearFilters: () => ref.read(busSearchProvider.notifier).clearFilters(),
        onNewSearch: () => context.pop(),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        ThixPolicy.s16,
        ThixPolicy.s16,
        ThixPolicy.s16,
        ThixPolicy.s32,
      ),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: state.filteredResults.length,
      separatorBuilder: (_, __) => SizedBox(height: ThixPolicy.s12),
      itemBuilder: (_, i) {
        final trip = state.filteredResults[i];
        return _AnimatedTripCard(
          index: i,
          child: AgencyTripCard(
            trip: trip,
            heroTag: 'trip_${trip.id}',
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(
                '/thix-reservation/bus/trip/${trip.id}',
                extra: trip,
              );
            },
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// _SortChipsBar — Barre de tri avec chips animés
/// ============================================================================
class _SortChipsBar extends ConsumerWidget {
  final Color domainColor;

  const _SortChipsBar({required this.domainColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(busSearchProvider);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: ThixPolicy.s16,
        vertical: ThixPolicy.s10,
      ),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 14,
            color: ThixPolicy.textSecondary,
          ),
          SizedBox(width: ThixPolicy.s6),
          Text(
            l10n.busSearchSortBy,
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.textSecondary,
              fontWeight: ThixPolicy.semiBold,
            ),
          ),
          SizedBox(width: ThixPolicy.s8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _SortChip(
                    label: l10n.busSearchSortDeparture,
                    value: 'departure',
                    icon: Icons.access_time_rounded,
                    currentSort: state.sortBy,
                    domainColor: domainColor,
                    onSelected: (v) =>
                        ref.read(busSearchProvider.notifier).setSort(v),
                  ),
                  SizedBox(width: ThixPolicy.s6),
                  _SortChip(
                    label: l10n.busSearchSortPrice,
                    value: 'price',
                    icon: Icons.payments_outlined,
                    currentSort: state.sortBy,
                    domainColor: domainColor,
                    onSelected: (v) =>
                        ref.read(busSearchProvider.notifier).setSort(v),
                  ),
                  SizedBox(width: ThixPolicy.s6),
                  _SortChip(
                    label: l10n.busSearchSortDuration,
                    value: 'duration',
                    icon: Icons.timer_outlined,
                    currentSort: state.sortBy,
                    domainColor: domainColor,
                    onSelected: (v) =>
                        ref.read(busSearchProvider.notifier).setSort(v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _SortChip — Chip de tri individuel avec animation
/// ============================================================================
class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String currentSort;
  final Color domainColor;
  final ValueChanged<String> onSelected;

  const _SortChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.currentSort,
    required this.domainColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentSort == value;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label ${isSelected ? "(actif)" : ""}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(value);
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: ThixPolicy.s10,
              vertical: ThixPolicy.s6,
            ),
            decoration: BoxDecoration(
              color: isSelected ? domainColor : Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rFull),
              border: Border.all(
                color: isSelected ? domainColor : ThixPolicy.border,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: isSelected ? Colors.white : domainColor,
                ),
                SizedBox(width: ThixPolicy.s4),
                Text(
                  label,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontSize: 11.5,
                    color: isSelected ? Colors.white : ThixPolicy.textMain,
                    fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.semiBold,
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
/// _AnimatedTripCard — Animation d'apparition des cartes
/// ============================================================================
class _AnimatedTripCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedTripCard({required this.index, required this.child});

  @override
  State<_AnimatedTripCard> createState() => _AnimatedTripCardState();
}

class _AnimatedTripCardState extends State<_AnimatedTripCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + (widget.index * 40).clamp(0, 200)),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

/// ============================================================================
/// _TripResultsSkeleton — Skeleton loader pour la liste
/// ============================================================================
class _TripResultsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        ThixPolicy.s16,
        ThixPolicy.s16,
        ThixPolicy.s16,
        ThixPolicy.s32,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: ThixPolicy.s12),
      itemBuilder: (_, i) => _SkeletonCard(index: i),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final int index;
  const _SkeletonCard({required this.index});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
      builder: (ctx, _) {
        final alpha = (0.5 + (_ctrl.value * 0.3)).clamp(0.0, 1.0);
        final color = ThixPolicy.surfaceStrong.withValues(alpha: alpha);

        return Container(
          padding: EdgeInsets.all(ThixPolicy.s16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SkeletonBox(width: 40, height: 40, color: color),
                  SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 120, height: 14, color: color),
                        SizedBox(height: ThixPolicy.s6),
                        _SkeletonBox(width: 80, height: 10, color: color),
                      ],
                    ),
                  ),
                  _SkeletonBox(width: 60, height: 24, color: color),
                ],
              ),
              SizedBox(height: ThixPolicy.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SkeletonBox(width: 60, height: 20, color: color),
                  _SkeletonBox(width: 100, height: 10, color: color),
                  _SkeletonBox(width: 60, height: 20, color: color),
                ],
              ),
              SizedBox(height: ThixPolicy.s12),
              _SkeletonBox(width: double.infinity, height: 32, color: color),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
      ),
    );
  }
}

/// ============================================================================
/// _EmptyResultsView — État vide avec actions contextuelles
/// ============================================================================
class _EmptyResultsView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onNewSearch;

  const _EmptyResultsView({
    required this.hasFilters,
    required this.onClearFilters,
    required this.onNewSearch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(ThixPolicy.s24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: ThixPolicy.s40),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThixPolicy.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 40,
                color: ThixPolicy.domainReservation.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: ThixPolicy.s20),
            Text(
              hasFilters
                  ? l10n.busSearchNoResultsWithFilters
                  : l10n.busSearchNoResults,
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ThixPolicy.s8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                hasFilters
                    ? l10n.busSearchNoResultsFiltersHint
                    : l10n.busSearchNoResultsHint,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: ThixPolicy.s28),
            if (hasFilters)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: Text(l10n.busSearchClearFilters),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThixPolicy.domainReservation,
                    side: BorderSide(color: ThixPolicy.domainReservation),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    ),
                  ),
                ),
              ),
            SizedBox(height: ThixPolicy.s12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onNewSearch,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(l10n.busSearchNewSearch),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.domainReservation,
                  foregroundColor: Colors.white,
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
/// _ErrorResultsView — État d'erreur avec retry
/// ============================================================================
class _ErrorResultsView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorResultsView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(ThixPolicy.s24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: ThixPolicy.s40),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: ThixPolicy.danger,
              ),
            ),
            SizedBox(height: ThixPolicy.s20),
            Text(
              l10n.commonError,
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ThixPolicy.s8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                error,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: ThixPolicy.s28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.commonRetry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.domainReservation,
                  foregroundColor: Colors.white,
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
