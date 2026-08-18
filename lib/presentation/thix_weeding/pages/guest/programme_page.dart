// lib/presentation/thix_weeding/pages/guest/programme_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../models/program_item_model.dart';

part 'programme_page.g.dart';

@riverpod
Future<List<ProgramItem>> weddingProgram(WeddingProgramRef ref, String weddingId) async {
  final repo = ref.read(weddingRepositoryProvider);
  return repo.getProgram(weddingId);
}

class ProgrammePage extends ConsumerWidget {
  final String weddingId;
  const ProgrammePage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(weddingProgramProvider(weddingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Programme'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); })),
      body: programAsync.when(
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('Programme bientôt disponible'));
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text('Déroulé de la journée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
              SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isFirst = index == 0;
                  final isLast = index == items.length - 1;
                  return _TimelineTile(item: item, isFirst: isFirst, isLast: isLast);
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Erreur: $e'), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(weddingProgramProvider(weddingId)), child: const Text('Réessayer'))])),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ProgramItem item;
  final bool isFirst;
  final bool isLast;
  const _TimelineTile({required this.item, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 70,
            child: Column(
              children: [
                if (!isFirst) Expanded(child: Container(width: 2, color: Colors.pink.shade100)),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: item.isDone? Colors.green : Colors.pink.shade50, shape: BoxShape.circle, border: Border.all(color: item.isDone? Colors.green : const Color(0xFFE25A6A))),
                  child: Icon(item.isDone? Icons.check : Icons.access_time, size: 18, color: item.isDone? Colors.white : const Color(0xFFE25A6A)),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: Colors.pink.shade100)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 20, top: 4),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(item.time, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE25A6A))), if (item.isDone) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('Terminé', style: TextStyle(fontSize: 10, color: Colors.green)))]),
                      const SizedBox(height: 6),
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(item.description, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
