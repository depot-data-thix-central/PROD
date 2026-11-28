// lib/presentation/home/widgets/home_hub_customize_sheet.dart
//
// Panneau de personnalisation (ADMIN uniquement) :
// photos de fond, défilement auto, vitesse, intensité du voile,
// COULEUR DU VOILE (le blanc), couleur principale et couleur d'accent.
// Aperçu en direct ; rien n'est publié avant « Enregistrer ».
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_hub_settings.dart';
import 'home_theme.dart';

class HubCustomizeSheet extends StatefulWidget {
  final HomeHubController controller;
  const HubCustomizeSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    HomeHubController controller,
  ) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HubCustomizeSheet(controller: controller),
    );
    // Fermé sans enregistrer → on revient aux réglages publiés.
    controller.clearPreview();
  }

  @override
  State<HubCustomizeSheet> createState() => _HubCustomizeSheetState();
}

class _HubCustomizeSheetState extends State<HubCustomizeSheet> {
  static const List<Color> _primaryPresets = [
    Color(0xFF1746A2), // Bleu THIX
    Color(0xFF1E88E5), // Bleu ciel
    Color(0xFF0E9F6E), // Émeraude
    Color(0xFF6D28D9), // Violet
    Color(0xFFC62828), // Rouge
    Color(0xFFEA580C), // Orange
    Color(0xFF1F2937), // Ardoise
    Color(0xFFD9667A), // Rose
  ];

  static const List<Color> _accentPresets = [
    Color(0xFFFFB800), // Jaune THIX
    Color(0xFFF97316), // Orange
    Color(0xFF22C55E), // Vert
    Color(0xFF38BDF8), // Ciel
    Color(0xFFEC4899), // Rose
    Color(0xFFEF4444), // Rouge
  ];

  static const List<Color> _veilPresets = [
    Color(0xFFFFFFFF), // Blanc
    Color(0xFFFFF8E7), // Crème
    Color(0xFFE8F4FF), // Ciel clair
    Color(0xFFF1F5F9), // Gris clair
    Color(0xFF0B1F44), // Bleu nuit
    Color(0xFF111111), // Noir
    Color(0xFF0F2D1E), // Vert forêt
  ];

  late HubSettings _draft = widget.controller.saved;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  void _apply(HubSettings s) {
    if (!mounted) return;
    setState(() => _draft = s);
    widget.controller.setPreview(s);
  }

  Future<void> _pickImages() async {
    if (_uploading) return;
    final room = kHubMaxImages - _draft.images.length;
    if (room <= 0) {
      setState(() => _error = 'Maximum $kHubMaxImages photos.');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() {
        _uploading = true;
        _error = null;
      });

      final urls = <String>[];
      final errors = <String>[];

      for (final f in result.files.take(room)) {
        final ext = (f.extension ?? '').toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          errors.add('${f.name} : format refusé');
          continue;
        }
        final bytes = f.bytes ??
            (f.path != null ? await File(f.path!).readAsBytes() : null);
        if (bytes == null) {
          errors.add('${f.name} : lecture impossible');
          continue;
        }
        if (bytes.length > kHubMaxImageBytes) {
          errors.add('${f.name} : plus de 6 Mo');
          continue;
        }
        try {
          urls.add(await widget.controller.uploadImage(bytes, ext));
        } catch (e) {
          debugPrint('[HubCustomize] upload error: $e');
          errors.add('${f.name} : échec de l\'envoi');
        }
      }

      if (urls.isNotEmpty) {
        _apply(_draft.copyWith(images: [..._draft.images, ...urls]));
      }
      if (errors.isNotEmpty && mounted) {
        setState(() => _error = errors.join('\n'));
      }
    } catch (e) {
      debugPrint('[HubCustomize] pick error: $e');
      if (mounted) setState(() => _error = 'Impossible de lire les photos.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeImage(String url) {
    HapticFeedback.selectionClick();
    _apply(_draft.copyWith(
      images: _draft.images.where((u) => u != url).toList(),
    ));
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _apply(HubSettings.defaults.copyWith(images: _draft.images));
  }

  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.save(_draft);
      HapticFeedback.mediumImpact();
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Accueil mis à jour'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HomeTheme.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      debugPrint('[HubCustomize] save error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Enregistrement refusé. Vérifie le rôle admin et le SQL home_hub_settings (colonne veil_color).';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final p = _draft.primary;

    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: HomeTheme.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                Icon(Icons.palette_rounded, color: p, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Personnaliser l\'accueil',
                    style: TextStyle(
                      color: HomeTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: HomeTheme.inkSoft),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PHOTOS ──
                  _title('Photos de fond (${_draft.images.length}/$kHubMaxImages)'),
                  const SizedBox(height: 4),
                  const Text(
                    'Diversité africaine : villes, paysages, jeunes entrepreneurs, culture… '
                    'Format paysage, JPG / PNG / WebP, 6 Mo max.',
                    style: TextStyle(color: HomeTheme.inkSoft, fontSize: 11.5, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 92,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _addTile(p),
                        for (final url in _draft.images) _thumb(url),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── DÉFILEMENT ──
                  _title('Défilement automatique'),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Faire défiler les photos',
                          style: TextStyle(
                            color: HomeTheme.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: _draft.autoScroll,
                        activeColor: p,
                        onChanged: (v) => _apply(_draft.copyWith(autoScroll: v)),
                      ),
                    ],
                  ),
                  _sliderRow(
                    label: 'Vitesse',
                    valueText: '${_draft.intervalSeconds} s',
                    slider: Slider(
                      value: _draft.intervalSeconds.toDouble(),
                      min: 3,
                      max: 15,
                      divisions: 12,
                      activeColor: p,
                      onChanged: _draft.autoScroll
                          ? (v) => _apply(_draft.copyWith(intervalSeconds: v.round()))
                          : null,
                    ),
                  ),
                  _sliderRow(
                    label: 'Voile',
                    valueText: '${(_draft.veil * 100).round()} %',
                    slider: Slider(
                      value: _draft.veil,
                      min: 0.2,
                      max: 0.9,
                      activeColor: p,
                      onChanged: (v) => _apply(_draft.copyWith(veil: v)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── COULEUR DU VOILE (le blanc) ──
                  _title('Couleur du voile (le blanc)'),
                  const SizedBox(height: 4),
                  const Text(
                    'Sur un voile sombre, les textes passent en blanc automatiquement.',
                    style: TextStyle(color: HomeTheme.inkSoft, fontSize: 11.5, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final c in _veilPresets)
                        _Swatch(
                          color: c,
                          selected: c.value == _draft.veilColor.value,
                          onTap: () => _apply(_draft.copyWith(veilColor: c)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── COULEURS ──
                  _title('Couleur principale'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final c in _primaryPresets)
                        _Swatch(
                          color: c,
                          selected: c.value == _draft.primary.value,
                          onTap: () => _apply(_draft.copyWith(primary: c)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _title('Couleur d\'accent'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final c in _accentPresets)
                        _Swatch(
                          color: c,
                          selected: c.value == _draft.accent.value,
                          onTap: () => _apply(_draft.copyWith(accent: c)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: Icon(Icons.restart_alt_rounded, size: 18, color: p),
                    label: Text(
                      'Réinitialiser le style',
                      style: TextStyle(color: p, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 14 + bottom),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_saving || _uploading) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: p,
                  disabledBackgroundColor: p.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enregistrer pour tout le monde',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String t) => Text(
        t,
        style: const TextStyle(
          color: HomeTheme.ink,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      );

  Widget _sliderRow({
    required String label,
    required String valueText,
    required Widget slider,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(
              color: HomeTheme.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: slider),
        SizedBox(
          width: 44,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: HomeTheme.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile(Color p) {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 92,
        height: 92,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: p.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.withOpacity(0.35), width: 1.4),
        ),
        alignment: Alignment.center,
        child: _uploading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: p),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: p, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    'Ajouter',
                    style: TextStyle(
                      color: p,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _thumb(String url) {
    return Container(
      width: 92,
      height: 92,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: HomeTheme.skyMist),
              errorWidget: (_, __, ___) => Container(
                color: HomeTheme.skyMist,
                child: const Icon(Icons.broken_image_rounded,
                    color: HomeTheme.inkSoft),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: () => _removeImage(url),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Check lisible aussi sur les couleurs claires (blanc, crème…).
    final checkColor =
        color.computeLuminance() > 0.6 ? HomeTheme.ink : Colors.white;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? HomeTheme.ink : Colors.black12,
            width: selected ? 2.4 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 18, color: checkColor)
            : null,
      ),
    );
  }
}
