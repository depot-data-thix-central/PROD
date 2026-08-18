// lib/presentation/thix_weeding/pages/staff/galerie/gallery_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

class GalleryManagementPage extends ConsumerWidget {
  final String weddingId;
  const GalleryManagementPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: galleryAsync.when(
          data: (List<GalleryModel> list) => Text('Galerie - ${list.length}'),
          loading: () => const Text('Galerie'),
          error: (_, __) => const Text('Galerie'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.cloud_upload), onPressed: () => context.push('/thix-weeding/staff/$weddingId/galerie/upload')),
        ],
      ),
      body: galleryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (List<GalleryModel> medias) {
          if (medias.isEmpty) return _EmptyState(weddingId: weddingId);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(galleryProvider(weddingId)),
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: medias.length,
              itemBuilder: (_, i) {
                final GalleryModel m = medias[i];
                return _GalleryTile(
                  media: m,
                  onTap: () => _openViewer(context, m),
                  onLongPress: () => _confirmDelete(context, ref, m),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/thix-weeding/staff/$weddingId/galerie/upload'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Uploader'),
      ),
    );
  }

  // ================= ACTIONS =================

  void _openViewer(BuildContext context, GalleryModel m) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(child: Image.network(m.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)))),
            Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
            Positioned(bottom: 12, left: 12, right: 12, child: Text(m.caption ?? '', style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GalleryModel m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer?'),
        content: Text('Supprimer ce média ID ${m.id.substring(0, 8)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(galleryServiceProvider).delete(m.id);
                ref.invalidate(galleryProvider(weddingId));
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ================= WIDGETS INTERNES =================

class _EmptyState extends StatelessWidget {
  final String weddingId;
  const _EmptyState({required this.weddingId});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.photo_library_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Aucune photo', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => context.push('/thix-weeding/staff/$weddingId/galerie/upload'), icon: const Icon(Icons.add_a_photo), label: const Text('Ajouter photos')),
        ]),
      );
}

class _GalleryTile extends StatelessWidget {
  final GalleryModel media;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _GalleryTile({required this.media, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              media.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
            ),
          ),
        ],
      ),
    );
  }
}
