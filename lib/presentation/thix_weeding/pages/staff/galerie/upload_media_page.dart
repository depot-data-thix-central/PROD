// lib/presentation/thix_weeding/pages/staff/galerie/upload_media_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — UPLOAD MEDIA (PRODUCTION)
// Design royal + Multi-upload + Progression + Web/Mobile compatible
// ⚠️ PAS de dart:io → utilise uploadBytes pour compatibilité Web/WASM
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

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
// MODÈLE LOCAL POUR FICHIER SÉLECTIONNÉ
// ============================================================================
class _PickedMedia {
  final XFile file;
  final Uint8List bytes;
  final bool isVideo;

  _PickedMedia({
    required this.file,
    required this.bytes,
    required this.isVideo,
  });

  String get name => file.name;
  int get size => bytes.length;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class UploadMediaPage extends ConsumerStatefulWidget {
  final String weddingId;
  const UploadMediaPage({super.key, required this.weddingId});

  @override
  ConsumerState<UploadMediaPage> createState() => _UploadMediaPageState();
}

class _UploadMediaPageState extends ConsumerState<UploadMediaPage>
    with SingleTickerProviderStateMixin {
  final List<_PickedMedia> _picked = [];
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;
  int _uploadSuccess = 0;

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
    _captionCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // PICK
  // ============================================================================
  Future<void> _pickPhotos() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (files.isEmpty) return;

      for (final f in files) {
        final bytes = await f.readAsBytes();
        setState(() {
          _picked.add(_PickedMedia(file: f, bytes: bytes, isVideo: false));
        });
      }
    } catch (e) {
      _showError('Erreur sélection photos: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _picked.add(_PickedMedia(file: file, bytes: bytes, isVideo: true));
      });
    } catch (e) {
      _showError('Erreur sélection vidéo: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _picked.add(_PickedMedia(file: file, bytes: bytes, isVideo: false));
      });
    } catch (e) {
      _showError('Erreur caméra: $e');
    }
  }

  void _removeAt(int index) {
    setState(() => _picked.removeAt(index));
  }

  void _clearAll() {
    setState(() => _picked.clear());
  }

  // ============================================================================
  // UPLOAD
  // ============================================================================
  Future<void> _uploadAll() async {
    if (_picked.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadTotal = _picked.length;
      _uploadProgress = 0;
      _uploadSuccess = 0;
    });

    final supa = Supabase.instance.client;
    final caption = _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim();

    for (var i = 0; i < _picked.length; i++) {
      final media = _picked[i];
      try {
        final ext = media.name.contains('.')
            ? media.name.split('.').last.toLowerCase()
            : (media.isVideo ? 'mp4' : 'jpg');
        final safeExt = ['png', 'webp', 'jpg', 'jpeg', 'mp4', 'mov', 'avi', 'mkv']
                .contains(ext)
            ? ext
            : (media.isVideo ? 'mp4' : 'jpg');

        final fileName =
            '${widget.weddingId}/${DateTime.now().millisecondsSinceEpoch}_$i.$safeExt';

        final contentType = media.isVideo
            ? 'video/$safeExt'
            : (safeExt == 'png'
                ? 'image/png'
                : (safeExt == 'webp' ? 'image/webp' : 'image/jpeg'));

        await supa.storage.from('thix-weeding-gallery').uploadBinary(
              fileName,
              media.bytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                upsert: false,
                contentType: contentType,
              ),
            );

        final publicUrl =
            supa.storage.from('thix-weeding-gallery').getPublicUrl(fileName);

        await supa.from('thix_weeding_gallery').insert({
          'wedding_id': widget.weddingId,
          'image_url': publicUrl,
          'caption': caption,
        });

        _uploadSuccess++;
      } catch (e) {
        debugPrint('Erreur upload ${media.name}: $e');
      }

      if (mounted) {
        setState(() => _uploadProgress = i + 1);
      }
    }

    ref.invalidate(galleryProvider(widget.weddingId));

    if (mounted) {
      setState(() => _isUploading = false);
      if (_uploadSuccess == _uploadTotal) {
        _showSuccess('$_uploadSuccess média(s) uploadé(s) avec succès ✓');
        context.pop();
      } else {
        _showError('$_uploadSuccess/$_uploadTotal uploadé(s). ${_uploadTotal - _uploadSuccess} erreur(s).');
      }
    }
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

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── APP BAR ────────────────────────────────────────────────
            _UploadAppBar(pickedCount: _picked.length),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── BOUTONS DE SÉLECTION ───────────────────────────
                  _PickButtons(
                    onPhotos: _isUploading ? null : _pickPhotos,
                    onVideo: _isUploading ? null : _pickVideo,
                    onCamera: _isUploading ? null : _pickFromCamera,
                  ),
                  const SizedBox(height: 16),

                  // ── LÉGENDE ────────────────────────────────────────
                  _CaptionField(controller: _captionCtrl),
                  const SizedBox(height: 16),

                  // ── PROGRESSION UPLOAD ─────────────────────────────
                  if (_isUploading) ...[
                    _UploadProgressCard(
                      progress: _uploadProgress,
                      total: _uploadTotal,
                      success: _uploadSuccess,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── GRILLE DES MÉDIAS SÉLECTIONNÉS ─────────────────
                  if (_picked.isNotEmpty) ...[
                    _PickedHeader(
                      count: _picked.length,
                      totalSize: _picked.fold<int>(0, (s, m) => s + m.size),
                      onClearAll: _isUploading ? null : _clearAll,
                    ),
                    const SizedBox(height: 10),
                    _PickedGrid(
                      picked: _picked,
                      onRemove: _isUploading ? null : _removeAt,
                    ),
                    const SizedBox(height: 24),
                  ] else if (!_isUploading) ...[
                    _EmptyPicker(onPick: _pickPhotos),
                    const SizedBox(height: 24),
                  ],

                  // ── BOUTON UPLOAD ──────────────────────────────────
                  _UploadButton(
                    isLoading: _isUploading,
                    count: _picked.length,
                    onPressed: _uploadAll,
                  ),
                  const SizedBox(height: 12),

                  // ── NOTE INFO ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _R.blue.withOpacity(0.08),
                          _R.purple.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _R.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _R.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline,
                              color: _R.blue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Chaque média recevra un UUID unique en base de données. Les images sont optimisées automatiquement.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _R.blue,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// APP BAR
// ============================================================================
class _UploadAppBar extends StatelessWidget {
  final int pickedCount;

  const _UploadAppBar({required this.pickedCount});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: _R.text,
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
      title: Text(
        'Uploader des médias',
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w800, color: _R.blue, fontSize: 18),
      ),
      actions: [
        if (pickedCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: _R.goldG,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pickedCount sélectionné${pickedCount > 1 ? 's' : ''}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// PICK BUTTONS
// ============================================================================
class _PickButtons extends StatelessWidget {
  final VoidCallback? onPhotos;
  final VoidCallback? onVideo;
  final VoidCallback? onCamera;

  const _PickButtons({
    required this.onPhotos,
    required this.onVideo,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PickButton(
                icon: Icons.photo_library_outlined,
                label: 'Photos',
                subtitle: 'Galerie',
                gradient: _R.royal,
                onTap: onPhotos,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickButton(
                icon: Icons.videocam_outlined,
                label: 'Vidéo',
                subtitle: 'Galerie',
                gradient: _R.roseG,
                onTap: onVideo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickButton(
                icon: Icons.camera_alt_outlined,
                label: 'Caméra',
                subtitle: 'Photo rapide',
                gradient: _R.greenG,
                onTap: onCamera,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: disabled ? null : gradient,
            color: disabled ? _R.border : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: _R.blue.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CAPTION FIELD
// ============================================================================
class _CaptionField extends StatelessWidget {
  final TextEditingController controller;

  const _CaptionField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: _R.goldG,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.edit_note, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Légende commune',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex: Cérémonie civile, Salle décorée...',
              hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
              filled: true,
              fillColor: _R.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cette légende sera appliquée à tous les médias uploadés',
            style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
          ),
        ],
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
  final int success;

  const _UploadProgressCard({
    required this.progress,
    required this.total,
    required this.success,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? progress / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _R.gold.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload en cours...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$success réussi(s) • ${progress - success} erreur(s)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$progress/$total',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
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
// PICKED HEADER
// ============================================================================
class _PickedHeader extends StatelessWidget {
  final int count;
  final int totalSize;
  final VoidCallback? onClearAll;

  const _PickedHeader({
    required this.count,
    required this.totalSize,
    required this.onClearAll,
  });

  String get _totalSizeLabel {
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: _R.royal,
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              const Icon(Icons.photo_library, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count média${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                'Taille totale : $_totalSizeLabel',
                style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
              ),
            ],
          ),
        ),
        if (onClearAll != null)
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text('Tout retirer'),
            style: TextButton.styleFrom(
              foregroundColor: _R.rose,
              textStyle: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// PICKED GRID
// ============================================================================
class _PickedGrid extends StatelessWidget {
  final List<_PickedMedia> picked;
  final Function(int)? onRemove;

  const _PickedGrid({required this.picked, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: picked.length,
      itemBuilder: (_, i) {
        final m = picked[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: m.isVideo
                  ? Container(
                      color: _R.text.withOpacity(0.8),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam,
                                color: Colors.white, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              m.sizeLabel,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image.memory(
                      m.bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
            // Badge vidéo
            if (m.isVideo)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _R.rose,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 12),
                ),
              ),
            // Taille
            if (!m.isVideo)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Text(
                    m.sizeLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // Bouton supprimer
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove!(i),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: _R.rose,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// EMPTY PICKER
// ============================================================================
class _EmptyPicker extends StatelessWidget {
  final VoidCallback onPick;

  const _EmptyPicker({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _R.border, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _R.blue.withOpacity(0.15),
                    _R.purple.withOpacity(0.1)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.add_photo_alternate_outlined, size: 40, color: _R.blue),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun média sélectionné',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Appuyez sur Photos, Vidéo ou Caméra ci-dessus',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UPLOAD BUTTON
// ============================================================================
class _UploadButton extends StatelessWidget {
  final bool isLoading;
  final int count;
  final VoidCallback onPressed;

  const _UploadButton({
    required this.isLoading,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || count == 0;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: disabled ? null : _R.greenG,
        color: disabled ? _R.border : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: _R.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Upload en cours...',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        count > 0
                            ? 'Uploader $count média${count > 1 ? 's' : ''}'
                            : 'Sélectionnez des médias',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: disabled ? _R.text2 : Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
