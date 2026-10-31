// lib/presentation/thix_weeding/pages/staff/invitation/preview_invitation_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — PREVIEW INVITATION (PRODUCTION) — CORRIGÉ
// 6 Templates Premium + QR unique + Multi-partage
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// PROVIDER LOCAL
// ============================================================================
final weddingInvitationProvider = FutureProvider.family<WeddingModel, String>((ref, weddingId) async {
  final data = await Supabase.instance.client
      .from('thix_weeding_weddings')
      .select()
      .eq('id', weddingId)
      .single();
  return WeddingModel.fromJson(data);
});

// ============================================================================
// STYLE MONOSPACE GLOBAL (compatible Web / WASM)
// ============================================================================
const TextStyle _monoStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
  letterSpacing: 0.5,
);

TextStyle _mono({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
}) {
  return _monoStyle.copyWith(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing ?? 0.5,
  );
}

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color roseSoft = Color(0xFFFFE4EC);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cream = Color(0xFFFFFBF5);
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
// TEMPLATES PREMIUM D'INVITATION
// ============================================================================
enum _TemplateId {
  royalGold,
  modernMinimal,
  roseRomance,
  vintageClassic,
  darkElegance,
  floralBotanic,
}

class _Template {
  final _TemplateId id;
  final String name;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final Color primary;
  final Color accent;
  final Color background;
  final Color text;
  final String? patternAsset;
  final bool isPremium;

  const _Template({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.primary,
    required this.accent,
    required this.background,
    required this.text,
    this.patternAsset,
    this.isPremium = false,
  });
}

const List<_Template> _TEMPLATES = [
  _Template(
    id: _TemplateId.royalGold,
    name: 'Royal Gold',
    subtitle: 'Luxe & Prestige',
    icon: Icons.auto_awesome,
    gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
    primary: Color(0xFFB8860B),
    accent: Color(0xFFD4AF37),
    background: Color(0xFFFFFBF5),
    text: Color(0xFF1A1A1A),
    isPremium: true,
  ),
  _Template(
    id: _TemplateId.modernMinimal,
    name: 'Modern Minimal',
    subtitle: 'Épuré & Élégant',
    icon: Icons.grid_view,
    gradient: LinearGradient(colors: [Color(0xFF0B3B8F), Color(0xFF6B46C1)]),
    primary: Color(0xFF0B3B8F),
    accent: Color(0xFF6B46C1),
    background: Colors.white,
    text: Color(0xFF111827),
  ),
  _Template(
    id: _TemplateId.roseRomance,
    name: 'Rose Romance',
    subtitle: 'Douceur & Passion',
    icon: Icons.favorite,
    gradient: LinearGradient(colors: [Color(0xFFE31C4E), Color(0xFFFF6B9D)]),
    primary: Color(0xFFE31C4E),
    accent: Color(0xFFFF6B9D),
    background: Color(0xFFFFF0F5),
    text: Color(0xFF4A0E1F),
  ),
  _Template(
    id: _TemplateId.vintageClassic,
    name: 'Vintage Classic',
    subtitle: 'Rétro & Intemporel',
    icon: Icons.movie_filter,
    gradient: LinearGradient(colors: [Color(0xFF8B7355), Color(0xFF5C4A3A)]),
    primary: Color(0xFF8B7355),
    accent: Color(0xFFD4A373),
    background: Color(0xFFFAF3E7),
    text: Color(0xFF3D2F1F),
  ),
  _Template(
    id: _TemplateId.darkElegance,
    name: 'Dark Elegance',
    subtitle: 'Mystère & Raffinement',
    icon: Icons.nights_stay,
    gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
    primary: Color(0xFFD4AF37),
    accent: Color(0xFFE5E4E2),
    background: Color(0xFF0F0F1E),
    text: Color(0xFFF5F5F5),
    isPremium: true,
  ),
  _Template(
    id: _TemplateId.floralBotanic,
    name: 'Floral Botanic',
    subtitle: 'Nature & Fraîcheur',
    icon: Icons.local_florist,
    gradient: LinearGradient(colors: [Color(0xFF2D5016), Color(0xFF6B8E23)]),
    primary: Color(0xFF2D5016),
    accent: Color(0xFFD4AF37),
    background: Color(0xFFF5F9F0),
    text: Color(0xFF1A2E0A),
  ),
];

_Template _findTemplate(_TemplateId id) =>
    _TEMPLATES.firstWhere((t) => t.id == id);

// ============================================================================
// THÈMES (styles de mise en page)
// ============================================================================
enum _ThemeStyle { centered, elegant, photo, royal }

class _ThemeDef {
  final _ThemeStyle id;
  final String name;
  final IconData icon;
  const _ThemeDef(this.id, this.name, this.icon);
}

const List<_ThemeDef> _THEMES = [
  _ThemeDef(_ThemeStyle.centered, 'Centré', Icons.center_focus_strong),
  _ThemeDef(_ThemeStyle.elegant, 'Élégant', Icons.auto_stories),
  _ThemeDef(_ThemeStyle.photo, 'Photo', Icons.photo_camera),
  _ThemeDef(_ThemeStyle.royal, 'Royal', Icons.workspace_premium),
];

// ============================================================================
// COULEURS D'ACCENT
// ============================================================================
const List<Color> _ACCENT_COLORS = [
  Color(0xFFD4AF37), // Or
  Color(0xFFE31C4E), // Rose
  Color(0xFF0B3B8F), // Bleu royal
  Color(0xFF6B46C1), // Violet
  Color(0xFF059669), // Vert
  Color(0xFFD97706), // Ambre
  Color(0xFFBE185D), // Magenta
  Color(0xFF1A1A1A), // Noir
];

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PreviewInvitationPage extends ConsumerStatefulWidget {
  final String weddingId;
  const PreviewInvitationPage({super.key, required this.weddingId});

  @override
  ConsumerState<PreviewInvitationPage> createState() =>
      _PreviewInvitationPageState();
}

class _PreviewInvitationPageState extends ConsumerState<PreviewInvitationPage>
    with SingleTickerProviderStateMixin {
  _TemplateId _selectedTemplate = _TemplateId.royalGold;
  _ThemeStyle _selectedTheme = _ThemeStyle.centered;
  Color _customAccent = _R.gold;
  bool _showPhoto = false;
  bool _isPublishing = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(weddingInvitationProvider(widget.weddingId));
    final galleryAsync = ref.watch(galleryProvider(widget.weddingId));
    final guestsAsync = ref.watch(guestsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.cream,
      body: weddingAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(weddingInvitationProvider(widget.weddingId)),
        ),
        data: (wedding) {
          final guests = guestsAsync.valueOrNull ?? const [];
          final gallery = galleryAsync.valueOrNull ?? const [];
          final confirmed = guests
              .where((g) => (g.rsvpStatus ?? '').toLowerCase() == 'confirmed' ||
                  (g.rsvpStatus ?? '').toLowerCase() == 'accepted')
              .length;
          final pending = guests.where((g) => (g.rsvpStatus ?? '').isEmpty ||
              (g.rsvpStatus ?? '').toLowerCase() == 'pending').length;

          return FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── APP BAR ROYALE ─────────────────────────────────────
                _RoyalAppBar(
                  wedding: wedding,
                  onEdit: () => context.push(
                      '/thix-weeding/staff/${widget.weddingId}/parametres'),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── STATS RSVP ─────────────────────────────────
                      _RsvpStatsCard(
                        total: guests.length,
                        confirmed: confirmed,
                        pending: pending,
                      ),
                      const SizedBox(height: 16),

                      // ── HERO BANNER ────────────────────────────────
                      _HeroBanner(wedding: wedding),
                      const SizedBox(height: 24),

                      // ── SÉLECTION TEMPLATE ─────────────────────────
                      _SectionHeader(
                        title: 'Choisir un modèle',
                        icon: Icons.palette_outlined,
                        color: _R.gold,
                        subtitle: '6 templates premium disponibles',
                      ),
                      const SizedBox(height: 12),
                      _TemplateSelector(
                        selected: _selectedTemplate,
                        onChanged: (t) => setState(() => _selectedTemplate = t),
                      ),
                      const SizedBox(height: 20),

                      // ── APERÇU INVITATION ──────────────────────────
                      _SectionHeader(
                        title: 'Aperçu',
                        icon: Icons.visibility_outlined,
                        color: _R.blue,
                        actionLabel: 'Plein écran',
                        onAction: () => _showFullScreenPreview(context, wedding),
                      ),
                      const SizedBox(height: 12),
                      _InvitationPreview(
                        wedding: wedding,
                        template: _findTemplate(_selectedTemplate),
                        theme: _selectedTheme,
                        accentColor: _customAccent,
                        coverPhoto: _showPhoto && gallery.isNotEmpty
                            ? gallery.first.imageUrl
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // ── THÈME + COULEURS ───────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _R.card(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personnalisation',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ThemeSelector(
                              selected: _selectedTheme,
                              onChanged: (t) => setState(() => _selectedTheme = t),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Couleur d\'accent',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _R.text2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _ColorPicker(
                              selected: _customAccent,
                              onChanged: (c) => setState(() => _customAccent = c),
                            ),
                            if (gallery.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _PhotoToggle(
                                enabled: _showPhoto,
                                onChanged: (v) => setState(() => _showPhoto = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── LIEN D'INVITATION ──────────────────────────
                      _ShareCard(
                        wedding: wedding,
                        weddingId: widget.weddingId,
                        isPublishing: _isPublishing,
                        onPublish: () => _publish(context, ref),
                        onShare: () => _shareInvitation(context, wedding),
                        onCopy: () => _copyLink(context, wedding),
                      ),
                      const SizedBox(height: 16),

                      // ── QR CODE ────────────────────────────────────
                      _QrCodeCard(
                        wedding: wedding,
                        template: _findTemplate(_selectedTemplate),
                      ),
                      const SizedBox(height: 16),

                      // ── CANAUX DE PARTAGE ──────────────────────────
                      _ShareChannelsCard(
                        wedding: wedding,
                        weddingId: widget.weddingId,
                      ),
                      const SizedBox(height: 16),

                      // ── EXPORT ─────────────────────────────────────
                      _ExportCard(
                        wedding: wedding,
                        template: _findTemplate(_selectedTemplate),
                      ),
                      const SizedBox(height: 16),

                      // ── NOTE INVITÉS UNIQUES ───────────────────────
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
                                'Chaque invité recevra un lien unique avec son Thix ID et un QR Code personnel pour le contrôle d\'accès jour J.',
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
                      const SizedBox(height: 24),

                      // ── BOUTON PRINCIPAL ───────────────────────────
                      _PublishCTA(
                        wedding: wedding,
                        weddingId: widget.weddingId,
                        isPublishing: _isPublishing,
                        onPublish: () => _publish(context, ref),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    setState(() => _isPublishing = true);
    try {
      await Supabase.instance.client
          .from('thix_weeding_weddings')
          .update({'invitation_published': true})
          .eq('id', widget.weddingId);
      ref.invalidate(weddingInvitationProvider(widget.weddingId));
      ref.invalidate(weddingProvider(widget.weddingId));

      if (context.mounted) {
        _showSuccess(context, 'Invitation publiée avec succès ✓');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur: $e');
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _shareInvitation(BuildContext context, WeddingModel wedding) async {
    final url = 'https://thix.id/w/${widget.weddingId}';
    final dateStr = wedding.weddingDate != null ? ' le ${_fmtDate(wedding.weddingDate!)}' : '';
    final venueStr = wedding.venue != null ? ' à ${wedding.venue}' : '';
    final text = 'Vous êtes invités au mariage de ${wedding.brideName} & ${wedding.groomName}$dateStr$venueStr.\n\n$url';
    await Share.share(text, subject: 'Invitation mariage');
  }

  void _copyLink(BuildContext context, WeddingModel wedding) {
    Clipboard.setData(
      ClipboardData(text: 'https://thix.id/w/${widget.weddingId}'),
    );
    _showSuccess(context, 'Lien copié dans le presse-papier ✓');
  }

  void _showFullScreenPreview(BuildContext context, WeddingModel wedding) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPreview(
          wedding: wedding,
          template: _findTemplate(_selectedTemplate),
          theme: _selectedTheme,
          accentColor: _customAccent,
        ),
      ),
    );
  }

  void _showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _RoyalAppBar extends StatelessWidget {
  final WeddingModel wedding;
  final VoidCallback onEdit;

  const _RoyalAppBar({required this.wedding, required this.onEdit});

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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.tune, color: _R.blue, size: 20),
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
                            child: const Icon(Icons.mail_outline,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'INVITATION NUMÉRIQUE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          if (wedding.invitationPublished)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _R.green.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Publiée',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Créez votre invitation',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        wedding.coupleNames.isEmpty
                            ? 'Personnalisez votre invitation unique'
                            : '${wedding.coupleNames} • Design premium',
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
// STATS RSVP
// ============================================================================
class _RsvpStatsCard extends StatelessWidget {
  final int total;
  final int confirmed;
  final int pending;

  const _RsvpStatsCard({
    required this.total,
    required this.confirmed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _R.card(),
      child: Row(
        children: [
          _MiniStat(icon: Icons.people, label: 'Total', value: '$total', color: _R.blue),
          _MiniStat(
              icon: Icons.check_circle, label: 'Confirmés', value: '$confirmed', color: _R.green),
          _MiniStat(
              icon: Icons.hourglass_empty, label: 'En attente', value: '$pending', color: _R.amber),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: _R.text2)),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO BANNER
// ============================================================================
class _HeroBanner extends StatelessWidget {
  final WeddingModel wedding;
  const _HeroBanner({required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _R.gold.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVITATION PREMIUM',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      '6 templates élégants',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                    ),
                ],
              ),
            ),
            if (actionLabel != null)
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 12, color: color),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// SÉLECTEUR DE TEMPLATE
// ============================================================================
class _TemplateSelector extends StatelessWidget {
  final _TemplateId selected;
  final ValueChanged<_TemplateId> onChanged;

  const _TemplateSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _TEMPLATES.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final t = _TEMPLATES[i];
          final isSelected = t.id == selected;
          return GestureDetector(
            onTap: () => onChanged(t.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? t.primary : _R.border,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: t.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Preview mini
                    Container(
                      color: t.background,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: t.gradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(t.icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Sophie',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                          Text(
                            '&',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 12,
                              color: t.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            'Thomas',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Overlay info
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (t.isPremium)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      gradient: _R.goldG,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'PRO',
                                      style: GoogleFonts.inter(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              t.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Badge sélection
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(Icons.check,
                              color: t.primary, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// APERÇU INVITATION
// ============================================================================
class _InvitationPreview extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final _ThemeStyle theme;
  final Color accentColor;
  final String? coverPhoto;

  const _InvitationPreview({
    required this.wedding,
    required this.template,
    required this.theme,
    required this.accentColor,
    this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildTemplate(),
      ),
    );
  }

  Widget _buildTemplate() {
    switch (template.id) {
      case _TemplateId.royalGold:
        return _RoyalGoldTemplate(
          wedding: wedding,
          template: template,
          accent: accentColor,
          coverPhoto: coverPhoto,
        );
      case _TemplateId.modernMinimal:
        return _ModernMinimalTemplate(
          wedding: wedding,
          template: template,
          accent: accentColor,
          coverPhoto: coverPhoto,
        );
      case _TemplateId.roseRomance:
        return _RoseRomanceTemplate(
          wedding: wedding,
          template: template,
          accent: accentColor,
          coverPhoto: coverPhoto,
        );
      case _TemplateId.vintageClassic:
        return _VintageClassicTemplate(
          wedding: wedding,
          template: template,
          accent: accentColor,
          coverPhoto: coverPhoto,
        );
      case _TemplateId.darkElegance:
        return _DarkEleganceTemplate(
          wedding: wedding,
          template: template,
          accent: accentColor,
          coverPhoto: coverPhoto,
        );
      case _TemplateId.floralBotanic:
        return _FloralBotanicTemplate(
          wedding: wedding,
          template: template,
          accent: accentColor,
          coverPhoto: coverPhoto,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE 1 : ROYAL GOLD
// ═══════════════════════════════════════════════════════════════════════════
class _RoyalGoldTemplate extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final Color accent;
  final String? coverPhoto;

  const _RoyalGoldTemplate({
    required this.wedding,
    required this.template,
    required this.accent,
    this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: template.background,
        border: Border.all(color: template.accent.withOpacity(0.4), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Ornament(color: template.primary),
              const SizedBox(width: 8),
              Icon(Icons.auto_awesome, color: template.primary, size: 16),
              const SizedBox(width: 8),
              _Ornament(color: template.primary),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Save the Date',
            style: GoogleFonts.cormorant(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: template.primary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 20),
          if (coverPhoto != null)
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: template.primary, width: 3),
                image: DecorationImage(
                  image: NetworkImage(coverPhoto!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            wedding.brideName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: template.text,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            '&',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              color: accent,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            wedding.groomName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: template.text,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Container(width: 80, height: 1, color: template.primary),
          const SizedBox(height: 20),
          _InfoRowRoyal(
            icon: Icons.calendar_today,
            label: 'DATE',
            value: wedding.weddingDate != null
                ? _fmtDateLong(wedding.weddingDate!)
                : 'À définir',
            color: template.primary,
          ),
          const SizedBox(height: 8),
          _InfoRowRoyal(
            icon: Icons.place,
            label: 'LIEU',
            value: wedding.venue ?? 'À définir',
            color: template.primary,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Ornament(color: template.primary),
              const SizedBox(width: 8),
              Icon(Icons.favorite, color: template.primary, size: 14),
              const SizedBox(width: 8),
              _Ornament(color: template.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ornament extends StatelessWidget {
  final Color color;
  const _Ornament({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, color, Colors.transparent],
        ),
      ),
    );
  }
}

class _InfoRowRoyal extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRowRoyal({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorant(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE 2 : MODERN MINIMAL
// ═══════════════════════════════════════════════════════════════════════════
class _ModernMinimalTemplate extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final Color accent;
  final String? coverPhoto;

  const _ModernMinimalTemplate({
    required this.wedding,
    required this.template,
    required this.accent,
    this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      color: template.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEDDING',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            wedding.brideName,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: template.text,
              height: 1,
            ),
          ),
          Text(
            '&',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w200,
              color: accent,
              height: 1.2,
            ),
          ),
          Text(
            wedding.groomName,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: template.text,
              height: 1,
            ),
          ),
          const SizedBox(height: 32),
          Container(width: 60, height: 3, color: accent),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ModernInfo(
                  label: 'DATE',
                  value: wedding.weddingDate != null
                      ? _fmtDateShort(wedding.weddingDate!)
                      : '—',
                  accent: accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ModernInfo(
                  label: 'LIEU',
                  value: wedding.venue ?? '—',
                  accent: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _ModernInfo({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: accent,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE 3 : ROSE ROMANCE
// ═══════════════════════════════════════════════════════════════════════════
class _RoseRomanceTemplate extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final Color accent;
  final String? coverPhoto;

  const _RoseRomanceTemplate({
    required this.wedding,
    required this.template,
    required this.accent,
    this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            template.background,
            template.background,
            template.primary.withOpacity(0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.favorite, color: template.primary, size: 32),
          const SizedBox(height: 16),
          Text(
            'Vous êtes invités au mariage de',
            style: GoogleFonts.cormorant(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: template.primary,
            ),
          ),
          const SizedBox(height: 20),
          if (coverPhoto != null)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: template.primary.withOpacity(0.3), width: 3),
                image: DecorationImage(
                  image: NetworkImage(coverPhoto!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            wedding.brideName,
            style: GoogleFonts.dancingScript(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: template.primary,
            ),
          ),
          Text(
            '❤',
            style: GoogleFonts.dancingScript(
              fontSize: 20,
              color: accent,
            ),
          ),
          Text(
            wedding.groomName,
            style: GoogleFonts.dancingScript(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: template.primary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: template.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  wedding.weddingDate != null
                      ? _fmtDateLong(wedding.weddingDate!)
                      : 'À définir',
                  style: GoogleFonts.cormorant(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: template.primary,
                  ),
                ),
                if (wedding.venue != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    wedding.venue!,
                    style: GoogleFonts.cormorant(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: template.primary.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE 4 : VINTAGE CLASSIC
// ═══════════════════════════════════════════════════════════════════════════
class _VintageClassicTemplate extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final Color accent;
  final String? coverPhoto;

  const _VintageClassicTemplate({
    required this.wedding,
    required this.template,
    required this.accent,
    this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: template.background,
        border: Border.all(color: template.primary.withOpacity(0.3), width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: template.primary.withOpacity(0.2)),
              ),
            ),
          ),
          Column(
            children: [
              Text(
                '✦ MARIAGE ✦',
                style: GoogleFonts.cormorant(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: template.primary,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                wedding.brideName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: template.text,
                ),
              ),
              Text(
                '&',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: accent,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                wedding.groomName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: template.text,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 60,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      template.primary,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                wedding.weddingDate != null
                    ? _fmtDateLong(wedding.weddingDate!)
                    : 'À définir',
                style: GoogleFonts.cormorant(
                  fontSize: 13,
                  color: template.primary,
                  letterSpacing: 2,
                ),
              ),
              if (wedding.venue != null) ...[
                const SizedBox(height: 8),
                Text(
                  wedding.venue!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorant(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: template.primary.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE 5 : DARK ELEGANCE
// ═══════════════════════════════════════════════════════════════════════════
class _DarkEleganceTemplate extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final Color accent;
  final String? coverPhoto;

  const _DarkEleganceTemplate({
    required this.wedding,
    required this.template,
    required this.accent,
    this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [template.background, const Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            'THE WEDDING OF',
            style: GoogleFonts.cormorant(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: template.primary,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 24),
          if (coverPhoto != null)
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: template.primary, width: 2),
                image: DecorationImage(
                  image: NetworkImage(coverPhoto!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            wedding.brideName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: template.text,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            'et',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              color: template.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            wedding.groomName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: template.text,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Container(width: 60, height: 1, color: template.primary),
          const SizedBox(height: 20),
          Text(
            wedding.weddingDate != null
                ? _fmtDateLong(wedding.weddingDate!)
                : 'À définir',
            style: GoogleFonts.cormorant(
              fontSize: 13,
              color: template.accent,
              letterSpacing: 2,
            ),
          ),
          if (wedding.venue != null) ...[
            const SizedBox(height: 6),
            Text(
              wedding.venue!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorant(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: template.accent.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE 6 : FLORAL BOTANIC
// ═══════════════════════════════════════════════════════════════════════════
class _FloralBotanicTemplate extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final Color accent;
  final String? coverPhoto;

  const _FloralBotanicTemplate({
    required this.wedding,
    required this.template,
    required this.accent,
    this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: template.background),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_florist, color: template.primary, size: 20),
              const SizedBox(width: 6),
              Icon(Icons.eco, color: template.primary.withOpacity(0.6), size: 16),
              const SizedBox(width: 6),
              Icon(Icons.local_florist, color: template.primary, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ensemble pour la vie',
            style: GoogleFonts.cormorant(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: template.primary,
            ),
          ),
          const SizedBox(height: 20),
          if (coverPhoto != null)
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: template.primary.withOpacity(0.3), width: 2),
                image: DecorationImage(
                  image: NetworkImage(coverPhoto!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            wedding.brideName,
            style: GoogleFonts.dancingScript(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: template.primary,
            ),
          ),
          Text(
            '♡',
            style: GoogleFonts.dancingScript(
              fontSize: 18,
              color: accent,
            ),
          ),
          Text(
            wedding.groomName,
            style: GoogleFonts.dancingScript(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: template.primary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: template.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.calendar_today, size: 14, color: template.primary),
                const SizedBox(height: 4),
                Text(
                  wedding.weddingDate != null
                      ? _fmtDateLong(wedding.weddingDate!)
                      : 'À définir',
                  style: GoogleFonts.cormorant(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: template.primary,
                  ),
                ),
                if (wedding.venue != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.place, size: 12, color: template.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          wedding.venue!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cormorant(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: template.primary.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Icon(Icons.eco, color: template.primary.withOpacity(0.6), size: 16),
        ],
      ),
    );
  }
}

// ============================================================================
// THÈME SELECTOR
// ============================================================================
class _ThemeSelector extends StatelessWidget {
  final _ThemeStyle selected;
  final ValueChanged<_ThemeStyle> onChanged;

  const _ThemeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _THEMES.map((t) {
        final isSelected = t.id == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: isSelected ? _R.blue : Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onChanged(t.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? _R.blue : _R.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 16,
                          color: isSelected ? Colors.white : _R.blue),
                      const SizedBox(height: 3),
                      Text(
                        t.name,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : _R.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// COLOR PICKER
// ============================================================================
class _ColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;

  const _ColorPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _ACCENT_COLORS.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: c.withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// PHOTO TOGGLE
// ============================================================================
class _PhotoToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PhotoToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: enabled ? _R.green.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? _R.green : _R.border,
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Afficher photo du couple',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: enabled ? _R.green : _R.text,
          ),
        ),
        subtitle: Text(
          'Depuis votre galerie',
          style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled ? _R.green.withOpacity(0.15) : _R.border.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.photo_camera, size: 18, color: enabled ? _R.green : _R.text2),
        ),
        value: enabled,
        activeColor: _R.green,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

// ============================================================================
// SHARE CARD
// ============================================================================
class _ShareCard extends StatelessWidget {
  final WeddingModel wedding;
  final String weddingId;
  final bool isPublishing;
  final VoidCallback onPublish;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  const _ShareCard({
    required this.wedding,
    required this.weddingId,
    required this.isPublishing,
    required this.onPublish,
    required this.onShare,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final url = 'https://thix.id/w/$weddingId';
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
                decoration: const BoxDecoration(
                  gradient: _R.royal,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(Icons.link, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Lien d\'invitation public',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _R.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _R.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 14, color: _R.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    url,
                    style: _mono(
                      fontSize: 12,
                      color: _R.blue,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _R.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.copy, size: 14, color: _R.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: wedding.invitationPublished ? _R.greenG : _R.royal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (wedding.invitationPublished ? _R.green : _R.blue)
                            .withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isPublishing ? null : onPublish,
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: isPublishing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    wedding.invitationPublished
                                        ? Icons.check_circle
                                        : Icons.public,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    wedding.invitationPublished
                                        ? 'Publiée'
                                        : 'Publier',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Partager'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _R.blue,
                    side: const BorderSide(color: _R.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QR CODE CARD
// ============================================================================
class _QrCodeCard extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;

  const _QrCodeCard({required this.wedding, required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: template.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: template.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2, size: 52, color: Color(0xFF0B3B8F)),
                const SizedBox(height: 4),
                Text(
                  'UNIQUE',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: template.primary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fingerprint, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'QR CODES UNIQUES',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Chaque invité recevra son propre QR code',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pour contrôle d\'accès sécurisé jour J',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Code: ${wedding.uniqueCode}',
                    style: _mono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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

// ============================================================================
// SHARE CHANNELS
// ============================================================================
class _ShareChannelsCard extends StatelessWidget {
  final WeddingModel wedding;
  final String weddingId;

  const _ShareChannelsCard({
    required this.wedding,
    required this.weddingId,
  });

  @override
  Widget build(BuildContext context) {
    final url = 'https://thix.id/w/$weddingId';
    final dateStr = wedding.weddingDate != null ? ' le ${_fmtDate(wedding.weddingDate!)}' : '';
    final venueStr = wedding.venue != null ? ' à ${wedding.venue}' : '';
    final text = 'Vous êtes invités au mariage de ${wedding.brideName} & ${wedding.groomName}$dateStr$venueStr.\n\n$url';

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
                decoration: const BoxDecoration(
                  gradient: _R.goldG,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Canaux de partage',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShareChip(
                  label: 'WhatsApp',
                  icon: Icons.message,
                  color: const Color(0xFF25D366),
                  onTap: () async {
                    await Share.share(text);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShareChip(
                  label: 'SMS',
                  icon: Icons.sms,
                  color: _R.blue,
                  onTap: () async {
                    await Share.share(text);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShareChip(
                  label: 'Email',
                  icon: Icons.email,
                  color: _R.purple,
                  onTap: () async {
                    await Share.share(text, subject: 'Invitation mariage');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShareChip(
                  label: 'Plus',
                  icon: Icons.more_horiz,
                  color: _R.text2,
                  onTap: () async {
                    await Share.share(text, subject: 'Invitation mariage');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ShareChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
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
// EXPORT CARD
// ============================================================================
class _ExportCard extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;

  const _ExportCard({required this.wedding, required this.template});

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
                decoration: const BoxDecoration(
                  gradient: _R.greenG,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(Icons.file_download_outlined, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Exporter l\'invitation',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ExportTile(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf,
                  color: _R.rose,
                  onTap: () => _showExportSuccess(context, 'PDF généré'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExportTile(
                  label: 'Image',
                  icon: Icons.image_outlined,
                  color: _R.blue,
                  onTap: () => _showExportSuccess(context, 'Image exportée'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExportTile(
                  label: 'Imprimer',
                  icon: Icons.print_outlined,
                  color: _R.purple,
                  onTap: () => _showExportSuccess(context, 'Impression lancée'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExportSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ],
      ),
      backgroundColor: _R.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

class _ExportTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExportTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
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
// PUBLISH CTA
// ============================================================================
class _PublishCTA extends StatelessWidget {
  final WeddingModel wedding;
  final String weddingId;
  final bool isPublishing;
  final VoidCallback onPublish;

  const _PublishCTA({
    required this.wedding,
    required this.weddingId,
    required this.isPublishing,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: wedding.invitationPublished ? _R.greenG : _R.goldG,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (wedding.invitationPublished ? _R.green : _R.gold).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isPublishing ? null : onPublish,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isPublishing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        wedding.invitationPublished ? Icons.check_circle : Icons.public,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        wedding.invitationPublished ? 'Invitation publiée' : 'Publier l\'invitation',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

// ============================================================================
// FULL SCREEN PREVIEW
// ============================================================================
class _FullScreenPreview extends StatelessWidget {
  final WeddingModel wedding;
  final _Template template;
  final _ThemeStyle theme;
  final Color accentColor;

  const _FullScreenPreview({
    required this.wedding,
    required this.template,
    required this.theme,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: template.background,
        foregroundColor: template.text,
        title: Text(
          template.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: template.text),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _InvitationPreview(
          wedding: wedding,
          template: template,
          theme: theme,
          accentColor: accentColor,
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
      backgroundColor: _R.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.mail_outline, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2),
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
      backgroundColor: _R.cream,
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
                child: const Icon(Icons.error_outline, color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
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
// UTILITAIRES DE FORMATAGE
// ============================================================================
String _fmtDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

String _fmtDateLong(DateTime dt) {
  const months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _fmtDateShort(DateTime dt) {
  const months = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Jun',
    'Jul',
    'Aoû',
    'Sep',
    'Oct',
    'Nov',
    'Déc'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
