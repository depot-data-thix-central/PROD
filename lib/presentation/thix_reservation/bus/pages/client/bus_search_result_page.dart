// lib/presentation/thix_reservation/bus/pages/client/bus_search_result_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../providers/bus_search_provider.dart';
import '../../widgets/client/agency_trip_card.dart';
import '../../widgets/client/bus_filter_bottom_sheet.dart';

class BusSearchResultPage extends ConsumerStatefulWidget {
  const BusSearchResultPage({super.key});

  @override
  ConsumerState<BusSearchResultPage> createState() => _BusSearchResultPageState();
}

class _BusSearchResultPageState extends ConsumerState<BusSearchResultPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(busSearchProvider);
      if (state.filteredResults.isEmpty && !state.isSearching) {
        ref.read(busSearchProvider.notifier).search();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 Écoute moderne de l'état Riverpod
    final state = ref.watch(busSearchProvider);
    final notifier = ref.read(busSearchProvider.notifier);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${state.departureCity ?? '-'} → ${state.arrivalCity ?? '-'}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
            ),
            Text(
              '${state.departureDate.day.toString().padLeft(2, '0')}/${state.departureDate.month.toString().padLeft(2, '0')} • ${state.passengers} passager(s) • ${state.filteredResults.length} trajets',
              style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: ThixPolicy.textMain),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const BusFilterBottomSheet(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 🌟 Barre de tri SaaS moderne alignée sur la Policy
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Trier par :', style: TextStyle(fontSize: 11.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                _SortChip(label: 'Départ', value: 'departure'),
                const SizedBox(width: 6),
                _SortChip(label: 'Prix', value: 'price'),
                const SizedBox(width: 6),
                _SortChip(label: 'Heure', value: 'duration'),
              ],
            ),
          ),
          const Divider(height: 1, color: ThixPolicy.border),
          Expanded(
            child: Builder(builder: (_) {
              if (state.isSearching) {
                return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
              }
              if (state.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: ThixPolicy.danger),
                        const SizedBox(height: 12),
                        Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => notifier.search(),
                          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (state.filteredResults.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: ThixPolicy.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text('Aucun trajet trouvé', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
                      const SizedBox(height: 6),
                      const Text('Essayez une autre date ou destination', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => notifier.clearFilters(),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: ThixPolicy.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Effacer les filtres', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.filteredResults.length,
                itemBuilder: (_, i) {
                  final trip = state.filteredResults[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AgencyTripCard(
                      trip: trip,
                      onTap: () => context.push('/thix-reservation/bus/trip/${trip.id}', extra: trip),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends ConsumerWidget {
  final String label;
  final String value;
  const _SortChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(busSearchProvider);
    final selected = state.sortBy == value;
    
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5, 
          color: selected ? Colors.white : ThixPolicy.textMain, 
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedColor: ThixPolicy.primary,
      backgroundColor: ThixPolicy.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? Colors.transparent : ThixPolicy.border),
      ),
      onSelected: (_) => ref.read(busSearchProvider.notifier).setSort(value),
    );
  }
}
