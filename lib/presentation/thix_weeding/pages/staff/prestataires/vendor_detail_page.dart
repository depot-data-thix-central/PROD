// lib/presentation/thix_weeding/pages/staff/prestataires/vendor_detail_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — VENDOR DETAIL (PRODUCTION v3)
// ✅ Mode CATALOGUE : bandeau code THIX-P + réponse prestataire + TIMELINE de
//    suivi des étapes (contacté → devis → réservé → payé → terminé)
// ✅ Mode MANUEL : comportement d'origine conservé
// ✅ Design royal + Dépenses liées + Actions rapides + Statuts + Suppression
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// PROVIDERS LOCAUX
// ============================================================================
final vendorDetailProvider =
    FutureProvider.family<VendorModel, String>((ref, vendorId) async {
  return await ref.read(vendorServiceProvider).getById(vendorId);
});

final vendorExpensesProvider =
    FutureProvider.family<List<ExpenseModel>, String>((ref, vendorId) async {
  try {
    final res = await Supabase.instance.client
        .from('thix_weeding_expenses')
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res)
        .map((e) => ExpenseModel.fromJson(e))
        .toList();
  } catch (_) {
    return [];
  }
});

/// ✅ NOUVEAU : la DEMANDE de prestation liée à ce vendor (mode catalogue)
/// Retourne null si le vendor a été créé manuellement.
final vendorRequestProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, vendorId) async {
  try {
    final res = await Supabase.instance.client
        .from('thix_weeding_vendor_requests')
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  } catch (_) {
    return null;
  }
});

/// ✅ NOUVEAU : infos du prestataire THIX (pour le bandeau code THIX-P)
final thixProviderInfoProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, providerId) async {
  try {
    final res = await Supabase.instance.client
        .from('thix_weeding_providers')
        .select('id, unique_code, business_name, city, category, verification_status, level, phone, email')
        .eq('id', providerId)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  } catch (_) {
    return null;
  }
});

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
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// ============================================================================
// CATÉGORIES (mêmes définitions que add_vendor_page)
// ============================================================================
const Map<String, _CatDef> _CAT_MAP = {
  'organisateur': _CatDef('Organisateur', Icons.celebration, Color(0xFF6B46C1)),
  'decorateur': _CatDef('Décorateur', Icons.auto_awesome, Color(0xFFFF6B9D)),
  'photographe': _CatDef('Photographe', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  'videaste': _CatDef('Vidéaste', Icons.videocam_outlined, Color(0xFFDB2777)),
  'traiteur': _CatDef('Traiteur', Icons.restaurant, Color(0xFFD97706)),
  'patissier': _CatDef('Pâtissier', Icons.cake_outlined, Color(0xFFBE185D)),
  'maquilleur': _CatDef('Maquilleur', Icons.auto_fix_high, Color(0xFFEC4899)),
  'coiffeur': _CatDef('Coiffeur', Icons.content_cut, Color(0xFF8B5CF6)),
  'couturier': _CatDef('Couturier', Icons.checkroom, Color(0xFF0891B2)),
  'dj': _CatDef('DJ / Orchestre', Icons.music_note, Color(0xFF7C3AED)),
  'vehicule': _CatDef('Loueur véhicules', Icons.directions_car, Color(0xFF4338CA)),
  'salle': _CatDef('Salle réception', Icons.place_outlined, Color(0xFF0B3B8F)),
  'fleuriste': _CatDef('Fleuriste', Icons.local_florist, Color(0xFF059669)),
  'securite': _CatDef('Sécurité', Icons.shield_outlined, Color(0xFF64748B)),
  'materiel': _CatDef('Matériel', Icons.inventory_2_outlined, Color(0xFF78716C)),
};

class _CatDef {
  final String label;
  final IconData icon;
  final Color color;
  const _CatDef(this.label, this.icon, this.color);
}

_CatDef _getCat(String? key) {
  if (key == null || key.isEmpty) return _CatDef('Autre', Icons.store_outlined, _R.text2);
  for (final entry in _CAT_MAP.entries) {
    if (entry.key == key.toLowerCase() ||
        entry.value.label.toLowerCase() == key.toLowerCase()) {
      return entry.value;
    }
  }
  return _CatDef(key, Icons.store_outlined, _R.blue);
}

// ============================================================================
// STATUTS (étendus avec requested + completed pour le flux catalogue)
// ============================================================================
const Map<String, _StatusDef> _STATUS_MAP = {
  'requested': _StatusDef('Demande envoyée', Icons.send_outlined, Color(0xFF6B7280)),
  'pending': _StatusDef('En attente', Icons.hourglass_empty, Color(0xFF6B7280)),
  'contacted': _StatusDef('Contacté', Icons.phone_callback, Color(0xFF0B3B8F)),
  'devis_envoye': _StatusDef('Devis envoyé', Icons.description_outlined, Color(0xFF6B46C1)),
  'booked': _StatusDef('Réservé', Icons.event_available, Color(0xFF059669)),
  'paid': _StatusDef('Payé', Icons.payments, Color(0xFFD4AF37)),
  'completed': _StatusDef('Terminé', Icons.task_alt, Color(0xFF059669)),
  'cancelled': _StatusDef('Annulé', Icons.cancel_outlined, Color(0xFFE31C4E)),
};

class _StatusDef {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusDef(this.label, this.icon, this.color);
}

_StatusDef _getStatus(String? key) {
  if (key == null) return _STATUS_MAP['pending']!;
  return _STATUS_MAP[key] ?? _StatusDef(key, Icons.info_outline, _R.text2);
}

// ============================================================================
// ✅ NOUVEAU : TIMELINE DES ÉTAPES (post-approbation)
// ============================================================================
class _StageDef {
  final String key;
  final String label;
  final String hint;
  final IconData icon;
  const _StageDef(this.key, this.label, this.hint, this.icon);
}

const List<_StageDef> _STAGES = [
  _StageDef('requested', 'Demande envoyée', 'En attente de la réponse du prestataire', Icons.send_outlined),
  _StageDef('contacted', 'Contacté', 'Premier échange établi avec le prestataire', Icons.phone_callback),
  _StageDef('devis_envoye', 'Devis reçu', 'Le prestataire a transmis son devis / conditions', Icons.description_outlined),
  _StageDef('booked', 'Réservé', 'Prestation confirmée et bloquée pour l\'événement', Icons.event_available),
  _StageDef('paid', 'Payé', 'Acompte ou solde réglé', Icons.payments),
  _StageDef('completed', 'Terminé', 'Prestation réalisée', Icons.task_alt),
];

int _stageIndex(String key) =>
    _STAGES.indexWhere((s) => s.key == key);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class VendorDetailPage extends ConsumerWidget {
  final String weddingId;
  final String vendorId;

  const VendorDetailPage({
    super.key,
    required this.weddingId,
    required this.vendorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(vendorDetailProvider(vendorId));
    final expensesAsync = ref.watch(vendorExpensesProvider(vendorId));
    final requestAsync = ref.watch(vendorRequestProvider(vendorId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: vendorAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(vendorDetailProvider(vendorId)),
        ),
        data: (vendor) {
          final request = requestAsync.valueOrNull;
          // Si la demande existe, charger les infos prestataire THIX
          AsyncValue<Map<String, dynamic>?> providerAsync = const AsyncValue.data(null);
          if (request != null && request['provider_id'] != null) {
            providerAsync =
                ref.watch(thixProviderInfoProvider(request['provider_id'] as String));
          }

          return _VendorContent(
            weddingId: weddingId,
            vendor: vendor,
            expensesAsync: expensesAsync,
            request: request,
            providerInfo: providerAsync.valueOrNull,
            onRefresh: () {
              ref.invalidate(vendorDetailProvider(vendorId));
              ref.invalidate(vendorExpensesProvider(vendorId));
              ref.invalidate(vendorRequestProvider(vendorId));
              if (request != null && request['provider_id'] != null) {
                ref.invalidate(thixProviderInfoProvider(request['provider_id'] as String));
              }
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _VendorContent extends StatelessWidget {
  final String weddingId;
  final VendorModel vendor;
  final AsyncValue<List<ExpenseModel>> expensesAsync;
  final Map<String, dynamic>? request;
  final Map<String, dynamic>? providerInfo;
  final VoidCallback onRefresh;

  const _VendorContent({
    required this.weddingId,
    required this.vendor,
    required this.expensesAsync,
    required this.request,
    required this.providerInfo,
    required this.onRefresh,
  });

  bool get _isFromCatalog => request != null;

  @override
  Widget build(BuildContext context) {
    final cat = _getCat(vendor.category);
    final status = _getStatus(vendor.status);

    final expenses = expensesAsync.valueOrNull ?? [];
    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);
    final paidAmount =
        expenses.where((e) => e.isPaid).fold<double>(0, (s, e) => s + e.amount);
    final unpaidAmount = totalSpent - paidAmount;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _VendorAppBar(
          vendor: vendor,
          cat: cat,
          status: status,
          weddingId: weddingId,
          isCatalog: _isFromCatalog,
          onDelete: () => _confirmDelete(context, weddingId, vendor.id),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── HERO CARD ──────────────────────────────────────────
              _HeroCard(vendor: vendor, cat: cat, status: status),
              const SizedBox(height: 16),

              // ── ✅ BANDEAU PRESTATAIRE THIX (mode catalogue) ───────
              if (_isFromCatalog && providerInfo != null) ...[
                _ThixProviderBanner(
                  providerInfo: providerInfo!,
                  request: request!,
                ),
                const SizedBox(height: 16),
              ],

              // ── ✅ TIMELINE DE SUIVI (mode catalogue) ──────────────
              if (_isFromCatalog) ...[
                _RequestTimeline(
                  request: request!,
                  vendorId: vendor.id,
                  onRefresh: onRefresh,
                ),
                const SizedBox(height: 16),
              ],

              // ── ACTIONS RAPIDES ────────────────────────────────────
              _QuickActions(
                vendor: vendor,
                weddingId: weddingId,
                vendorId: vendor.id,
                providerId: _isFromCatalog ? request!['provider_id'] as String? : null,
                onRefresh: onRefresh,
              ),
              const SizedBox(height: 16),

              // ── INFORMATIONS CONTACT ───────────────────────────────
              _ContactSection(vendor: vendor),
              const SizedBox(height: 16),

              // ── CONTRAT & PRIX ─────────────────────────────────────
              _ContractSection(vendor: vendor),
              const SizedBox(height: 16),

              // ── NOTES ──────────────────────────────────────────────
              if (vendor.notes != null && vendor.notes!.isNotEmpty) ...[
                _NotesSection(notes: vendor.notes!),
                const SizedBox(height: 16),
              ],

              // ── PACKAGES ───────────────────────────────────────────
              if (vendor.packages.isNotEmpty) ...[
                _PackagesSection(packages: vendor.packages),
                const SizedBox(height: 16),
              ],

              // ── DÉPENSES LIÉES ─────────────────────────────────────
              _ExpensesSection(
                expensesAsync: expensesAsync,
                totalSpent: totalSpent,
                paidAmount: paidAmount,
                unpaidAmount: unpaidAmount,
              ),
              const SizedBox(height: 16),

              // ── MÉTADONNÉES ────────────────────────────────────────
              _MetaCard(vendor: vendor, isCatalog: _isFromCatalog),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String weddingId, String vendorId) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                    gradient: _R.roseG, shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'Supprimer ce prestataire ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Cette action est irréversible. Toutes les dépenses liées seront aussi supprimées.',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.inter(fontSize: 13, color: _R.text2),
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
      ),
    );
    if (ok != true) return;

    try {
      await Supabase.instance.client
          .from('thix_weeding_vendors')
          .delete()
          .eq('id', vendorId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _R.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ============================================================================
// ✅ BANDEAU PRESTATAIRE THIX (code THIX-P + vérification + réponse)
// ============================================================================
class _ThixProviderBanner extends StatelessWidget {
  final Map<String, dynamic> providerInfo;
  final Map<String, dynamic> request;
  const _ThixProviderBanner(
      {required this.providerInfo, required this.request});

  @override
  Widget build(BuildContext context) {
    final code = providerInfo['unique_code'] as String? ?? '';
    final name = providerInfo['business_name'] as String? ?? '';
    final city = providerInfo['city'] as String? ?? 'RDC';
    final verified = providerInfo['verification_status'] == 'verified';
    final reqStatus = request['status'] as String? ?? 'pending';
    final response = request['provider_response'] as String?;
    final respondedAt = request['responded_at'] as String?;

    Color accent;
    IconData statusIcon;
    String statusLabel;
    if (reqStatus == 'approved') {
      accent = _R.green;
      statusIcon = Icons.check_circle;
      statusLabel = 'Demande acceptée';
    } else if (reqStatus == 'rejected') {
      accent = _R.rose;
      statusIcon = Icons.cancel;
      statusLabel = 'Demande refusée';
    } else {
      accent = _R.amber;
      statusIcon = Icons.hourglass_top;
      statusLabel = 'En attente de réponse';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.10), accent.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent, accent.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRESTATAIRE THIX',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _R.text),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 15, color: _R.green),
                        ],
                      ],
                    ),
                    Text(
                      '$city · Code $code',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _R.text2, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Copier le code
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Code $code copié ✓'),
                      backgroundColor: _R.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _R.border),
                    ),
                    child: const Icon(Icons.copy, size: 16, color: _R.text2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Statut de la demande
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 15, color: accent),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w800, color: accent),
                ),
              ],
            ),
          ),

          // Réponse du prestataire
          if (response != null && response.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'Réponse du prestataire',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent),
                      ),
                      const Spacer(),
                      if (respondedAt != null)
                        Text(
                          _fmtShortDate(respondedAt),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _R.text2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    response,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: _R.text, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ✅ TIMELINE INTERACTIVE DE SUIVI DES ÉTAPES
// ============================================================================
class _RequestTimeline extends ConsumerWidget {
  final Map<String, dynamic> request;
  final String vendorId;
  final VoidCallback onRefresh;

  const _RequestTimeline({
    required this.request,
    required this.vendorId,
    required this.onRefresh,
  });

  String get _reqStatus => request['status'] as String? ?? 'pending';
  String get _stage => request['stage'] as String? ?? 'requested';
  String get _requestId => request['id'] as String;

  bool get _approved => _reqStatus == 'approved';
  bool get _rejected => _reqStatus == 'rejected';
  bool get _pending => _reqStatus == 'pending';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIdx = _stageIndex(_stage).clamp(0, _STAGES.length - 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_R.purple, _R.purple.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timeline, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Suivi de la prestation',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_approved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _R.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Approuvé',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _R.green)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Cas EN ATTENTE ──
          if (_pending)
            _PendingBlock(requestId: _requestId, onRefresh: onRefresh),

          // ── Cas REFUSÉ ──
          if (_rejected)
            _RejectedBlock(request: request),

          // ── Cas APPROUVÉ : timeline interactive ──
          if (_approved) ...[
            _StageTracker(currentIdx: currentIdx),
            const SizedBox(height: 16),
            _StageControls(
              requestId: _requestId,
              vendorId: vendorId,
              currentIdx: currentIdx,
              onRefresh: onRefresh,
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingBlock extends ConsumerWidget {
  final String requestId;
  final VoidCallback onRefresh;
  const _PendingBlock({required this.requestId, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _R.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _R.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.hourglass_top, color: _R.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'En attente de la réponse du prestataire',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _R.amber),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Dès qu\'il accepte, le suivi des étapes s\'ouvrira automatiquement ici.',
            style: GoogleFonts.inter(fontSize: 11.5, color: _R.text2, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cancelRequest(context, ref),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Retirer la demande'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _R.rose,
                  side: const BorderSide(color: _R.rose),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Retirer cette demande ?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
            'Le prestataire ne verra plus votre demande. Vous pourrez en envoyer une nouvelle plus tard.',
            style: GoogleFonts.inter(fontSize: 13, color: _R.text2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler',
                  style: GoogleFonts.inter(color: _R.text2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _R.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Retirer',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('thix_weeding_vendor_requests')
          .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', requestId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Demande retirée',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _R.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose));
      }
    }
  }
}

class _RejectedBlock extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RejectedBlock({required this.request});

  @override
  Widget build(BuildContext context) {
    final reason = request['provider_response'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _R.rose.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _R.rose.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.cancel, color: _R.rose, size: 18),
            const SizedBox(width: 8),
            Text('Demande refusée par le prestataire',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _R.rose)),
          ]),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Motif : $reason',
                style: GoogleFonts.inter(
                    fontSize: 12, color: _R.text, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text(
            'Vous pouvez contacter le prestataire autrement ou choisir un autre professionnel du catalogue.',
            style: GoogleFonts.inter(fontSize: 11.5, color: _R.text2, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StageTracker extends StatelessWidget {
  final int currentIdx;
  const _StageTracker({required this.currentIdx});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_STAGES.length, (i) {
        final stage = _STAGES[i];
        final done = i < currentIdx;
        final active = i == currentIdx;
        final isLast = i == _STAGES.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne indicateur + ligne
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (done || active)
                          ? LinearGradient(colors: [
                              active ? _R.gold : _R.green,
                              (active ? _R.gold : _R.green).withOpacity(0.7)
                            ])
                          : null,
                      color: (!done && !active) ? _R.border : null,
                      border: Border.all(
                        color: (done || active)
                            ? Colors.transparent
                            : _R.border,
                        width: 2,
                      ),
                    ),
                    child: (done || active)
                        ? Icon(
                            active ? Icons.radio_button_checked : Icons.check,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 26,
                      color: done ? _R.green : _R.border,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Libellé + hint
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            (done || active) ? FontWeight.w800 : FontWeight.w600,
                        color: (done || active) ? _R.text : _R.text2,
                      ),
                    ),
                    if (active)
                      Text(
                        stage.hint,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _R.goldDark, height: 1.35),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StageControls extends ConsumerWidget {
  final String requestId;
  final String vendorId;
  final int currentIdx;
  final VoidCallback onRefresh;

  const _StageControls({
    required this.requestId,
    required this.vendorId,
    required this.currentIdx,
    required this.onRefresh,
  });

  bool get _isFinal => currentIdx >= _STAGES.length - 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isFinal) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _R.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _R.green.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.task_alt, color: _R.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Prestation terminée ✓ Tout est à jour.',
              style: GoogleFonts.inter(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: _R.green),
            ),
          ),
        ]),
      );
    }

    final next = _STAGES[currentIdx + 1];

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _advance(context, next),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text('Étape suivante : ${next.label}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: _R.blue,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Menu pour sauter directement à une étape
        PopupMenuButton<String>(
          tooltip: 'Changer d\'étape',
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _R.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _R.border),
            ),
            child: const Icon(Icons.swap_vert, size: 18, color: _R.text2),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (key) {
            final idx = _stageIndex(key);
            if (idx >= 0) _advanceTo(context, _STAGES[idx]);
          },
          itemBuilder: (_) => _STAGES.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return PopupMenuItem(
              value: s.key,
              child: Row(children: [
                Icon(s.icon, size: 16, color: i <= currentIdx ? _R.green : _R.text2),
                const SizedBox(width: 10),
                Text(s.label, style: GoogleFonts.inter(fontSize: 13)),
                if (i == currentIdx)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.check, size: 14, color: _R.green),
                  ),
              ]),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _advance(BuildContext context, _StageDef next) =>
      _advanceTo(context, next);

  Future<void> _advanceTo(BuildContext context, _StageDef stage) async {
    HapticFeedback.selectionClick();
    try {
      final now = DateTime.now().toIso8601String();
      // 1) Avancer le stage de la demande
      await Supabase.instance.client
          .from('thix_weeding_vendor_requests')
          .update({'stage': stage.key, 'updated_at': now})
          .eq('id', requestId);
      // 2) Miroir sur le vendor pour cohérence de la liste
      await Supabase.instance.client
          .from('thix_weeding_vendors')
          .update({'status': stage.key})
          .eq('id', vendorId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Étape mise à jour : ${stage.label} ✓',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose));
      }
    }
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _VendorAppBar extends StatelessWidget {
  final VendorModel vendor;
  final _CatDef cat;
  final _StatusDef status;
  final String weddingId;
  final bool isCatalog;
  final VoidCallback onDelete;

  const _VendorAppBar({
    required this.vendor,
    required this.cat,
    required this.status,
    required this.weddingId,
    required this.isCatalog,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 160,
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
            onTap: () => context
                .push('/thix-weeding/staff/$weddingId/prestataires/add?edit=${vendor.id}'),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.edit_outlined, color: _R.blue, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.delete_outline, color: _R.rose, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: vendor.isBooked ? _R.greenG : _R.royal,
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
                    shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _R.gold.withOpacity(0.15)),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(cat.icon, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(
                                    isCatalog ? 'PRESTATAIRE THIX' : 'PRESTATAIRE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.85),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  if (isCatalog) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified, size: 12, color: _R.gold),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                  vendor.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  cat.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(status.icon, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  status.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          if (vendor.isBooked) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: _R.goldG,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'RÉSERVÉ',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1),
                              ),
                            ),
                          ],
                        ],
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
// HERO CARD
// ============================================================================
class _HeroCard extends StatelessWidget {
  final VendorModel vendor;
  final _CatDef cat;
  final _StatusDef status;

  const _HeroCard({required this.vendor, required this.cat, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: vendor.isBooked ? _R.greenG : _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (vendor.isBooked ? _R.green : _R.gold).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(cat.icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  cat.label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
                if (vendor.price != null && vendor.price! > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${_fmtMoney(vendor.price!)} FCFA',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
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

// ============================================================================
// ACTIONS RAPIDES
// ============================================================================
class _QuickActions extends StatelessWidget {
  final VendorModel vendor;
  final String weddingId;
  final String vendorId;
  final String? providerId;
  final VoidCallback onRefresh;

  const _QuickActions({
    required this.vendor,
    required this.weddingId,
    required this.vendorId,
    required this.providerId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = vendor.phone != null && vendor.phone!.isNotEmpty;
    final hasEmail = vendor.email != null && vendor.email!.isNotEmpty;
    final hasCatalog = providerId != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasPhone)
          _ActionButton(
            icon: Icons.call,
            label: 'Appeler',
            gradient: _R.greenG,
            onTap: () {
              Clipboard.setData(ClipboardData(text: vendor.phone!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Numéro copié : ${vendor.phone}'),
                backgroundColor: _R.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
          ),
        if (hasEmail)
          _ActionButton(
            icon: Icons.email_outlined,
            label: 'Email',
            gradient: _R.royal,
            onTap: () {
              Clipboard.setData(ClipboardData(text: vendor.email!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Email copié : ${vendor.email}'),
                backgroundColor: _R.blue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
          ),
        if (hasCatalog)
          _ActionButton(
            icon: Icons.travel_explore,
            label: 'Fiche',
            gradient: _R.goldG,
            onTap: () =>
                context.push('/thix-weeding/provider/detail/$providerId'),
          ),
        _ActionButton(
          icon: vendor.isBooked ? Icons.event_busy : Icons.event_available,
          label: vendor.isBooked ? 'Annuler' : 'Confirmer',
          gradient: vendor.isBooked ? _R.roseG : _R.greenG,
          onTap: () async {
            try {
              await Supabase.instance.client
                  .from('thix_weeding_vendors')
                  .update({
                    'is_booked': !vendor.isBooked,
                    'status': vendor.isBooked ? 'cancelled' : 'booked'
                  })
                  .eq('id', vendorId);
              onRefresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      vendor.isBooked ? 'Réservation annulée' : 'Prestataire confirmé ✓'),
                  backgroundColor: vendor.isBooked ? _R.amber : _R.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose));
              }
            }
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.gradient,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: _R.blue.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTACT SECTION
// ============================================================================
class _ContactSection extends StatelessWidget {
  final VendorModel vendor;
  const _ContactSection({required this.vendor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Contact', icon: Icons.person_outline, color: _R.purple),
          const SizedBox(height: 14),
          _InfoRow(
              icon: Icons.person_outline,
              label: 'Personne de contact',
              value: vendor.contactName ?? 'Non renseigné',
              color: _R.purple),
          _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: vendor.phone ?? 'Non renseigné',
              color: _R.green,
              copyable: vendor.phone),
          _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: vendor.email ?? 'Non renseigné',
              color: _R.blue,
              copyable: vendor.email),
        ],
      ),
    );
  }
}

// ============================================================================
// CONTRACT SECTION
// ============================================================================
class _ContractSection extends StatelessWidget {
  final VendorModel vendor;
  const _ContractSection({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(vendor.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              title: 'Contrat & Tarif', icon: Icons.payments_outlined, color: _R.gold),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Prix convenu',
            value: vendor.price != null && vendor.price! > 0
                ? '${_fmtMoney(vendor.price!)} FCFA'
                : 'Non défini',
            color: _R.gold,
          ),
          _InfoRow(
            icon: status.icon,
            label: 'Statut actuel',
            value: status.label,
            color: status.color,
            badge: true,
          ),
          _InfoRow(
            icon: vendor.isBooked ? Icons.event_available : Icons.event_busy,
            label: 'Réservation',
            value: vendor.isBooked ? 'Confirmée ✓' : 'Non réservée',
            color: vendor.isBooked ? _R.green : _R.text2,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NOTES SECTION
// ============================================================================
class _NotesSection extends StatelessWidget {
  final String notes;
  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Notes', icon: Icons.notes_outlined, color: _R.text2),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _R.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _R.border),
            ),
            child: Text(notes,
                style: GoogleFonts.inter(fontSize: 13, color: _R.text, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PACKAGES SECTION
// ============================================================================
class _PackagesSection extends StatelessWidget {
  final List<VendorPackageModel> packages;
  const _PackagesSection({required this.packages});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              title: 'Prestations (${packages.length})',
              icon: Icons.list_alt_outlined,
              color: _R.blue),
          const SizedBox(height: 14),
          ...packages.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _R.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _R.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: _R.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.star_outline, size: 16, color: _R.blue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            if (p.description != null && p.description!.isNotEmpty)
                              Text(p.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: _R.text2)),
                          ],
                        ),
                      ),
                      Text('${_fmtMoney(p.price)} FCFA',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w800, color: _R.gold)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ============================================================================
// EXPENSES SECTION
// ============================================================================
class _ExpensesSection extends StatelessWidget {
  final AsyncValue<List<ExpenseModel>> expensesAsync;
  final double totalSpent;
  final double paidAmount;
  final double unpaidAmount;

  const _ExpensesSection({
    required this.expensesAsync,
    required this.totalSpent,
    required this.paidAmount,
    required this.unpaidAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              title: 'Dépenses liées', icon: Icons.receipt_long_outlined, color: _R.rose),
          const SizedBox(height: 14),

          if (totalSpent > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_R.rose.withOpacity(0.08), _R.amber.withOpacity(0.08)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _R.rose.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _ExpenseMiniStat(
                          label: 'Total', value: totalSpent, color: _R.text)),
                  Expanded(
                      child: _ExpenseMiniStat(
                          label: 'Payé', value: paidAmount, color: _R.green)),
                  Expanded(
                      child: _ExpenseMiniStat(
                          label: 'Restant',
                          value: unpaidAmount,
                          color: unpaidAmount > 0 ? _R.rose : _R.green)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          expensesAsync.when(
            loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: _R.rose)),
            data: (expenses) {
              if (expenses.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: _R.surface, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_outlined, size: 32, color: _R.text2),
                      const SizedBox(height: 8),
                      Text('Aucune dépense liée',
                          style: GoogleFonts.inter(fontSize: 13, color: _R.text2)),
                    ],
                  ),
                );
              }
              return Column(
                children: expenses
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _R.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: e.isPaid
                                      ? _R.green.withOpacity(0.3)
                                      : _R.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (e.isPaid ? _R.green : _R.amber).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                      e.isPaid ? Icons.check_circle : Icons.pending,
                                      size: 16,
                                      color: e.isPaid ? _R.green : _R.amber),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                              fontSize: 13, fontWeight: FontWeight.w700)),
                                      Text(e.category,
                                          style: GoogleFonts.inter(
                                              fontSize: 10, color: _R.text2)),
                                    ],
                                  ),
                                ),
                                Text('${_fmtMoney(e.amount)} FCFA',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: e.isPaid ? _R.green : _R.amber)),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExpenseMiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ExpenseMiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(_fmtMoney(value),
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: _R.text2)),
      ],
    );
  }
}

// ============================================================================
// META CARD
// ============================================================================
class _MetaCard extends StatelessWidget {
  final VendorModel vendor;
  final bool isCatalog;
  const _MetaCard({required this.vendor, required this.isCatalog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _R.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _R.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: _R.text2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.fingerprint, size: 14, color: _R.text2)),
              const SizedBox(width: 8),
              Text('Métadonnées',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _R.text2)),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(label: 'ID unique', value: vendor.id),
          _MetaRow(label: 'Origine', value: isCatalog ? 'Catalogue THIX' : 'Saisie manuelle'),
          _MetaRow(label: 'Créé le', value: _fmtDateTime(vendor.createdAt)),
          _MetaRow(label: 'Paquets', value: '${vendor.packages.length} prestation(s)'),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS UTILITAIRES
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool badge;
  final String? copyable;

  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      this.badge = false,
      this.copyable});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                const SizedBox(height: 2),
                badge
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.3))),
                        child: Text(value,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                      )
                    : Text(value,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: value == 'Non renseigné' || value == 'Non défini'
                                ? _R.text2
                                : _R.text)),
              ],
            ),
          ),
          if (copyable != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copyable!));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Copié ✓'),
                      backgroundColor: _R.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.copy, size: 14, color: _R.text2)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: GoogleFonts.inter(fontSize: 11, color: _R.text2))),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: _R.text))),
        ],
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 36)),
          const SizedBox(height: 16),
          Text('Chargement...',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
        ]),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: _R.rose.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline, color: _R.rose, size: 40)),
            const SizedBox(height: 16),
            Text('Impossible de charger',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _R.blue)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtMoney(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  var count = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    count++;
    if (count % 3 == 0 && i > 0) buf.write(' ');
  }
  return buf.toString().split('').reversed.join();
}

String _fmtDateTime(DateTime dt) {
  const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _fmtShortDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return '';
  }
}
