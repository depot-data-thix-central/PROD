// lib/presentation/thix_money/widgets/tontine_strip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tontine_provider.dart';

class TontineStrip extends ConsumerWidget {
  const TontineStrip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tontineProvider);
    if (state.isLoading && state.items.isEmpty) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final t = state.items[i];
          return Container(
            width: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: t.progress, backgroundColor: Colors.grey.shade200, color: Colors.green),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${(t.progress*100).toInt()}% • ${t.members}/${t.totalMembers}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const Text('Voir', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
              ])
            ]),
          );
        },
      ),
    );
  }
}
