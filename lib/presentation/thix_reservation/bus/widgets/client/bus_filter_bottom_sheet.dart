// lib/presentation/thix_reservation/bus/widgets/client/bus_filter_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/bus_search_provider.dart';

class BusFilterBottomSheet extends ConsumerWidget {
  const BusFilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(busSearchProvider);
    final notifier = ref.read(busSearchProvider.notifier);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtres de recherche',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
              ),
              TextButton(
                onPressed: () => notifier.clearFilters(),
                child: const Text(
                  'Tout effacer',
                  style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: ThixPolicy.border),
          const Text(
            'Prix maximum (CDF)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.minPrice.toInt().toString() + ' CDF',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ThixPolicy.textSecondary),
              ),
              Text(
                state.maxPrice.toInt().toString() + ' CDF',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ThixPolicy.textSecondary),
              ),
            ],
          ),
          Slider(
            value: state.maxPrice.clamp(1000, 100000),
            min: 1000,
            max: 100000,
            divisions: 99,
            activeColor: ThixPolicy.primary,
            inactiveColor: ThixPolicy.border,
            label: state.maxPrice.toInt().toString() + ' CDF',
            onChanged: (val) => notifier.updatePriceFilter(state.minPrice, val),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les prix sont en Franc Congolais. 1 USD ≈ 2850 CDF.',
            style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
              ),
              child: const Text(
                'Appliquer les filtres',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
