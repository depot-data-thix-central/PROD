// lib/presentation/thix_weeding/pages/staff/parametres/settings_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — SETTINGS (PRODUCTION v2)
// ✅ Code d'accès THIX-W-JJMM-XXXYY intégré
// ✅ Labels harmonisés avec la home page
// ✅ _mono() helper pour tous les textes monospace
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ============================================================================
// HELPER MONOSPACE (compatible Web/WASM)
// ============================================================================
const TextStyle _monoStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
  letterSpacing: 0.5,
);

TextStyle _mono({double? fontSize, FontWeight? fontWeight, Color? color, double? letterSpacing}) {
  return _monoStyle.copyWith(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      );
}

// ============================================================================
// PROVIDER LOCAL
// ============================================================================
final settingsProvider = FutureProvider.family<WeddingModel, String>((ref, weddingId) async {
  final data = await Supabase.instance.client
      .from('thix_weeding_weddings')
      .select()
      .eq('id', weddingId)
      .single();
  return WeddingModel.fromJson(data);
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class SettingsPage extends ConsumerWidget {
  final String weddingId;
  const SettingsPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsProvider(weddingId));

    return Scaffold(
      backgroundColor: _R.cream,
      body: async.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(settingsProvider(weddingId)),
        ),
        data: (wedding) => _SettingsContent(
          weddingId: weddingId,
          wedding: wedding,
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _SettingsContent extends StatelessWidget {
  final String weddingId;
  final WeddingModel wedding;

  const _SettingsContent({required this.weddingId, required this.wedding});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _SettingsAppBar(wedding: wedding),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _WeddingHeroCard(wedding: wedding),
              const SizedBox(height: 20),

              // ── CONFIGURATION ──────────────────────────────────────
              _SectionHeader(title: 'Configuration', icon: Icons.tune, color: _R.blue),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.edit_outlined,
                title: 'Informations mariage',
                subtitle: 'Noms, date, lieu de réception',
                color: _R.blue,
                onTap: () => context.push('/thix-weeding/staff/$weddingId/parametres/infos'),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.mail_outline,
                title: 'Invitation numérique',
                subtitle: 'Aperçu, templates et publication',
                color: _R.purple,
                onTap: () => context.push('/thix-weeding/staff/$weddingId/invitation/preview'),
              ),
              const SizedBox(height: 20),

              // ── ACCÈS & PARTAGE ────────────────────────────────────
              _SectionHeader(title: 'Accès & Partage', icon: Icons.share_outlined, color: _R.gold),
              const SizedBox(height: 12),
              // ✅ MIS À JOUR : Titre et description harmonisés avec le nouveau format
              _CodeAccessCard(uniqueCode: wedding.uniqueCode, weddingId: weddingId),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.qr_code_2,
                title: 'QR Code événement',
                subtitle: 'Afficher le QR code de l\'événement',
                color: _R.green,
                onTap: () => _showQrCode(context, wedding),
              ),
              const SizedBox(height: 20),

              // ── DONNÉES ────────────────────────────────────────────
              _SectionHeader(title: 'Données', icon: Icons.storage_outlined, color: _R.text2),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Exporter les données',
                subtitle: 'PDF, Excel ou CSV',
                color: _R.blue,
                onTap: () => _showExportSheet(context),
              ),
              const SizedBox(height: 20),

              // ── ZONE DE DANGER ─────────────────────────────────────
              _SectionHeader(title: 'Zone de danger', icon: Icons.warning_amber_outlined, color: _R.rose),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Supprimer le mariage',
                subtitle: 'Action irréversible — toutes les données perdues',
                color: _R.rose,
                isDestructive: true,
                onTap: () => _confirmDelete(context, weddingId, wedding.coupleNames),
              ),
              const SizedBox(height: 24),

              // ── FOOTER ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_R.blue.withOpacity(0.06), _R.purple.withOpacity(0.06)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _R.blue.withOpacity(0.15)),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.verified_user_outlined, size: 14, color: _R.blue),
                    const SizedBox(width: 6),
                    Text('Données 100% Supabase • IDs UUID uniques',
                        style: GoogleFonts.inter(fontSize: 10, color: _R.blue, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Text('THIX WEDDING & EVENTS v2.15.0',
                      style: GoogleFonts.inter(fontSize: 9, color: _R.text2)),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _showQrCode(BuildContext context, WeddingModel wedding) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.qr_code_2, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            // ✅ MIS À JOUR : Label cohérent avec le nouveau format
            Text('QR Code Événement', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(wedding.coupleNames.isEmpty ? 'Mon Mariage' : wedding.coupleNames,
                style: GoogleFonts.inter(fontSize: 13, color: _R.text2)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _R.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _R.border)),
              child: const Icon(Icons.qr_code_2, size: 160, color: _R.blue),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _R.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _R.gold.withOpacity(0.3)),
              ),
              child: Text(
                'Code: ${wedding.uniqueCode}',
                style: _mono(fontSize: 13, fontWeight: FontWeight.w700, color: _R.goldDark, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 8),
            // ✅ AJOUTÉ : Format expliqué sous le code
            Text(
              'Format: THIX-W-JJMM-XXXYY',
              style: GoogleFonts.inter(fontSize: 10, color: _R.text2, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: _R.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Fermer'),
            ),
          ]),
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Exporter les données', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _ExportOption(icon: Icons.picture_as_pdf, label: 'Rapport PDF', subtitle: 'Document complet prêt à imprimer', color: _R.rose, onTap: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          _ExportOption(icon: Icons.table_chart, label: 'Excel (.xlsx)', subtitle: 'Pour analyse et tri personnalisé', color: _R.green, onTap: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          _ExportOption(icon: Icons.description_outlined, label: 'CSV', subtitle: 'Format universel compatible', color: _R.blue, onTap: () => Navigator.pop(context)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String weddingId, String coupleNames) async {
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(gradient: _R.roseG, shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text('Supprimer définitivement ?', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _R.rose))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Toutes les données suivantes seront irrémédiablement supprimées :', style: GoogleFonts.inter(fontSize: 13, color: _R.text2)),
          const SizedBox(height: 10),
          _DeleteItem(label: 'Invités et RSVP'),
          _DeleteItem(label: 'Prestataires et contrats'),
          _DeleteItem(label: 'Budget et dépenses'),
          _DeleteItem(label: 'Galerie photos/vidéos'),
          _DeleteItem(label: 'Livre d\'or et messages'),
          _DeleteItem(label: 'Planning et checklist'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _R.rose.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: _R.rose.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('⚠️ Tapez "SUPPRIMER" pour confirmer', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _R.rose)),
              const SizedBox(height: 6),
              TextField(
                controller: confirmCtrl,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'SUPPRIMER',
                  hintStyle: GoogleFonts.inter(color: _R.rose.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _R.rose.withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _R.rose, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Annuler', style: GoogleFonts.inter(color: _R.text2))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _R.rose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (confirmCtrl.text.trim().toUpperCase() == 'SUPPRIMER') {
                Navigator.pop(dialogDialogContext, true);
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: const Text('Veuillez taper "SUPPRIMER" pour confirmer'), backgroundColor: _R.amber, behavior: SnackBarBehavior.floating));
              }
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    confirmCtrl.dispose();
    if (ok != true) return;

    try {
      await Supabase.instance.client.from('thix_weeding_weddings').delete().eq('id', weddingId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Mariage supprimé avec succès'),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        context.go('/thix-weeding');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression: $e'), backgroundColor: _R.rose, behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _SettingsAppBar extends StatelessWidget {
  final WeddingModel wedding;
  const _SettingsAppBar({required this.wedding});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.royal,
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
        child: Stack(children: [
          Positioned(right: -60, top: -60, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
          Positioned(right: 30, bottom: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: _R.gold.withOpacity(0.15)))),
          FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.settings_outlined, color: Colors.white, size: 16)),
                    const SizedBox(width: 8),
                    Text('PARAMÈTRES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 2)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Configuration du mariage', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// WEDDING HERO CARD
// ============================================================================
class _WeddingHeroCard extends StatelessWidget {
  final WeddingModel wedding;
  const _WeddingHeroCard({required this.wedding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _R.gold.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.favorite, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              wedding.coupleNames.isEmpty ? 'Mon Mariage' : wedding.coupleNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 4),
            Text(
              [if (wedding.venue != null && wedding.venue!.isNotEmpty) wedding.venue!, if (wedding.weddingDate != null) _fmtDate(wedding.weddingDate!)].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(
                'ID: ${wedding.id.substring(0, 8)}',
                style: _mono(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================================
// CODE ACCESS CARD — ✅ MIS À JOUR : Nouveau format + labels harmonisés
// ============================================================================
class _CodeAccessCard extends StatelessWidget {
  final String uniqueCode;
  final String weddingId;

  const _CodeAccessCard({required this.uniqueCode, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: _R.goldG, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.key_outlined, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ✅ MIS À JOUR : Titre harmonisé avec la home page
            Text('Code d\'accès au mariage', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            // ✅ MIS À JOUR : Description clarifiée pour les invités
            Text('Partagez ce code avec vos invités pour rejoindre l\'événement', style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
          ])),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_R.gold.withOpacity(0.08), _R.goldDark.withOpacity(0.08)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _R.gold.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.fingerprint, size: 20, color: _R.goldDark),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                uniqueCode.isNotEmpty ? uniqueCode : 'Non généré',
                style: _mono(fontSize: 18, fontWeight: FontWeight.w800, color: _R.goldDark, letterSpacing: 1.5),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: uniqueCode));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    // ✅ MIS À JOUR : Message cohérent avec le nouveau label
                    content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 16), const SizedBox(width: 8), const Text('Code d\'accès copié ✓')]),
                    backgroundColor: _R.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _R.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.copy, size: 18, color: _R.goldDark),
                ),
              ),
            ),
          ]),
        ),
        // ✅ AJOUTÉ : Indication du format sous la carte
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 12, color: _R.text2),
          const SizedBox(width: 6),
          Text(
            'Format: THIX-W-JJMM-XXXYY',
            style: GoogleFonts.inter(fontSize: 10, color: _R.text2, fontWeight: FontWeight.w500),
          ),
        ]),
      ]),
    );
  }
}

// ============================================================================
// SETTINGS TILE
// ============================================================================
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDestructive ? _R.rose.withOpacity(0.3) : _R.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDestructive ? _R.rose.withOpacity(0.1) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: isDestructive ? _R.rose : color),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDestructive ? _R.rose : _R.text)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
            ])),
            Icon(Icons.chevron_right, size: 20, color: isDestructive ? _R.rose.withOpacity(0.5) : _R.text2),
          ]),
        ),
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
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: Colors.white, size: 14)),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}

// ============================================================================
// EXPORT OPTION
// ============================================================================
class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ExportOption({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
            ])),
            const Icon(Icons.chevron_right, color: _R.text2),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// DELETE ITEM
// ============================================================================
class _DeleteItem extends StatelessWidget {
  final String label;
  const _DeleteItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        const Icon(Icons.remove_circle_outline, size: 14, color: _R.rose),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
      ]),
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
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle), child: const Icon(Icons.settings_outlined, color: Colors.white, size: 36)),
        const SizedBox(height: 16),
        Text('Chargement...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
      ])),
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
      body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _R.rose.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: _R.rose, size: 40)),
        const SizedBox(height: 16),
        Text('Impossible de charger', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: FilledButton.styleFrom(backgroundColor: _R.blue)),
      ]))),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtDate(DateTime dt) {
  const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
