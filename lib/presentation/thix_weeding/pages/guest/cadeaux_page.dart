// lib/presentation/thix_weeding/pages/guest/cadeaux_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/wedding_repository_impl.dart';
// 👇 Importez le fichier contenant la bonne définition de GiftItem
import '../../domain/entities/wedding_entity.dart';
// ❌ Supprimez cet import qui causait le conflit :
// import '../../models/gift_model.dart';

part 'cadeaux_page.g.dart';

@riverpod
Future<List<GiftItem>> weddingGifts(WeddingGiftsRef ref, String weddingId) async {
  final repo = ref.read(weddingRepositoryProvider);
  return repo.getGifts(weddingId);
}

class CadeauxPage extends ConsumerWidget {
  final String weddingId;
  const CadeauxPage({super.key, required this.weddingId});

  void _showContributeSheet(BuildContext context, GiftItem gift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(gift.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('${gift.price.toStringAsFixed(0)} FCFA - Restant: ${gift.remaining.toStringAsFixed(0)} FCFA'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: gift.percent, backgroundColor: Colors.grey.shade200, color: const Color(0xFFE25A6A)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () { if (ctx.mounted) ctx.pop(); }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE25A6A)), child: const Text('Contribuer via Thix Money'))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(weddingGiftsProvider(weddingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Liste de cadeaux'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); })),
      body: giftsAsync.when(
        data: (gifts) {
          if (gifts.isEmpty) return const Center(child: Text('Aucun cadeau pour le moment'));
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text('Participez à leur bonheur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final gift = gifts[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showContributeSheet(context, gift),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(children: [
                              ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(gift.imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 120, color: Colors.grey.shade200, child: const Icon(Icons.card_giftcard)))),
                              if (gift.isReserved) Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)), child: const Text('Réservé', style: TextStyle(color: Colors.white, fontSize: 10)))),
                            ]),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(gift.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text('${gift.price.toStringAsFixed(0)} FCFA', style: const TextStyle(color: Color(0xFFE25A6A), fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(value: gift.percent.clamp(0, 1), backgroundColor: Colors.grey.shade200, color: const Color(0xFFE25A6A), minHeight: 4),
                                  const SizedBox(height: 4),
                                  Text('${(gift.percent * 100).toStringAsFixed(0)}% contribué', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: gifts.length),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Erreur: $e'), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(weddingGiftsProvider(weddingId)), child: const Text('Réessayer'))])),
      ),
    );
  }
}
