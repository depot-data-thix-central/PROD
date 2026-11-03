// lib/presentation/thix_weeding/pages/provider_portal/offers/provider_offer_form_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../models/provider_models.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — FORMULAIRE OFFRE DYNAMIQUE (Production v2)
/// ✅ Champs spécifiques par type (traiteur, salle, MC, gâteau...)
/// ✅ Upload vidéo (2 min max, 50 MB max)
/// ✅ Multi-photos
/// ✅ Validation complète
/// ═══════════════════════════════════════════════════════════════════════

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
}

class ProviderOfferFormPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final ProviderOfferModel? existing;

  const ProviderOfferFormPage({
    super.key,
    required this.provider,
    this.existing,
  });

  @override
  ConsumerState<ProviderOfferFormPage> createState() => _ProviderOfferFormPageState();
}

class _ProviderOfferFormPageState extends ConsumerState<ProviderOfferFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late OfferType _type;
  final Set<ProviderCategory> _categories = {};
  bool _isActive = true;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _uploadingVideo = false;

  // Médias
  final List<String> _imageUrls = [];
  final List<Uint8List> _localImageBytes = [];
  String? _videoUrl;
  Uint8List? _localVideoBytes;
  VideoPlayerController? _videoController;

  // Champs spécifiques par type
  Map<String, dynamic> _typeSpecificData = {};

  // Contraintes vidéo
  static const int _maxVideoDurationSeconds = 170; // 2 min 50 sec
  static const int _maxVideoSizeBytes = 50 * 1024 * 1024; // 50 MB

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(
      text: e?.price != null ? e!.price!.toStringAsFixed(0) : '',
    );
    _type = e?.type ?? OfferType.service;
    _isActive = e?.isActive ?? true;

    // Charger catégories existantes
    if (e != null && e.categories.isNotEmpty) {
      _categories.addAll(e.categories);
    } else {
      _categories.add(widget.provider.category);
    }

    // Charger images existantes
    if (e?.imageUrl != null && e!.imageUrl!.isNotEmpty) {
      _imageUrls.add(e.imageUrl!);
    }
    if (e != null) {
      for (final u in e.galleryUrls) {
        if (u.isNotEmpty && !_imageUrls.contains(u)) {
          _imageUrls.add(u);
        }
      }
    }

    // Charger vidéo existante
    _videoUrl = e?.videoUrl;

    // Charger données spécifiques
    _typeSpecificData = Map<String, dynamic>.from(e?.typeSpecificData ?? {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UPLOAD IMAGES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') 
          ? picked.name.split('.').last.toLowerCase() 
          : 'jpg';

      setState(() {
        _localImageBytes.add(bytes);
        _imageUrls.add('');
      });

      await _uploadImage(bytes, ext, _imageUrls.length - 1);
    } catch (e) {
      _showError('Erreur sélection image: $e');
    }
  }

  Future<void> _uploadImage(Uint8List bytes, String ext, int slot) async {
    setState(() => _uploadingImage = true);

    try {
      final client = Supabase.instance.client;
      final safeExt = ['png', 'webp', 'jpg', 'jpeg'].contains(ext) ? ext : 'jpg';
      final filename =
          '${widget.provider.id}/offers/${DateTime.now().millisecondsSinceEpoch}_$slot.$safeExt';

      await client.storage.from('thix-provider-media').uploadBinary(
            filename,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: 'image/$safeExt',
              upsert: false,
            ),
          );

      final url = client.storage.from('thix-provider-media').getPublicUrl(filename);

      if (!mounted) return;

      setState(() {
        _imageUrls[slot] = url;
      });

      _showSuccess('Photo ${slot + 1} uploadée ✓');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (slot < _imageUrls.length) {
          _imageUrls.removeAt(slot);
          _localImageBytes.removeAt(slot);
        }
      });

      _showError('Erreur upload image: $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _imageUrls.length) _imageUrls.removeAt(index);
      if (index < _localImageBytes.length) _localImageBytes.removeAt(index);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UPLOAD VIDÉO (2 min max, 50 MB max)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _pickVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: _maxVideoDurationSeconds),
      );

      if (picked == null) return;

      // Vérifier la taille
      final file = File(picked.path);
      final size = await file.length();

      if (size > _maxVideoSizeBytes) {
        _showError('Vidéo trop volumineuse. Maximum 50 MB.');
        return;
      }

      final bytes = await file.readAsBytes();

      setState(() {
        _localVideoBytes = bytes;
        _videoUrl = null;
      });

      // Vérifier la durée
      await _validateVideoDuration(picked.path);

      if (_videoController != null && 
          _videoController!.value.duration.inSeconds > _maxVideoDurationSeconds) {
        _showError('Vidéo trop longue. Maximum 2 minutes 50 secondes.');
        setState(() {
          _localVideoBytes = null;
          _videoController?.dispose();
          _videoController = null;
        });
        return;
      }

      await _uploadVideo(bytes, picked.name.split('.').last);
    } catch (e) {
      _showError('Erreur sélection vidéo: $e');
    }
  }

  Future<void> _validateVideoDuration(String path) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(path));
    await _videoController!.initialize();
    setState(() {});
  }

  Future<void> _uploadVideo(Uint8List bytes, String ext) async {
    setState(() => _uploadingVideo = true);

    try {
      final client = Supabase.instance.client;
      final safeExt = ['mp4', 'mov', 'avi'].contains(ext) ? ext : 'mp4';
      final filename =
          '${widget.provider.id}/videos/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

      await client.storage.from('thix-provider-videos').uploadBinary(
            filename,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: 'video/$safeExt',
              upsert: false,
            ),
          );

      final url = client.storage.from('thix-provider-videos').getPublicUrl(filename);

      if (!mounted) return;

      setState(() {
        _videoUrl = url;
        _localVideoBytes = null;
      });

      _showSuccess('Vidéo uploadée ✓');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _localVideoBytes = null;
      });

      _showError('Erreur upload vidéo: $e');
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  void _removeVideo() {
    setState(() {
      _videoUrl = null;
      _localVideoBytes = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GESTION CATÉGORIES
  // ═══════════════════════════════════════════════════════════════════════

  void _toggleCategory(ProviderCategory c) {
    HapticFeedback.selectionClick();

    setState(() {
      if (_categories.contains(c)) {
        if (_categories.length > 1) {
          _categories.remove(c);
        } else {
          _showError('Au moins 1 catégorie requise');
        }
      } else {
        if (_categories.length < 3) {
          _categories.add(c);
        } else {
          _showError('Maximum 3 catégories par annonce');
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CHAMPS SPÉCIFIQUES PAR TYPE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTypeSpecificFields() {
    switch (_type) {
      case OfferType.menu:
        return _TraiteurFields(
          data: _typeSpecificData,
          onChanged: (data) => setState(() => _typeSpecificData = data),
        );
      case OfferType.service:
        if (widget.provider.category == ProviderCategory.salle) {
          return _SalleFields(
            data: _typeSpecificData,
            onChanged: (data) => setState(() => _typeSpecificData = data),
          );
        } else if (widget.provider.category == ProviderCategory.mc) {
          return _MCFields(
            data: _typeSpecificData,
            onChanged: (data) => setState(() => _typeSpecificData = data),
          );
        } else if (widget.provider.category == ProviderCategory.patissier) {
          return _GateauFields(
            data: _typeSpecificData,
            onChanged: (data) => setState(() => _typeSpecificData = data),
          );
        } else if (widget.provider.category == ProviderCategory.dj) {
          return _DJFields(
            data: _typeSpecificData,
            onChanged: (data) => setState(() => _typeSpecificData = data),
          );
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAUVEGARDE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final price = _priceCtrl.text.trim().isEmpty 
          ? null 
          : double.tryParse(_priceCtrl.text.trim());
      final desc = _descCtrl.text.trim().isEmpty 
          ? null 
          : _descCtrl.text.trim();
      final cover = _imageUrls.isNotEmpty ? _imageUrls.first : null;
      final gallery = _imageUrls.length > 1 
          ? _imageUrls.sublist(1) 
          : <String>[];
      final categoriesList = _categories.toList();

      final offerData = {
        'title': _titleCtrl.text.trim(),
        'description': desc,
        'price': price,
        'type': _type.name,
        'type_specific_data': _typeSpecificData,
        'categories': categoriesList.map((c) => c.name).toList(),
        'image_url': cover,
        'gallery_urls': gallery,
        'video_url': _videoUrl,
        'is_active': _isActive,
      };

      if (widget.existing == null) {
        // Créer nouvelle offre
        await ref.read(createOfferProvider)(
          providerId: widget.provider.id,
          title: _titleCtrl.text.trim(),
          type: _type,
          description: desc,
          price: price,
          imageUrl: cover,
          galleryUrls: gallery,
          categories: categoriesList,
          isActive: _isActive,
          typeSpecificData: _typeSpecificData,
          videoUrl: _videoUrl,
        );
      } else {
        // Mettre à jour offre existante
        await ref.read(updateOfferProvider)(
          widget.existing!.id,
          widget.provider.id,
          title: _titleCtrl.text.trim(),
          type: _type,
          description: desc,
          price: price,
          imageUrl: cover,
          galleryUrls: gallery,
          categories: categoriesList,
          isActive: _isActive,
          typeSpecificData: _typeSpecificData,
          videoUrl: _videoUrl,
        );
      }

      if (!mounted) return;

      context.pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null
                ? 'Offre publiée ✓ ${_imageUrls.length} photo(s), ${_videoUrl != null ? '1 vidéo' : '0 vidéo'}'
                : 'Offre mise à jour ✓',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          backgroundColor: _P.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _P.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _P.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _P.inkSoft, fontSize: 13),
        prefixIcon: Icon(icon, color: _P.rose, size: 20),
        filled: true,
        fillColor: _P.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(
          widget.existing == null ? 'Publier une offre' : 'Modifier l\'offre',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════ SECTION MÉDIAS ═══════════════
                _SectionTitle(
                  title: 'Médias',
                  icon: Icons.photo_library,
                  badge: '${_imageUrls.length} photo(s)${_videoUrl != null ? ' + 1 vidéo' : ''}',
                ),
                const SizedBox(height: 12),

                // Zone upload images
                _buildImageUploadZone(),
                const SizedBox(height: 16),

                // Zone upload vidéo
                _buildVideoUploadZone(),
                const SizedBox(height: 24),

                // ═══════════════ SECTION INFORMATIONS ═══════════════
                _SectionTitle(title: 'Informations', icon: Icons.info_outline),
                const SizedBox(height: 12),

                // Titre
                Text(
                  'Titre de l\'offre *',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().length < 3 ? 'Titre requis (min 3 caractères)' : null,
                  decoration: _dec('Ex: Menu mariage 200 personnes', Icons.title_rounded),
                ),
                const SizedBox(height: 18),

                // Type d'offre
                Text(
                  'Type d\'offre *',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OfferType.values.map((t) {
                    final sel = _type == t;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _type = t;
                          _typeSpecificData = {}; // Reset champs spécifiques
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? _P.rose : _P.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? _P.rose : _P.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getOfferTypeIcon(t),
                              size: 15,
                              color: sel ? Colors.white : _P.inkSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : _P.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Catégories (1 à 3)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Catégories * (1 à 3)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _P.rose.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_categories.length}/3',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _P.rose),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ProviderCategory.values.map((c) {
                    final sel = _categories.contains(c);
                    return GestureDetector(
                      onTap: () => _toggleCategory(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel ? _P.rose : _P.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: sel ? _P.rose : _P.line),
                          boxShadow: sel
                              ? [BoxShadow(color: _P.rose.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(c),
                              size: 14,
                              color: sel ? Colors.white : _P.inkSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              c.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : _P.ink,
                              ),
                            ),
                            if (sel) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Prix
                Text(
                  'Prix (USD) — laisser vide pour "Sur devis"',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v != null && v.isNotEmpty && (double.tryParse(v) ?? -1) < 0) {
                      return 'Prix invalide';
                    }
                    return null;
                  },
                  decoration: _dec('Ex: 1500', Icons.attach_money_rounded),
                ),
                const SizedBox(height: 18),

                // Description
                Text(
                  'Description',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  maxLength: 400,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Décrivez votre offre en détail...', Icons.edit_note_rounded),
                ),
                const SizedBox(height: 24),

                // ═══════════════ CHAMPS SPÉCIFIQUES ═══════════════
                if (_buildTypeSpecificFields() is! SizedBox)
                  _SectionTitle(title: 'Détails spécifiques', icon: Icons.tune),
                const SizedBox(height: 12),
                _buildTypeSpecificFields(),
                const SizedBox(height: 24),

                // ═══════════════ VISIBILITÉ ═══════════════
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _P.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _P.line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        color: _isActive ? _P.green : _P.inkSoft,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Visible sur le catalogue et l\'accueil',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: _P.green,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Bouton de sauvegarde
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving || _uploadingImage || _uploadingVideo ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _P.rose,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving || _uploadingImage || _uploadingVideo
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.existing == null ? 'Publier l\'offre' : 'Enregistrer',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WIDGETS MÉDIAS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildImageUploadZone() {
    final items = <Widget>[];

    for (var i = 0; i < _imageUrls.length; i++) {
      final url = _imageUrls[i];
      final bytes = i < _localImageBytes.length ? _localImageBytes[i] : null;
      final hasUrl = url.isNotEmpty;

      items.add(_PhotoCard(
        index: i,
        imageUrl: hasUrl ? url : null,
        localBytes: (!hasUrl && bytes != null) ? bytes : null,
        isCover: i == 0,
        onRemove: () => _removeImage(i),
        isUploading: !hasUrl,
      ));
    }

    items.add(_AddPhotoCard(
      onPickGallery: () => _pickImage(ImageSource.gallery),
      onPickCamera: () => _pickImage(ImageSource.camera),
      uploading: _uploadingImage,
    ));

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  Widget _buildVideoUploadZone() {
    if (_videoUrl != null || _localVideoBytes != null) {
      return _VideoCard(
        videoUrl: _videoUrl,
        localBytes: _localVideoBytes,
        onRemove: _removeVideo,
        isUploading: _uploadingVideo,
      );
    }

    return GestureDetector(
      onTap: _uploadingVideo ? null : _pickVideo,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.purple.withOpacity(0.4), style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.videocam_outlined, color: _P.purple, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Ajouter une vidéo',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.ink),
              ),
              Text(
                'Max 2 min 50 • 50 MB',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _P.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS ICONS
  // ═══════════════════════════════════════════════════════════════════════

  IconData _getOfferTypeIcon(OfferType t) => switch (t) {
        OfferType.service => Icons.build_rounded,
        OfferType.menu => Icons.restaurant_menu_rounded,
        OfferType.package => Icons.card_giftcard_rounded,
        OfferType.promo => Icons.local_offer_rounded,
      };

  IconData _getCategoryIcon(ProviderCategory c) => switch (c) {
        ProviderCategory.salle => Icons.meeting_room_rounded,
        ProviderCategory.traiteur => Icons.restaurant_rounded,
        ProviderCategory.photographe => Icons.camera_alt_rounded,
        ProviderCategory.videaste => Icons.videocam_rounded,
        ProviderCategory.decorateur => Icons.palette_rounded,
        ProviderCategory.dj => Icons.music_note_rounded,
        ProviderCategory.mc => Icons.mic_rounded,
        ProviderCategory.maquilleur => Icons.face_rounded,
        ProviderCategory.patissier => Icons.cake_rounded,
        ProviderCategory.fleuriste => Icons.local_florist_rounded,
      };
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS SECTIONS
// ═══════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? badge;

  const _SectionTitle({
    required this.title,
    required this.icon,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _P.rose.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _P.rose, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _P.rose.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _P.rose),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS PHOTOS
// ═══════════════════════════════════════════════════════════════════════

class _PhotoCard extends StatelessWidget {
  final int index;
  final String? imageUrl;
  final Uint8List? localBytes;
  final bool isCover;
  final VoidCallback onRemove;
  final bool isUploading;

  const _PhotoCard({
    required this.index,
    required this.imageUrl,
    required this.localBytes,
    required this.isCover,
    required this.onRemove,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Container(
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isCover ? _P.rose : _P.line, width: isCover ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            else if (localBytes != null)
              Image.memory(localBytes!, fit: BoxFit.cover)
            else
              _fallback(),

            if (isUploading && imageUrl == null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                  ),
                ),
              ),

            if (isCover)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _P.rose,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'COUVERTURE',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: _P.inkSoft.withOpacity(0.1),
        child: const Icon(Icons.image_outlined, color: _P.inkSoft, size: 32),
      );
}

class _AddPhotoCard extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final bool uploading;

  const _AddPhotoCard({
    required this.onPickGallery,
    required this.onPickCamera,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : _showSourceChoice(context),
      child: SizedBox(
        width: 130,
        child: Container(
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _P.rose.withOpacity(0.4), style: BorderStyle.solid),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _P.rose.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined, color: _P.rose, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ajouter',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.ink),
                ),
                Text(
                  'une photo',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _P.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _showSourceChoice(BuildContext context) => () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined, color: _P.rose),
                    title: Text(
                      'Depuis la galerie',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onPickGallery();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined, color: _P.rose),
                    title: Text(
                      'Prendre une photo',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onPickCamera();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      };
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGET VIDÉO
// ═══════════════════════════════════════════════════════════════════════

class _VideoCard extends StatelessWidget {
  final String? videoUrl;
  final Uint8List? localBytes;
  final VoidCallback onRemove;
  final bool isUploading;

  const _VideoCard({
    required this.videoUrl,
    required this.localBytes,
    required this.onRemove,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.purple),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 120,
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.videocam,
                    color: _P.purple,
                    size: 40,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        videoUrl != null ? 'Vidéo uploadée' : 'Vidéo en cours d\'upload...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _P.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        videoUrl != null ? 'Visible dans l\'offre' : 'Patientez...',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUploading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _P.purple),
                  ),
                ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
