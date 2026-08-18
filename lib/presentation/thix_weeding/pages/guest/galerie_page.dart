// lib/presentation/thix_weeding/pages/guest/galerie_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/wedding_repository_impl.dart';

part 'galerie_page.g.dart';

class GalleryState {
  final List<String> images;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  const GalleryState({this.images = const [], this.page = 1, this.hasMore = true, this.isLoadingMore = false});
  GalleryState copyWith({List<String>? images, int? page, bool? hasMore, bool? isLoadingMore}) => GalleryState(images: images??this.images, page: page??this.page, hasMore: hasMore??this.hasMore, isLoadingMore: isLoadingMore??this.isLoadingMore);
}

@riverpod
class WeddingGallery extends _$WeddingGallery {
  @override
  Future<GalleryState> build(String weddingId) async {
    final repo = ref.read(weddingRepositoryProvider);
    final first = await repo.getGallery(weddingId, page: 1);
    return GalleryState(images: first, page: 1, hasMore: first.length >= 20);
  }

  Future<void> fetchNext() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repo = ref.read(weddingRepositoryProvider);
      final next = await repo.getGallery(weddingId, page: current.page + 1);
      state = AsyncData(current.copyWith(images: [...current.images, ...next], page: current.page + 1, hasMore: next.length >= 20, isLoadingMore: false));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

class GaleriePage extends ConsumerStatefulWidget {
  final String weddingId;
  const GaleriePage({super.key, required this.weddingId});
  @override
  ConsumerState<GaleriePage> createState() => _GaleriePageState();
}

class _GaleriePageState extends ConsumerState<GaleriePage> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
        ref.read(weddingGalleryProvider(widget.weddingId).notifier).fetchNext();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryAsync = ref.watch(weddingGalleryProvider(widget.weddingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Galerie'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); }), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.cloud_upload_outlined))]),
      body: galleryAsync.when(
        data: (state) {
          if (state.images.isEmpty) return const Center(child: Text('Aucune photo pour le moment'));
          return RefreshIndicator(
            onRefresh: () => ref.read(weddingGalleryProvider(widget.weddingId).notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= state.images.length) return const Center(child: CircularProgressIndicator());
                      final url = state.images[index];
                      return InkWell(
                        onTap: () => showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url)))),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200))),
                      );
                    }, childCount: state.images.length + (state.isLoadingMore? 1 : 0)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Erreur: $e'), FilledButton(onPressed: () => ref.invalidate(weddingGalleryProvider(widget.weddingId)), child: const Text('Réessayer'))])),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.add_a_photo), label: const Text('Ajouter')),
    );
  }
}
