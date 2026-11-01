// lib/presentation/thix_weeding/pages/staff/galerie/gallery_management_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — GALLERY MANAGEMENT (PRODUCTION)
// Design royal + Upload multi + Viewer plein écran + Légendes + Suppression
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ← AJOUTER CET IMPORT

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient royal = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class GalleryManagementPage extends ConsumerStatefulWidget {
  final String weddingId;
  const GalleryManagementPage({super.key, required this.weddingId});

  @override
  ConsumerState<GalleryManagementPage> createState() =>
      _GalleryManagementPageState();
}

class _GalleryManagementPageState extends ConsumerState<GalleryManagementPage>
    with SingleTickerProviderStateMixin {
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (images.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadTotal = images.length;
      _uploadProgress = 0;
    });

    int successCount = 0;
    for (final image in images) {
      try {
        final bytes = await image.readAsBytes();
        final url = await ref.read(galleryServiceProvider).uploadBytes(
              weddingId: widget.weddingId,
              bytes: bytes,
              fileName: image.name,
            );

        await ref.read(galleryServiceProvider).createRecord({
          'wedding_id': widget.weddingId,
          'image_url': url,
          'caption': null,
        });

        successCount++;
      } catch (e) {
        debugPrint('Erreur upload ${image.name}: $e');
      }

      if (mounted) {
        setState(() => _uploadProgress++);
      }
    }

    ref.invalidate(galleryProvider(widget.weddingId));

    if (mounted) {
      setState(() => _isUploading = false);
      _showSuccess('$successCount/${images.length} photo(s) ajoutée(s) ✓');
    }
  }

  Future<void> _deleteMedia(GalleryModel media) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _DeleteDialog(media: media),
    );
    if (ok != true) return;

    try {
      await ref.read(galleryServiceProvider).delete(media.id);
      ref.invalidate(galleryProvider(widget.weddingId));
      if (mounted) _showSuccess('Photo supprimée ✓');
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  Future<void> _editCaption(GalleryModel media) async {
    final controller = TextEditingController(text: media.caption ?? '');
    final newCaption = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _CaptionEditDialog(controller: controller),
    );

    if (newCaption == null) return;

    try {
      await Supabase.instance.client
          .from('thix_weeding_gallery')
          .update({'caption': newCaption.isEmpty ? null : newCaption})
          .eq('id', media.id);
      ref.invalidate(galleryProvider(widget.weddingId));
      if (mounted) _showSuccess('Légende mise à jour ✓');
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  void _openViewer(GalleryModel media, List<GalleryModel> allMedia) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(
          initialMedia: media,
          allMedia: allMedia,
          weddingId: widget.weddingId,
          onDelete: () => _deleteMedia(media),
          onEditCaption: () => _editCaption(media),
        ),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration:
                  const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final galleryAsync = ref.watch(galleryProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: galleryAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(galleryProvider(widget.weddingId)),
        ),
        data: (medias) => FadeTransition(
          opacity: _fadeAnim,
          child: _GalleryContent(
            weddingId: widget.weddingId,
            medias: medias,
            isUploading: _isUploading,
            uploadProgress: _uploadProgress,
            uploadTotal: _uploadTotal,
            onUpload: _pickAndUpload,
            onDelete: _deleteMedia,
            onEditCaption: _editCaption,
            onView: (m) => _openViewer(m, medias),
            onRefresh: () async =>
                ref.invalidate(galleryProvider(widget.weddingId)),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _GalleryContent extends StatelessWidget {
  final String weddingId;
  final List<GalleryModel> medias;
  final bool isUploading;
  final int uploadProgress;
  final int uploadTotal;
  final VoidCallback onUpload;
  final Function(GalleryModel) onDelete;
  final Function(GalleryModel) onEditCaption;
  final Function(GalleryModel) onView;
  final Future<void> Function() onRefresh;

  const _GalleryContent({
    required this.weddingId,
    required this.medias,
    required this.isUploading,
    required this.uploadProgress,
    required this.uploadTotal,
    required this.onUpload,
    required this.onDelete,
    required this.onEditCaption,
    required this.onView,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ───────────────────────────────────────────────────
        _GalleryAppBar(
          count: medias.length,
          onUpload: isUploading ? null : onUpload,
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── UPLOAD PROGRESS ─────────────────────────────────────
              if (isUploading) ...[
                _UploadProgressCard(
                  progress: uploadProgress,
                  total: uploadTotal,
                ),
                const SizedBox(height: 12),
              ],

              // ── STATS ──────────────────────────────────────────────
              _StatsBar(count: medias.length),
              const SizedBox(height: 12),

              // ── GRILLE / EMPTY ─────────────────────────────────────
              if (medias.isEmpty)
                _EmptyState(weddingId: weddingId, onUpload: onUpload)
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: medias.length,
                    itemBuilder: (_, i) {
                      final m = medias[i];
                      return _GalleryTile(
                        media: m,
                        onTap: () => onView(m),
                        onLongPress: () => _showContextMenu(
                          context,
                          m,
                          onDelete: () => onDelete(m),
                          onEditCaption: () => onEditCaption(m),
                        ),
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  void _showContextMenu(
    BuildContext context,
    GalleryModel media, {
    required VoidCallback onDelete,
    required VoidCallback onEditCaption,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaActionsSheet(
        media: media,
        onDelete: () {
          Navigator.pop(context);
          onDelete();
        },
        onEditCaption: () {
          Navigator.pop(context);
          onEditCaption();
        },
      ),
    );
  }
}

// ============================================================================
// APP BAR
// ============================================================================
class _GalleryAppBar extends StatelessWidget {
  final int count;
  final VoidCallback? onUpload;

  const _GalleryAppBar({required this.count, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
            ],
          ),
          child:
              const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onUpload,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.add_a_photo_outlined,
                  color: _R.blue, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.royal,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _R.gold.withOpacity(0.15),
                ),
              ),
            ),
            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.photo_library_outlined,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'GALERIE SOUVENIRS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Photos & Vidéos',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$count média${count > 1 ? 's' : ''} dans la galerie',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
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

// ============================================================================
// UPLOAD PROGRESS
// ============================================================================
class _UploadProgressCard extends StatelessWidget {
  final int progress;
  final int total;

  const _UploadProgressCard({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? progress / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _R.gold.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Upload en cours... $progress/$total',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${(ratio * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATS BAR
// ============================================================================
class _StatsBar extends StatelessWidget {
  final int count;

  const _StatsBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _R.card(r: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _R.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.photo, size: 14, color: _R.blue),
          ),
          const SizedBox(width: 8),
          Text(
            '$count photo${count > 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _R.text,
            ),
          ),
          const Spacer(),
          Text(
            'Appui long pour options',
            style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GALLERY TILE
// ============================================================================
class _GalleryTile extends StatelessWidget {
  final GalleryModel media;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GalleryTile({
    required this.media,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              media.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: _R.border,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: _R.blue,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: _R.border,
                child: const Icon(Icons.broken_image, color: _R.text2, size: 24),
              ),
            ),
            // Overlay caption indicator
            if (media.caption != null && media.caption!.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(
                    media.caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final String weddingId;
  final VoidCallback onUpload;

  const _EmptyState({required this.weddingId, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_R.blue.withOpacity(0.15), _R.purple.withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_outlined, size: 48, color: _R.blue),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune photo dans la galerie',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Ajoutez des photos pour créer vos souvenirs',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.add_a_photo, size: 18),
            label: const Text('Ajouter des photos'),
            style: FilledButton.styleFrom(
              backgroundColor: _R.blue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MEDIA ACTIONS SHEET
// ============================================================================
class _MediaActionsSheet extends StatelessWidget {
  final GalleryModel media;
  final VoidCallback onDelete;
  final VoidCallback onEditCaption;

  const _MediaActionsSheet({
    required this.media,
    required this.onDelete,
    required this.onEditCaption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _R.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Actions sur la photo',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.edit_note_outlined,
            label: 'Modifier la légende',
            subtitle: media.caption ?? 'Aucune légende',
            color: _R.blue,
            onTap: onEditCaption,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.delete_outline,
            label: 'Supprimer la photo',
            subtitle: 'Action irréversible',
            color: _R.rose,
            danger: true,
            onTap: onDelete,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool danger;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? color.withOpacity(0.06) : color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, color: color)),
                    Text(subtitle,
                        style:
                            GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _R.text2),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CAPTION EDIT DIALOG
// ============================================================================
class _CaptionEditDialog extends StatelessWidget {
  final TextEditingController controller;

  const _CaptionEditDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: _R.royal,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child:
                      const Icon(Icons.edit_note, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Modifier la légende',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Écrire une légende...',
                hintStyle: GoogleFonts.inter(color: _R.text2),
                filled: true,
                fillColor: _R.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.text,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DELETE DIALOG
// ============================================================================
class _DeleteDialog extends StatelessWidget {
  final GalleryModel media;

  const _DeleteDialog({required this.media});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: _R.roseG,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Supprimer cette photo ?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _R.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible. La photo sera définitivement supprimée de la galerie.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.text,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.rose,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FULL SCREEN VIEWER
// ============================================================================
class _FullScreenViewer extends StatefulWidget {
  final GalleryModel initialMedia;
  final List<GalleryModel> allMedia;
  final String weddingId;
  final VoidCallback onDelete;
  final VoidCallback onEditCaption;

  const _FullScreenViewer({
    required this.initialMedia,
    required this.allMedia,
    required this.weddingId,
    required this.onDelete,
    required this.onEditCaption,
  });

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allMedia.indexWhere((m) => m.id == widget.initialMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMedia = widget.allMedia[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_note, color: Colors.white, size: 18),
            ),
            onPressed: widget.onEditCaption,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
            ),
            onPressed: widget.onDelete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // Image viewer
            PageView.builder(
              controller: _pageController,
              itemCount: widget.allMedia.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final m = widget.allMedia[i];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.network(
                      m.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Bottom info bar
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 20 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentMedia.caption != null && currentMedia.caption!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            currentMedia.caption!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.allMedia.length}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _fmtDate(currentMedia.createdAt ?? DateTime.now()),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING / ERROR
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child:
                  const Icon(Icons.photo_library_outlined, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement de la galerie...',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _R.rose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.error_outline, color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger la galerie',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _R.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtDate(DateTime dt) {
  const months = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
    'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
