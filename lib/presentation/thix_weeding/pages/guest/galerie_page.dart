// lib/presentation/thix_weeding/pages/guest/galerie_page.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../../core/failure.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../staff/models/thix_weeding_models.dart';

part 'galerie_page.g.dart';

// ============================================================
// PALETTE — Charte THIX MARIAGE
// ============================================================
class _P {
  static const bg = Color(0xFFFFFBFC);
  static const surface = Colors.white;
  static const primary = Color(0xFFE31C4E);
  static const primarySoft = Color(0xFFFFE3EA);
  static const accent = Color(0xFFD4AF37);
  static const ink = Color(0xFF241521);
  static const inkSoft = Color(0xFF8A7580);

  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE31C4E), Color(0xFFFF6B8B)],
  );

  static final shadow = [
    BoxShadow(
      color: const Color(0xFFE31C4E).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    )
  ];
}

// ============================================================
// STATE PAGINE
// ============================================================
class GalleryPageState {
  final List<GalleryModel> photos;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  const GalleryPageState({
    this.photos = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  GalleryPageState copyWith({
    List<GalleryModel>? photos,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      GalleryPageState(
        photos: photos ?? this.photos,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

// ============================================================
// PROVIDER — Lecture seule (pas d'upload invité)
// ============================================================
@riverpod
class WeddingGallery extends _$WeddingGallery {
  static const _pageSize = 30;

  @override
  Future<GalleryPageState> build(String weddingId) async {
    final repo = ref.read(weddingRepositoryProvider);
    final first = await repo.getGallery(weddingId, page: 1);
    return GalleryPageState(
      photos: first.map((url) => GalleryModel(
        id: url.hashCode.toString(),
        weddingId: weddingId,
        url: url,
      )).toList(),
      page: 1,
      hasMore: first.length >= _pageSize,
    );
  }

  Future<void> fetchNext() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repo = ref.read(weddingRepositoryProvider);
      final next = await repo.getGallery(weddingId, page: current.page + 1);
      final newPhotos = next.map((url) => GalleryModel(
        id: url.hashCode.toString(),
        weddingId: weddingId,
        url: url,
      )).toList();

      state = AsyncData(current.copyWith(
        photos: [...current.photos, ...newPhotos],
        page: current.page + 1,
        hasMore: next.length >= _pageSize,
        isLoadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

// ============================================================
// PAGE GALERIE — Invité (Lecture seule)
// ============================================================
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
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
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
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.surface,
        foregroundColor: _P.ink,
        elevation: 0,
        title: const Text('Galerie', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: galleryAsync.when(
        data: (state) {
          if (state.photos.isEmpty) {
            return const _EmptyGalleryView();
          }

          return RefreshIndicator(
            color: _P.primary,
            onRefresh: () => ref.read(weddingGalleryProvider(widget.weddingId).notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // HEADER
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _GalleryHeader(count: state.photos.length),
                  ),
                ),

                // GRILLE
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= state.photos.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(color: _P.primary, strokeWidth: 2),
                            ),
                          );
                        }
                        final photo = state.photos[index];
                        return _PhotoTile(
                          photo: photo,
                          onTap: () => _openViewer(context, photo, state.photos),
                        );
                      },
                      childCount: state.photos.length + (state.isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _P.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 56, color: _P.inkSoft),
                const SizedBox(height: 12),
                Text(
                  e is Failure ? e.message : 'Erreur de chargement',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _P.ink),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(weddingGalleryProvider(widget.weddingId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                  style: FilledButton.styleFrom(backgroundColor: _P.primary),
                ),
              ],
            ),
          ),
        ),
      ),
      // ❌ PAS de FAB d'upload pour l'invité (réservé au Staff)
    );
  }

  void _openViewer(BuildContext context, GalleryModel photo, List<GalleryModel> allPhotos) {
    final initialIndex = allPhotos.indexWhere((p) => p.id == photo.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryViewer(
          photos: allPhotos,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }
}

// ============================================================
// WIDGETS
// ============================================================
class _GalleryHeader extends StatelessWidget {
  final int count;
  const _GalleryHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _P.shadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: _P.gradPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count souvenirs', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.ink)),
                const SizedBox(height: 2),
                const Text(
                  'Cliquez pour voir en plein écran et télécharger',
                  style: TextStyle(color: _P.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final GalleryModel photo;
  final VoidCallback onTap;
  const _PhotoTile({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          photo.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: _P.primarySoft,
            child: const Icon(Icons.broken_image_rounded, color: _P.primary, size: 32),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: _P.primarySoft,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _P.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyGalleryView extends StatelessWidget {
  const _EmptyGalleryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _P.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _P.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.photo_camera_rounded, size: 56, color: _P.primary),
            ),
            const SizedBox(height: 20),
            const Text('Aucun souvenir pour le moment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.ink)),
            const SizedBox(height: 8),
            const Text(
              'L\'organisation publiera bientôt les photos de l\'événement. Revenez plus tard !',
              textAlign: TextAlign.center,
              style: TextStyle(color: _P.inkSoft, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// VISIONNEUSE IMMERSIVE
// ============================================================
class _GalleryViewer extends StatefulWidget {
  final List<GalleryModel> photos;
  final int initialIndex;
  const _GalleryViewer({required this.photos, required this.initialIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late PageController _pageCtrl;
  late int _currentIndex;
  bool _downloading = false;
  bool _uiVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    final photo = widget.photos[_currentIndex];
    setState(() => _downloading = true);
    try {
      final response = await http.get(Uri.parse(photo.imageUrl));
      if (response.statusCode != 200) throw Exception('Téléchargement échoué');
      final bytes = response.bodyBytes;
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'image/jpeg',
        name: 'thix_wedding_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await Share.shareXFiles([xfile], text: 'Photo du mariage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo prête à enregistrer / partager'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareCurrent() async {
    final photo = widget.photos[_currentIndex];
    try {
      final response = await http.get(Uri.parse(photo.imageUrl));
      if (response.statusCode != 200) throw Exception('Erreur partage');

      final bytes = response.bodyBytes;
      final name = 'thix_wedding_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'image/jpeg',
        name: name,
      );
      // API share_plus stable (web + mobile)
      await Share.shareXFiles([xfile], text: 'Photo du mariage');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.primary),
        );
      }
    }
  }

  void _toggleUI() => setState(() => _uiVisible = !_uiVisible);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PHOTOS EN PLEIN ÉCRAN
          GestureDetector(
            onTap: _toggleUI,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final p = widget.photos[index];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      p.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: _P.primary));
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // TOP BAR
          if (_uiVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentIndex + 1} / ${widget.photos.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // BOTTOM BAR
          if (_uiVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ViewerButton(
                        icon: Icons.download_rounded,
                        label: 'Télécharger',
                        onTap: _downloading ? null : _downloadCurrent,
                        loading: _downloading,
                      ),
                      _ViewerButton(
                        icon: Icons.share_rounded,
                        label: 'Partager',
                        onTap: _shareCurrent,
                      ),
                      _ViewerButton(
                        icon: Icons.favorite_border_rounded,
                        label: 'Favori',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❤️ Ajouté aux favoris'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



class _ViewerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _ViewerButton({required this.icon, required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
