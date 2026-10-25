// lib/presentation/thix_market/widgets/products/drc_portal_widgets.dart
// ============================================================================
// DRC PRODUCTS PORTAL — widgets
//  • DrcPortalLogo        : logo en haut (upload admin/moderator)
//  • DrcPartnersBand      : « Nos partenaires » — photos en défilement automatique
//  • DrcMediaManagerSheet : ajout / légende / suppression (admin & moderator)
// ============================================================================
import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/drc_portal_theme.dart';
import '../../providers/drc_portal_media_providers.dart';

const int _kSlideLoop = 200;
const Duration _kSlideDelay = Duration(seconds: 4);
const double _kBandHeight = 178;

void showDrcMediaManager(BuildContext context, {required String kind, required String title}) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DrcMediaManagerSheet(kind: kind, title: title),
  );
}

// ============================================================================
// LOGO
// ============================================================================
class DrcPortalLogo extends ConsumerWidget {
  const DrcPortalLogo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logos = ref.watch(drcPortalMediaProvider(kDrcKindLogo)).valueOrNull ?? const <DrcMedia>[];
    final isEditor = ref.watch(drcPortalEditorProvider).valueOrNull ?? false;
    final url = logos.isNotEmpty ? logos.first.imageUrl : null;
    final lang = Localizations.localeOf(context).languageCode;

    final plate = Container(
      constraints: const BoxConstraints(maxWidth: 200, minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              height: 38,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox(height: 38, width: 90),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        plate,
        if (isEditor)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => showDrcMediaManager(
                context,
                kind: kDrcKindLogo,
                title: lang == 'fr' ? 'Logo du portail' : 'Portal logo',
              ),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: kDrcYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.edit_rounded, size: 12, color: kDrcNavy),
              ),
            ),
          ),
      ],
    );
  }

  /// Emblème de secours tant qu'aucun logo n'est téléversé.
  Widget _fallback() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.public_rounded, color: kDrcBlue, size: 26),
        SizedBox(width: 7),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DRC', style: TextStyle(color: kDrcBlueDeep, fontWeight: FontWeight.w900, fontSize: 16, height: 1.0, letterSpacing: -0.3)),
            SizedBox(height: 1),
            Text('PRODUCTS PORTAL', style: TextStyle(color: kDrcSub, fontWeight: FontWeight.w800, fontSize: 7.5, letterSpacing: 1.1)),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// BANDE « NOS PARTENAIRES »
// ============================================================================
class DrcPartnersBand extends ConsumerWidget {
  final String lang;
  const DrcPartnersBand({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drcPortalMediaProvider(kDrcKindPartner)).valueOrNull ?? const <DrcMedia>[];
    final isEditor = ref.watch(drcPortalEditorProvider).valueOrNull ?? false;

    // Visiteurs : rien tant qu'il n'y a pas de photo. Éditeurs : espace d'ajout visible.
    if (items.isEmpty && !isEditor) return const SizedBox.shrink();

    final title = lang == 'fr' ? 'Nos partenaires' : (lang == 'sw' ? 'Washirika wetu' : 'Our partners');
    final manage = lang == 'fr' ? 'Gérer' : (lang == 'sw' ? 'Simamia' : 'Manage');

    void open() => showDrcMediaManager(context, kind: kDrcKindPartner, title: title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const DrcTricolorBar(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kDrcInk, letterSpacing: -0.5),
                ),
              ),
              if (isEditor)
                GestureDetector(
                  onTap: open,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: kDrcSoft, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_photo_alternate_rounded, size: 14, color: kDrcBlueDeep),
                        const SizedBox(width: 5),
                        Text(manage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kDrcBlueDeep)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _emptyEditor(open)
        else
          _DrcAutoSlides(items: items),
      ],
    );
  }

  Widget _emptyEditor(VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: kDrcSoft.withOpacity(0.6),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kDrcBlue.withOpacity(0.35), width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_rounded, size: 30, color: kDrcBlue),
              const SizedBox(height: 8),
              Text(
                lang == 'fr'
                    ? 'Ajouter les photos de nos partenaires'
                    : 'Add our partners\' photos',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: kDrcBlueDeep),
              ),
              const SizedBox(height: 2),
              Text(
                lang == 'fr' ? 'Défilement automatique · Admin & modérateurs' : 'Auto-scrolling · Admins & moderators',
                style: const TextStyle(fontSize: 10, color: kDrcSub, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carrousel infini à défilement automatique (pause au toucher).
class _DrcAutoSlides extends StatefulWidget {
  final List<DrcMedia> items;
  const _DrcAutoSlides({required this.items});

  @override
  State<_DrcAutoSlides> createState() => _DrcAutoSlidesState();
}

class _DrcAutoSlidesState extends State<_DrcAutoSlides> {
  late PageController _ctrl;
  Timer? _timer;
  int _page = 0;
  bool _dragging = false;

  int get _n => widget.items.length;

  PageController _make(int n) {
    final start = n > 1 ? n * (_kSlideLoop ~/ 2) : 0;
    _page = start;
    return PageController(viewportFraction: n > 1 ? 0.92 : 1.0, initialPage: start);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = _make(_n);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _DrcAutoSlides old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) {
      final oldCtrl = _ctrl;
      _ctrl = _make(_n);
      WidgetsBinding.instance.addPostFrameCallback((_) => oldCtrl.dispose());
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_n < 2) return;
    _timer = Timer.periodic(_kSlideDelay, (_) {
      if (!mounted || _dragging || !_ctrl.hasClients || _n < 2) return;
      _ctrl.nextPage(duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _n;
    final current = n == 0 ? 0 : _page % n;

    return Column(
      children: [
        SizedBox(
          height: _kBandHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (nt) {
              if (nt is ScrollStartNotification && nt.dragDetails != null) {
                _dragging = true;
              } else if (nt is ScrollEndNotification && _dragging) {
                _dragging = false;
                _startTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _ctrl,
              itemCount: n > 1 ? n * _kSlideLoop : 1,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _slide(widget.items[i % n], single: n == 1),
            ),
          ),
        ),
        if (n > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < n; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == current ? 20 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == current ? kDrcBlue : kDrcLine,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _slide(DrcMedia m, {required bool single}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: single ? 16 : 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: kDrcSoft,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: kDrcBlueDeep.withOpacity(0.14), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: m.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (_, __) => const ColoredBox(color: kDrcSoft),
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: kDrcMuted)),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, kDrcNavy.withOpacity(m.title.isEmpty ? 0.0 : 0.65)],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (m.title.isNotEmpty)
              Positioned(
                left: 12,
                bottom: 14,
                right: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Text(
                          m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const Positioned(left: 0, right: 0, bottom: 0, child: DrcTricolorStripe(height: 3)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FEUILLE DE GESTION (ADMIN & MODERATOR)
// ============================================================================
class DrcMediaManagerSheet extends ConsumerStatefulWidget {
  final String kind; // 'logo' | 'partner'
  final String title;
  const DrcMediaManagerSheet({super.key, required this.kind, required this.title});

  @override
  ConsumerState<DrcMediaManagerSheet> createState() => _DrcMediaManagerSheetState();
}

class _DrcMediaManagerSheetState extends ConsumerState<DrcMediaManagerSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  String _progress = '';

  bool get _isLogo => widget.kind == kDrcKindLogo;

  String _t(String fr, String en) => Localizations.localeOf(context).languageCode == 'fr' ? fr : en;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? kDrcRed : kDrcInk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('row-level security') || m.contains('403') || m.contains('unauthorized') || m.contains('not authorized')) {
      return _t('Accès refusé : réservé aux administrateurs et modérateurs.', 'Access denied: admins and moderators only.');
    }
    if (m.contains('mime') || m.contains('not supported')) {
      return _t('Format non supporté (JPG, PNG ou WebP).', 'Unsupported format (JPG, PNG or WebP).');
    }
    if (m.contains('too large') || m.contains('413') || m.contains('size')) {
      return _t('Image trop lourde (8 Mo max).', 'Image too large (8 MB max).');
    }
    return _t('Échec de l\'envoi. Réessayez.', 'Upload failed. Please retry.');
  }

  Future<void> _removeRowAndFile(DrcMedia m) async {
    final client = Supabase.instance.client;
    await client.from(kDrcTable).delete().eq('id', m.id);
    if (m.storagePath.isNotEmpty) {
      try {
        await client.storage.from(kDrcBucket).remove([m.storagePath]);
      } catch (e) {
        debugPrint('[DRC Portal] ⚠️ storage remove error: $e');
      }
    }
  }

  Future<void> _add(List<DrcMedia> current) async {
    if (_busy) return;

    List<XFile> picked = [];
    try {
      if (_isLogo) {
        final x = await _picker.pickImage(source: ImageSource.gallery);
        if (x != null) picked = [x];
      } else {
        final remaining = kDrcMaxPartners - current.length;
        if (remaining <= 0) {
          _snack(_t('Maximum $kDrcMaxPartners photos.', 'Maximum $kDrcMaxPartners photos.'), error: true);
          return;
        }
        final list = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
        picked = list.take(remaining).toList();
      }
    } catch (e) {
      debugPrint('[DRC Portal] ⚠️ picker error: $e');
      _snack(_t('Impossible d\'ouvrir la galerie.', 'Unable to open the gallery.'), error: true);
      return;
    }
    if (picked.isEmpty) return;

    final client = Supabase.instance.client;
    int ok = 0;
    int failed = 0;
    Object? lastError;
    int nextOrder = current.fold<int>(-1, (m, b) => b.sortOrder > m ? b.sortOrder : m) + 1;

    setState(() {
      _busy = true;
      _progress = '0/${picked.length}';
    });

    for (int i = 0; i < picked.length; i++) {
      final f = picked[i];
      String? uploadedPath;
      try {
        final bytes = await f.readAsBytes();
        if (bytes.length > kDrcMaxFileBytes) {
          failed++;
          lastError = 'too large';
          continue;
        }
        var ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'jpg';
        if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)) ext = 'jpg';
        final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
        final path = '${widget.kind}/${DateTime.now().microsecondsSinceEpoch}_$i.$ext';

        await client.storage.from(kDrcBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mime, upsert: false),
            );
        uploadedPath = path;

        await client.from(kDrcTable).insert({
          'kind': widget.kind,
          'image_url': client.storage.from(kDrcBucket).getPublicUrl(path),
          'storage_path': path,
          'sort_order': nextOrder++,
          'is_active': true,
        });
        ok++;
      } catch (e) {
        failed++;
        lastError = e;
        debugPrint('[DRC Portal] ❌ upload error: $e');
        if (uploadedPath != null) {
          try {
            await client.storage.from(kDrcBucket).remove([uploadedPath]);
          } catch (_) {}
        }
      }
      if (mounted) setState(() => _progress = '${i + 1}/${picked.length}');
    }

    // Logo : le nouveau remplace l'ancien
    if (_isLogo && ok > 0) {
      for (final old in current) {
        try {
          await _removeRowAndFile(old);
        } catch (e) {
          debugPrint('[DRC Portal] ⚠️ old logo cleanup error: $e');
        }
      }
    }

    ref.invalidate(drcPortalMediaProvider(widget.kind));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = '';
    });

    if (ok > 0 && failed == 0) {
      _snack(_isLogo ? _t('Logo mis à jour.', 'Logo updated.') : _t('$ok photo(s) ajoutée(s).', '$ok photo(s) added.'));
    } else if (ok > 0) {
      _snack(_t('$ok ajoutée(s), $failed échec(s).', '$ok added, $failed failed.'), error: true);
    } else {
      _snack(_friendlyError(lastError ?? ''), error: true);
    }
  }

  Future<void> _delete(DrcMedia m) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Supprimer cette photo ?', 'Delete this photo?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler', 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kDrcRed),
            child: Text(_t('Supprimer', 'Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _removeRowAndFile(m);
      ref.invalidate(drcPortalMediaProvider(widget.kind));
      _snack(_t('Photo supprimée.', 'Photo deleted.'));
    } catch (e) {
      debugPrint('[DRC Portal] ❌ delete error: $e');
      _snack(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(DrcMedia m) async {
    if (_busy || _isLogo) return;
    final ctrl = TextEditingController(text: m.title);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Nom du partenaire', 'Partner name'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: _t('Affiché sur la photo (optionnel)', 'Shown on the photo (optional)')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Annuler', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(_t('Enregistrer', 'Save'))),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client
          .from(kDrcTable)
          .update({'title': value.isEmpty ? null : value})
          .eq('id', m.id);
      ref.invalidate(drcPortalMediaProvider(widget.kind));
    } catch (e) {
      debugPrint('[DRC Portal] ❌ rename error: $e');
      _snack(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(drcPortalMediaProvider(widget.kind));
    final items = async.valueOrNull ?? const <DrcMedia>[];
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kDrcLine, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: kDrcSoft, borderRadius: BorderRadius.circular(11)),
                    child: Icon(_isLogo ? Icons.badge_rounded : Icons.photo_library_rounded, size: 16, color: kDrcBlueDeep),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: kDrcInk, letterSpacing: -0.3)),
                        Text(
                          _isLogo
                              ? _t('Remplace le logo affiché en haut du portail', 'Replaces the logo shown at the top of the portal')
                              : _t('${items.length}/$kDrcMaxPartners · défilement automatique', '${items.length}/$kDrcMaxPartners · auto-scrolling'),
                          style: const TextStyle(fontSize: 10.5, color: kDrcMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (async.isLoading && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator(color: kDrcBlue, strokeWidth: 2.5)),
                )
              else if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  decoration: BoxDecoration(color: kDrcBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kDrcLine)),
                  child: Column(
                    children: [
                      const Icon(Icons.image_outlined, size: 30, color: kDrcMuted),
                      const SizedBox(height: 8),
                      Text(
                        _isLogo
                            ? _t('Aucun logo : l\'emblème par défaut est affiché.', 'No logo: the default emblem is shown.')
                            : _t('Aucune photo pour le moment.', 'No photo yet.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: kDrcSub, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (int i = 0; i < items.length; i++) _thumb(items[i], i)],
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _add(items),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDrcBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kDrcBlue.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: Text(
                    _busy
                        ? '${_t('Envoi', 'Uploading')} $_progress'
                        : (_isLogo ? _t('Choisir le logo', 'Choose logo') : _t('Ajouter des photos', 'Add photos')),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t('JPG, PNG ou WebP · 8 Mo max · Réservé aux administrateurs et modérateurs.',
                    'JPG, PNG or WebP · 8 MB max · Admins and moderators only.'),
                style: const TextStyle(fontSize: 10, color: kDrcMuted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(DrcMedia m, int index) {
    final size = _isLogo ? 150.0 : 96.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _rename(m),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: _isLogo ? Colors.white : kDrcBg,
                  child: CachedNetworkImage(
                    imageUrl: m.imageUrl,
                    fit: _isLogo ? BoxFit.contain : BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(color: kDrcBg),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: kDrcMuted),
                  ),
                ),
              ),
            ),
          ),
          if (!_isLogo)
            Positioned(
              left: 5,
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(7)),
                child: Row(
                  children: [
                    Text('${index + 1}', style: const TextStyle(color: kDrcYellow, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m.title.isEmpty ? _t('+ nom', '+ name') : m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _busy ? null : () => _delete(m),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: kDrcRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
