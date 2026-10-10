import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import '../../providers/bus_search_provider.dart';

class CityPickerSheet extends ConsumerWidget {
  final bool isDep;
  const CityPickerSheet({super.key, required this.isDep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(busSearchProvider);
    final cities = ['Kinshasa', 'Matadi', 'Lubumbashi', 'Goma', 'Kisangani']; // Replace with real data

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isDep ? l10n.t('reservation_check_out') : l10n.t('reservation_check_in'), 
                 style: ThixPolicy.h3Style),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              itemCount: cities.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final city = cities[i];
                return ListTile(
                  title: Text(city),
                  onTap: () {
                    if (isDep) {
                      ref.read(busSearchProvider.notifier).setDeparture(city);
                    } else {
                      ref.read(busSearchProvider.notifier).setArrival(city);
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
