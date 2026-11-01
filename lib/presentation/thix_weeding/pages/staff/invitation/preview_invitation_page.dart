// lib/presentation/thix_weeding/pages/staff/invitation/preview_invitation_page.dart
// ============================================================================
// THIX WEDDING — INVITATION STUDIO v4.0 (PRODUCTION)
// ✅ Éditeur complet + Aperçu Live
// ✅ 10 Templates Premium distincts (Royale, Botanique, Moderne, Vintage...)
// ✅ Upload Photo Hero via Supabase Storage
// ✅ Sauvegarde Config JSONB
// ============================================================================
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/thix_weeding_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM & HELPERS
// ═══════════════════════════════════════════════════════════════════════════
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color cream = Color(0xFFFFFBF5);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  
  static BoxDecoration card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      );
}

TextStyle _mono({double? fontSize, FontWeight? fontWeight, Color? color}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: fontSize ?? 12,
    fontWeight: fontWeight ?? FontWeight.w600,
    color: color ?? _R.text2,
    letterSpacing: 0.5,
  );
}

// Structure de données stockée en JSONB
class InvitationConfig {
  String templateId;
  String heroImageUrl;
  String titleText;
  String introText;
  String outroText;
  Color primaryColor;
  Color bgColor;
  String fontStyle; 

  InvitationConfig({
    this.templateId = 'royal_gold',
    this.heroImageUrl = '',
    this.titleText = 'Save The Date',
    this.introText = 'Nous avons l\'honneur de vous inviter au mariage de',
    this.outroText = 'Venez célébrer cet amour avec nous.',
    this.primaryColor = const Color(0xFFD4AF37),
    this.bgColor = const Color(0xFFFFFBF5),
    this.fontStyle = 'playfair_display',
  });

  factory InvitationConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return InvitationConfig();
    
    // Parsing couleurs hex string -> Color
    Color parseColor(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      try {
        final cleanHex = hex.replaceAll('#', '');
        return Color(int.parse('FF$cleanHex', radix: 16));
      } catch (_) {
        return fallback;
      }
    }

    return InvitationConfig(
      templateId: map['template_id'] as String? ?? 'royal_gold',
      heroImageUrl: map['hero_image_url'] as String? ?? '',
      titleText: map['title_text'] as String? ?? 'Save The Date',
      introText: map['intro_text'] as String? ?? '',
      outroText: map['outro_text'] as String? ?? '',
      primaryColor: parseColor(map['primary_color'], const Color(0xFFD4AF37)),
      bgColor: parseColor(map['background_color'], const Color(0xFFFFFBF5)),
      fontStyle: map['font_style'] as String? ?? 'playfair_display',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'hero_image_url': heroImageUrl,
      'title_text': titleText,
      'intro_text': introText,
      'outro_text': outroText,
      'primary_color': '#${primaryColor.value.toRadixString(16).substring(2)}',
      'background_color': '#${bgColor.value.toRadixString(16).substring(2)}',
      'font_style': fontStyle,
    };
  }
}

// Enum des 10 templates disponibles
enum TemplateType {
  royalGold,      // Luxe doré classique
  botanicalLeaf,  // Feuilles vertes minimalistes
  modernBold,     // Typographie géante noir/blanc
  vintagePaper,   // Papier kraft / sépia
  floralPink,     // Roses romantiques
  darkElegant,    // Fond sombre or blanc
  watercolorArt,  // Effet aquarelle doux
  geometricLine,  // Lignes fines modernes
  scriptClassic,  // Écriture manuscrite élégante
  photoFrame,     // Grande photo centrale cadre fin
}

extension TemplateExt on TemplateType {
  String get id {
    switch (this) {
      case TemplateType.royalGold: return 'royal_gold';
      case TemplateType.botanicalLeaf: return 'botanical_leaf';
      case TemplateType.modernBold: return 'modern_bold';
      case TemplateType.vintagePaper: return 'vintage_paper';
      case TemplateType.floralPink: return 'floral_pink';
      case TemplateType.darkElegant: return 'dark_elegant';
      case TemplateType.watercolorArt: return 'watercolor_art';
      case TemplateType.geometricLine: return 'geometric_line';
      case TemplateType.scriptClassic: return 'script_classic';
      case TemplateType.photoFrame: return 'photo_frame';
    }
  }

  String get name {
    switch (this) {
      case TemplateType.royalGold: return 'Royal Gold';
      case TemplateType.botanicalLeaf: return 'Botanic Leaf';
      case TemplateType.modernBold: return 'Modern Bold';
      case TemplateType.vintagePaper: return 'Vintage Kraft';
      case TemplateType.floralPink: return 'Rose Romance';
      case TemplateType.darkElegant: return 'Dark Luxury';
      case TemplateType.watercolorArt: return 'Watercolor Soft';
      case TemplateType.geometricLine: return 'Geometric Line';
      case TemplateType.scriptClassic: return 'Script Classic';
      case TemplateType.photoFrame: return 'Photo Frame';
    }
  }
  
  IconData get icon {
    switch (this) {
      case TemplateType.royalGold: return Icons.auto_awesome;
      case TemplateType.botanicalLeaf: return Icons.eco;
      case TemplateType.modernBold: return Icons.format_size;
      case TemplateType.vintagePaper: return Icons.bookmark_border;
      case TemplateType.floralPink: return Icons.favorite;
      case TemplateType.darkElegant: return Icons.nights_stay;
      case TemplateType.watercolorArt: return Icons.brush;
      case TemplateType.geometricLine: return Icons.linear_scale;
      case TemplateType.scriptClassic: return Icons.edit_note;
      case TemplateType.photoFrame: return Icons.crop_original;
    }
  }
}

// Provider local
final weddingInvitationProvider = FutureProvider.family<WeddingModel, String>((ref, weddingId) async {
  final data = await Supabase.instance.client
      .from('thix_weeding_weddings')
      .select()
      .eq('id', weddingId)
      .single();
  return WeddingModel.fromJson(data);
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE (STATEFUL)
// ═══════════════════════════════════════════════════════════════════════════
class PreviewInvitationPage extends ConsumerStatefulWidget {
  final String weddingId;
  const PreviewInvitationPage({super.key, required this.weddingId});

  @override
  ConsumerState<PreviewInvitationPage> createState() => _PreviewInvitationPageState();
}

class _PreviewInvitationPageState extends ConsumerState<PreviewInvitationPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _introCtrl;
  late TextEditingController _outroCtrl;
  
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  
  // État local de la config
  InvitationConfig _config = InvitationConfig();
  TemplateType _selectedTemplate = TemplateType.royalGold;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: 'Save The Date');
    _introCtrl = TextEditingController(text: 'Nous avons l\'honneur de vous inviter au mariage de');
    _outroCtrl = TextEditingController(text: 'Venez célébrer cet amour avec nous.');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _introCtrl.dispose();
    _outroCtrl.dispose();
    super.dispose();
  }

  // Logique d'upload photo vers Supabase Storage
  Future<void> _uploadHeroImage() async {
    setState(() => _isUploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
      
      if (picked != null) {
        final fileName = '${widget.weddingId}_hero_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await picked.readAsBytes();
        
        // Upload vers bucket 'thix-weeding-gallery'
        await Supabase.instance.client.storage
            .from('thix-weeding-gallery')
            .uploadBinary(fileName, bytes);
            
        final publicUrl = Supabase.instance.client.storage.from('thix-weeding-gallery').getPublicUrl(fileName);
        
        setState(() {
          _config.heroImageUrl = publicUrl;
        });
        
        await _saveConfig(); // Auto-save après upload
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload: $e'), backgroundColor: _R.rose));
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      // Mettre à jour l'état interne depuis les controllers avant save
      _config.titleText = _titleCtrl.text;
      _config.introText = _introCtrl.text;
      _config.outroText = _outroCtrl.text;
      _config.templateId = _selectedTemplate.id;

      await Supabase.instance.client
          .from('thix_weeding_weddings')
          .update({'invitation_config': _config.toMap()})
          .eq('id', widget.weddingId);
          
      ref.invalidate(weddingInvitationProvider(widget.weddingId));
      
      if(mounted) {
         HapticFeedback.successImpact();
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
           content: Text('Design enregistré ✓', style: TextStyle(fontWeight: FontWeight.bold)),
           backgroundColor: _R.green,
           behavior: SnackBarBehavior.floating,
           duration: Duration(seconds: 1),
         ));
      }
    } catch (e) {
       if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur sauvegarde: $e'), backgroundColor: _R.rose));
       }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(weddingInvitationProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.cream,
      appBar: AppBar(
        title: const Text('Studio d\'Invitation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveConfig,
            icon: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _R.blue))
              : const Icon(Icons.save_alt, color: _R.blue),
            tooltip: 'Enregistrer',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: weddingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (wedding) {
          // Initialiser les valeurs si premier chargement ou changement de template
          // Note: On ne réinitialise pas les ctrl.text ici pour ne pas écraser la saisie utilisateur
          // mais on synchronise la config globale si elle changeait côté serveur (rare)
          
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // ── APERÇU LIVE (LE CŒUR DU DESIGN) ───────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 0.75, // Ratio portrait type carte postale
                    child: _buildSelectedTemplate(wedding),
                  ),
                ),
                
                const SizedBox(height: 10),

                // ── SÉLECTEUR DE TEMPLATE (GRILLE) ────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choisir un modèle', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _R.text)),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
                        children: TemplateType.values.map((type) {
                          final isSelected = _selectedTemplate == type;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedTemplate = type);
                              // Optionnel : changer les couleurs par défaut selon le thème
                              if(type == TemplateType.darkElegant) {
                                _config.bgColor = const Color(0xFF1A1A2E);
                                _config.primaryColor = const Color(0xFFD4AF37);
                              } else if (type == TemplateType.botanicalLeaf) {
                                _config.bgColor = const Color(0xFFF5F9F0);
                                _config.primaryColor = const Color(0xFF2D5016);
                              } else {
                                _config.bgColor = const Color(0xFFFFFBF5);
                                _config.primaryColor = const Color(0xFFD4AF37);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? _R.blue : _R.border,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected ? _R.blue.withOpacity(0.05) : Colors.white,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(type.icon, size: 24, color: isSelected ? _R.blue : _R.text2),
                                  const SizedBox(height: 4),
                                  Text(
                                    type.name.split(' ').first, // Nom court
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: isSelected ? _R.blue : _R.text),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── PERSONNALISATION TEXTE ────────────────────────────
                _SectionCard(
                  title: 'Contenu Texte',
                  icon: Icons.text_fields,
                  children: [
                    _InputField(label: 'Titre Principal', controller: _titleCtrl, onChanged: (v) => _config.titleText = v),
                    const SizedBox(height: 12),
                    _InputField(label: 'Message d\'Accueil', controller: _introCtrl, maxLines: 2, onChanged: (v) => _config.introText = v),
                    const SizedBox(height: 12),
                    _InputField(label: 'Mot de Fin / RSVP', controller: _outroCtrl, maxLines: 2, onChanged: (v) => _config.outroText = v),
                  ],
                ),

                const SizedBox(height: 16),

                // ── APPARENCE VISUELLE ────────────────────────────────
                _SectionCard(
                  title: 'Apparence',
                  icon: Icons.palette_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ColorPickerTile(
                            label: 'Couleur Accent',
                            selected: _config.primaryColor,
                            colors: [_R.gold, _R.rose, _R.blue, _R.green, Colors.black],
                            onChanged: (c) => setState(() => _config.primaryColor = c),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ColorPickerTile(
                            label: 'Arrière-plan',
                            selected: _config.bgColor,
                            colors: [_R.cream, Colors.white, Color(0xFFF0F4F8), Color(0xFF1A1A2E)],
                            onChanged: (c) => setState(() => _config.bgColor = c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Bouton Upload Photo
                    OutlinedButton.icon(
                      onPressed: _isUploadingPhoto ? null : _uploadHeroImage,
                      icon: _isUploadingPhoto 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file),
                      label: Text(_config.heroImageUrl.isNotEmpty ? 'Changer la photo' : 'Ajouter une photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _R.blue,
                        side: BorderSide(color: _R.border),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    
                    if (_config.heroImageUrl.isNotEmpty) ...[
                       const SizedBox(height: 12),
                       Container(
                         height: 120,
                         decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(_config.heroImageUrl), fit: BoxFit.cover)),
                       )
                    ]
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Routeur dynamique vers les 10 templates
  Widget _buildSelectedTemplate(WeddingModel wedding) {
    switch (_selectedTemplate) {
      case TemplateType.royalGold: return _TplRoyalGold(config: _config, wedding: wedding);
      case TemplateType.botanicalLeaf: return _TplBotanicalLeaf(config: _config, wedding: wedding);
      case TemplateType.modernBold: return _TplModernBold(config: _config, wedding: wedding);
      case TemplateType.vintagePaper: return _TplVintagePaper(config: _config, wedding: wedding);
      case TemplateType.floralPink: return _TplFloralPink(config: _config, wedding: wedding);
      case TemplateType.darkElegant: return _TplDarkElegant(config: _config, wedding: wedding);
      case TemplateType.watercolorArt: return _TplWatercolorArt(config: _config, wedding: wedding);
      case TemplateType.geometricLine: return _TplGeometricLine(config: _config, wedding: wedding);
      case TemplateType.scriptClassic: return _TplScriptClassic(config: _config, wedding: wedding);
      case TemplateType.photoFrame: return _TplPhotoFrame(config: _config, wedding: wedding);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UI COMMUNS
// ═══════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: _R.blue),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String> onChanged;
  const _InputField({required this.label, required this.controller, this.maxLines = 1, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _R.text2)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _R.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _R.blue, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ColorPickerTile extends StatelessWidget {
  final String label;
  final Color selected;
  final List<Color> colors;
  final ValueChanged<Color> onChanged;
  const _ColorPickerTile({required this.label, required this.selected, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: _R.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _R.text2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: colors.map((c) {
              final isSelected = c.value == selected.value;
              return GestureDetector(
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                    boxShadow: isSelected ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)] : [],
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LES 10 TEMPLATES PREMIUM (DESIGN CODE À LA MAIN)
// ═══════════════════════════════════════════════════════════════════════════

// --- 1. ROYAL GOLD (Classique, Or, Bordures doubles) ---
class _TplRoyalGold extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplRoyalGold({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: config.bgColor,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Cadre extérieur
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: config.primaryColor, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Cadre intérieur
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: config.primaryColor.withOpacity(0.5), width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Contenu
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, color: config.primaryColor, size: 24),
                const SizedBox(height: 10),
                Text(config.titleText.toUpperCase(), style: GoogleFonts.playfairDisplay(fontSize: 14, letterSpacing: 3, color: config.primaryColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text(wedding.brideName, style: GoogleFonts.playfairDisplay(fontSize: 28, fontStyle: FontStyle.italic, color: _R.text)),
                Text('&', style: GoogleFonts.playfairDisplay(fontSize: 20, color: config.primaryColor)),
                Text(wedding.groomName, style: GoogleFonts.playfairDisplay(fontSize: 28, fontStyle: FontStyle.italic, color: _R.text)),
                const SizedBox(height: 20),
                Container(width: 40, height: 1, color: config.primaryColor),
                const SizedBox(height: 15),
                Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.playfairDisplay(fontSize: 12, color: _R.text2)),
                if(wedding.venue != null) Text(wedding.venue!, style: GoogleFonts.playfairDisplay(fontSize: 10, color: _R.text2, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. BOTANICAL LEAF (Vert nature, Feuilles décoratives) ---
class _TplBotanicalLeaf extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplBotanicalLeaf({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: config.bgColor,
      child: Stack(
        children: [
          // Décor coin haut gauche
          Positioned(top: -20, left: -20, child: Transform.rotate(angle: 0.5, child: Icon(Icons.eco, size: 100, color: config.primaryColor.withOpacity(0.1)))),
          // Décor coin bas droite
          Positioned(bottom: -20, right: -20, child: Transform.rotate(angle: 0.5, child: Icon(Icons.local_florist, size: 100, color: config.primaryColor.withOpacity(0.1)))),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(config.titleText, style: GoogleFonts.montserrat(fontSize: 12, letterSpacing: 2, color: config.primaryColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 15),
                  Text(wedding.brideName, style: GoogleFonts.dancingScript(fontSize: 36, color: _R.text)),
                  Text('and', style: GoogleFonts.montserrat(fontSize: 14, color: _R.text2)),
                  Text(wedding.groomName, style: GoogleFonts.dancingScript(fontSize: 36, color: _R.text)),
                  const SizedBox(height: 20),
                  Divider(thickness: 1, indent: 60, endIndent: 60, color: config.primaryColor),
                  const SizedBox(height: 10),
                  Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.montserrat(fontSize: 11, color: _R.text2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. MODERN BOLD (Typographie massive, Noir & Blanc) ---
class _TplModernBold extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplModernBold({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('WEDDING', style: GoogleFonts.oswald(fontSize: 10, letterSpacing: 5, color: _R.text2)),
          const SizedBox(height: 10),
          Text(wedding.brideName.toUpperCase(), style: GoogleFonts.oswald(fontSize: 32, height: 0.9, color: _R.text, fontWeight: FontWeight.w700)),
          Text('&', style: GoogleFonts.oswald(fontSize: 24, color: config.primaryColor)),
          Text(wedding.groomName.toUpperCase(), style: GoogleFonts.oswald(fontSize: 32, height: 0.9, color: _R.text, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(width: 50, height: 4, color: config.primaryColor),
          const SizedBox(height: 10),
          Text(_fmtDate(wedding.weddingDate).toUpperCase(), style: GoogleFonts.oswald(fontSize: 12, color: _R.text2)),
        ],
      ),
    );
  }
}

// --- 4. VINTAGE PAPER (Kraft/Sépia, Tampon postal) ---
class _TplVintagePaper extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplVintagePaper({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDFBF7), // Couleur papier vieilli
      child: Stack(
        children: [
          // Texture subtile simulée par opacité
          Positioned.fill(child: Container(color: Colors.orange.shade50.withOpacity(0.1))),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('SAVE THE DATE', style: GoogleFonts.specialElite(fontSize: 14, color: const Color(0xFF5C4A3A), letterSpacing: 2)),
                const SizedBox(height: 10),
                Text('~ ${wedding.brideName} ~', style: GoogleFonts.spectralMedium(fontSize: 24, color: const Color(0xFF3D2F1F), fontStyle: FontStyle.italic)),
                Text('AND', style: GoogleFonts.spectralSmallCaps(fontSize: 12, color: const Color(0xFF8B7355))),
                Text('~ ${wedding.groomName} ~', style: GoogleFonts.spectralMedium(fontSize: 24, color: const Color(0xFF3D2F1F), fontStyle: FontStyle.italic)),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8B7355))),
                  child: Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.spectralSmallCaps(fontSize: 10, color: const Color(0xFF5C4A3A))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 5. FLORAL PINK (Romantique, Doux, Rose) ---
class _TplFloralPink extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplFloralPink({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF0F5),
      child: Stack(
        children: [
          // Fleurs corners
          Positioned(top: 10, left: 10, child: Icon(Icons.favorite, color: Colors.pink.shade200, size: 40)),
          Positioned(bottom: 10, right: 10, child: Icon(Icons.favorite, color: Colors.pink.shade200, size: 40)),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('You are invited', style: GoogleFonts.quicksand(fontSize: 12, color: Colors.pink.shade400)),
                const SizedBox(height: 10),
                Text(wedding.brideName, style: GoogleFonts.pacifico(fontSize: 30, color: Colors.pink.shade700)),
                Text('❤', style: TextStyle(fontSize: 20, color: Colors.pink.shade300)),
                Text(wedding.groomName, style: GoogleFonts.pacifico(fontSize: 30, color: Colors.pink.shade700)),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.quicksand(fontSize: 12, color: _R.text2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 6. DARK ELEGANT (Luxueux, Fond sombre, Or) ---
class _TplDarkElegant extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplDarkElegant({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('THE WEDDING OF', style: GoogleFonts.marcellus(fontSize: 10, letterSpacing: 4, color: Colors.amber.shade300)),
          const SizedBox(height: 20),
          Text(wedding.brideName, style: GoogleFonts.cormorantGaramond(fontSize: 32, color: Colors.white, fontStyle: FontStyle.italic)),
          Text('&', style: GoogleFonts.cormorantGaramond(fontSize: 24, color: Colors.amber.shade300)),
          Text(wedding.groomName, style: GoogleFonts.cormorantGaramond(fontSize: 32, color: Colors.white, fontStyle: FontStyle.italic)),
          const SizedBox(height: 30),
          Container(width: 60, height: 1, color: Colors.amber.shade300),
          const SizedBox(height: 10),
          Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.marcellus(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// --- 7. WATERCOLOR ART (Artistique, Flou, Pastel) ---
class _TplWatercolorArt extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplWatercolorArt({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.purple.shade50, Colors.pink.shade50]),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // Simuler un effet aquarelle avec des cercles flous
             Stack(
               alignment: Alignment.center,
               children: [
                 Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.4), boxShadow: [BoxShadow(blurRadius: 40, color: Colors.blue.withOpacity(0.2))])),
                 Text('MARIAGE', style: GoogleFonts.kalam(fontSize: 14, color: _R.text, letterSpacing: 2)),
               ],
             ),
             const SizedBox(height: 15),
             Text('${wedding.brideName} & ${wedding.groomName}', style: GoogleFonts.indieFlower(fontSize: 26, color: _R.text)),
             const SizedBox(height: 10),
             Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.indieFlower(fontSize: 14, color: _R.text2)),
          ],
        ),
      ),
    );
  }
}

// --- 8. GEOMETRIC LINE (Minimaliste, Lignes droites) ---
class _TplGeometricLine extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplGeometricLine({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: CustomPaint(
        painter: _GeoPainter(lineColor: config.primaryColor),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('JOIN US', style: GoogleFonts.rubikMonoOne(fontSize: 10, color: _R.text2)),
              const SizedBox(height: 10),
              Text(wedding.brideName, style: GoogleFonts.rubik(fontSize: 24, fontWeight: FontWeight.w300, color: _R.text)),
              Text('+', style: GoogleFonts.rubik(fontSize: 20, color: config.primaryColor)),
              Text(wedding.groomName, style: GoogleFonts.rubik(fontSize: 24, fontWeight: FontWeight.w300, color: _R.text)),
              const SizedBox(height: 20),
              Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.rubik(fontSize: 12, color: _R.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

// Painter pour lignes géométriques
class _GeoPainter extends CustomPainter {
  final Color lineColor;
  _GeoPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor.withOpacity(0.2)..strokeWidth = 1;
    // Diagonales subtiles
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    // Cercle central
    canvas.drawCircle(Offset(size.width/2, size.height/2), size.width * 0.3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 9. SCRIPT CLASSIC (Manuscrit ancien, Encre bleue/noire) ---
class _TplScriptClassic extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplScriptClassic({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAF9F6), // Blanc cassé
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Dear Friends,', style: GoogleFonts.allura(fontSize: 20, color: _R.text2)),
          const SizedBox(height: 10),
          Text('We invite you to celebrate our union.', style: GoogleFonts.allura(fontSize: 18, color: _R.text)),
          const SizedBox(height: 20),
          Text(wedding.brideName, style: GoogleFonts.allura(fontSize: 40, color: config.primaryColor)),
          Text('and', style: GoogleFonts.allura(fontSize: 20, color: _R.text2)),
          Text(wedding.groomName, style: GoogleFonts.allura(fontSize: 40, color: config.primaryColor)),
          const SizedBox(height: 20),
          Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.allura(fontSize: 18, color: _R.text)),
        ],
      ),
    );
  }
}

// --- 10. PHOTO FRAME (Grande image, Cadre fin) ---
class _TplPhotoFrame extends StatelessWidget {
  final InvitationConfig config;
  final WeddingModel wedding;
  const _TplPhotoFrame({required this.config, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: config.heroImageUrl.isNotEmpty
                ? Image.network(config.heroImageUrl, fit: BoxFit.cover, width: double.infinity)
                : Container(color: _R.border, child: const Center(child: Icon(Icons.image_not_supported, size: 40, color: _R.text2))),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderTop: Border.all(color: config.primaryColor, width: 2)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(wedding.brideName, style: GoogleFonts.playfairDisplay(fontSize: 18, color: _R.text)),
                  Text('&', style: GoogleFonts.playfairDisplay(fontSize: 14, color: config.primaryColor)),
                  Text(wedding.groomName, style: GoogleFonts.playfairDisplay(fontSize: 18, color: _R.text)),
                  const SizedBox(height: 4),
                  Text(_fmtDate(wedding.weddingDate), style: GoogleFonts.playfairDisplay(fontSize: 10, color: _R.text2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Utilitaire date
String _fmtDate(DateTime? dt) {
  if (dt == null) return 'Date à définir';
  const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
