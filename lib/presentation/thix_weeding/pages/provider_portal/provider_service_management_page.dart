// lib/presentation/thix_weeding/pages/provider_portal/provider_service_management_page.dart
// ============================================================================
// THIX WEDDING — GESTION DE PRESTATION RÉELLE (remplace _GenericServicePage)
// ✅ DÉTAILS   : édition du dossier vendor (prix, statut, is_booked, notes)
// ✅ DOCUMENTS : upload Storage (thix-provider-media/vendor-docs/) + liste + suppression
// ✅ PAIEMENTS : saisie acomptes/soldes, progression payé vs prix, suppression
// ✅ Zéro dart:io (uploadBinary => compatible Web + Android)
// ✅ Tables : thix_vendor_documents / thix_vendor_payments (SQL fournie)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';

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
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF14B8A6);
}

const _vendorStatuses = ['contacted', 'confirmed', 'booked', 'done', 'cancelled'];

String vendorStatusLabel(String? s) => switch (s) {
      'contacted' => 'Contacté',
      'confirmed' => 'Confirmé',
      'booked' => 'Réservé',
      'done' => 'Terminé',
      'cancelled' => 'Annulé',
      _ => s ?? '—',
    };

Color vendorStatusColor(String? s) => switch (s) {
      'contacted' => _P.amber,
      'confirmed' => _P.blue,
      'booked' => _P.green,
      'done' => _P.teal,
      'cancelled' => _P.red,
      _ => _P.inkSoft,
    };

const _payMethods = {
  'especes': 'Espèces',
  'mobile_money': 'Mobile Money',
  'banque': 'Virement bancaire',
  'carte': 'Carte',
};

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS RIVERPOD
// ═══════════════════════════════════════════════════════════════════════════
final vendorRowProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, vendorId) async {
  final res = await Supabase.instance.client
      .from('thix_weeding_vendors')
      .select()
      .eq('id', vendorId)
      .maybeSingle();
  return res == null ? null : Map<String, dynamic>.from(res);
});

final weddingRowProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, weddingId) async {
  final res = await Supabase.instance.client
      .from('thix_weeding_weddings')
      .select()
      .eq('id', weddingId)
      .maybeSingle();
  return res == null ? null : Map<String, dynamic>.from(res);
});

final vendorDocsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, vendorId) async {
  final res = await Supabase.instance.client
      .from('thix_vendor_documents')
      .select()
      .eq('vendor_id', vendorId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final vendorPaymentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, vendorId) async {
  final res = await Supabase.instance.client
      .from('thix_vendor_payments')
      .select()
      .eq('vendor_id', vendorId)
      .order('paid_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class VendorServiceManager extends ConsumerStatefulWidget {
  final String vendorId;
  final String weddingId;
  final ThixProviderModel provider;
  final String couple;

  const VendorServiceManager({
    super.key,
    required this.vendorId,
    required this.weddingId,
    required this.provider,
    required this.couple,
  });

  @override
  ConsumerState<VendorServiceManager> createState() => _VendorServiceManagerState();
}

class _VendorServiceManagerState extends ConsumerState<VendorServiceManager> {
  final _picker = ImagePicker();

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _refreshAll() {
    ref.invalidate(vendorRowProvider(widget.vendorId));
    ref.invalidate(weddingRowProvider(widget.weddingId));
    ref.invalidate(vendorDocsProvider(widget.vendorId));
    ref.invalidate(vendorPaymentsProvider(widget.vendorId));
  }

  @override
  Widget build(BuildContext context) {
    final vendorAsync = ref.watch(vendorRowProvider(widget.vendorId));
    final weddingAsync = ref.watch(weddingRowProvider(widget.weddingId));
    final docsAsync = ref.watch(vendorDocsProvider(widget.vendorId));
    final paysAsync = ref.watch(vendorPaymentsProvider(widget.vendorId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.rose,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Gestion de la prestation',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _P.rose,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          _refreshAll();
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // ── HEADER COUPLE + MARIAGE ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_P.rose.withOpacity(0.12), _P.roseLight.withOpacity(0.06)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _P.rose.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _P.rose.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: _P.rose, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prestation pour',
                            style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft)),
                        Text(widget.couple,
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
                        Text(widget.provider.businessName,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        weddingAsync.when(
                          data: (w) {
                            if (w == null) return const SizedBox.shrink();
                            final dateStr = w['wedding_date'] as String?;
                            String dateLabel = 'Date à définir';
                            if (dateStr != null && dateStr.isNotEmpty) {
                              try {
                                dateLabel = DateFormat('EEEE dd MMMM yyyy', 'fr_FR')
                                    .format(DateTime.parse(dateStr));
                              } catch (_) {}
                            }
                            final venue = (w['venue'] as String? ?? '').trim();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 12, color: _P.rose),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(dateLabel,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _P.ink)),
                                  ),
                                ]),
                                if (venue.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 12, color: _P.rose),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(venue,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                              fontSize: 11, color: _P.inkSoft)),
                                    ),
                                  ]),
                                ],
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 1) DÉTAILS ──
            vendorAsync.when(
              data: (vendor) {
                if (vendor == null) {
                  return _errorTile('Dossier prestataire introuvable (vendor_id).');
                }
                final price = (vendor['price'] as num?)?.toDouble();
                final status = vendor['status'] as String?;
                final booked = vendor['is_booked'] as bool? ?? false;
                final notes = vendor['notes'] as String?;
                final paid = paysAsync.valueOrNull?.fold<double>(
                        0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0)) ??
                    0;

                return _card(
                  icon: Icons.settings_rounded,
                  color: _P.rose,
                  title: 'Détails',
                  action: IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined, color: _P.inkSoft, size: 20),
                    onPressed: () => _editDetails(vendor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _badge(vendorStatusLabel(status), vendorStatusColor(status),
                              Icons.flag_rounded),
                          if (booked)
                            _badge('Réservée', _P.green, Icons.check_circle_rounded),
                          _badge(
                              price != null
                                  ? '${price.toStringAsFixed(0)} USD'
                                  : 'Prix à définir',
                              _P.blue,
                              Icons.payments_rounded),
                          _badge('Payé : ${paid.toStringAsFixed(0)} USD', _P.teal,
                              Icons.savings_rounded),
                        ],
                      ),
                      if ((notes ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: _P.bg, borderRadius: BorderRadius.circular(10)),
                          child: Text(notes!,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: _P.ink, height: 1.4)),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: _P.rose)),
              ),
              error: (e, _) => _errorTile('Erreur détails: $e'),
            ),
            const SizedBox(height: 16),

            // ── 2) DOCUMENTS ──
            _card(
              icon: Icons.description_outlined,
              color: _P.blue,
              title: 'Documents',
              action: IconButton(
                tooltip: 'Ajouter un document',
                icon: const Icon(Icons.add_circle_outline, color: _P.blue),
                onPressed: _addDocument,
              ),
              child: docsAsync.when(
                data: (docs) => docs.isEmpty
                    ? Text('Aucun document. Ajoutez contrat, devis signé, facture…',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _P.inkSoft,
                            fontStyle: FontStyle.italic))
                    : Column(
                        children: docs
                            .map((d) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: _P.bg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _P.line)),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: _P.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10)),
                                        child: const Icon(Icons.image_outlined,
                                            color: _P.blue, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(d['name'] as String? ?? 'Document',
                                                style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: _P.ink)),
                                            Text(
                                                _fmtDate(
                                                    d['created_at'] as String?),
                                                style: GoogleFonts.inter(
                                                    fontSize: 10.5,
                                                    color: _P.inkSoft)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Ouvrir',
                                        icon: const Icon(Icons.open_in_new_rounded,
                                            size: 18, color: _P.blue),
                                        onPressed: () =>
                                            _openUrl(d['url'] as String? ?? ''),
                                      ),
                                      IconButton(
                                        tooltip: 'Supprimer',
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: _P.red),
                                        onPressed: () =>
                                            _deleteDocument(d['id'] as String),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _P.blue)),
                ),
                error: (e, _) => _errorTile(
                    'Table thix_vendor_documents absente ? Exécutez le SQL fourni.\n$e'),
              ),
            ),
            const SizedBox(height: 16),

            // ── 3) PAIEMENTS ──
            _card(
              icon: Icons.payments_outlined,
              color: _P.green,
              title: 'Paiements',
              action: IconButton(
                tooltip: 'Ajouter un paiement',
                icon: const Icon(Icons.add_circle_outline, color: _P.green),
                onPressed: () => _addPayment(vendorAsync.valueOrNull),
              ),
              child: paysAsync.when(
                data: (pays) {
                  final price =
                      (vendorAsync.valueOrNull?['price'] as num?)?.toDouble();
                  final paid = pays.fold<double>(
                      0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
                  final progress =
                      (price != null && price > 0) ? (paid / price).clamp(0.0, 1.0) : 0.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${paid.toStringAsFixed(0)} USD',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: _P.green)),
                          const SizedBox(width: 6),
                          Text(
                              price != null
                                  ? '/ ${price.toStringAsFixed(0)} USD'
                                  : '(prix non défini)',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: _P.inkSoft)),
                          const Spacer(),
                          Text('${(progress * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _P.teal)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: _P.line,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_P.green),
                        ),
                      ),
                      if (price != null && paid < price) ...[
                        const SizedBox(height: 6),
                        Text(
                            'Reste à percevoir : ${(price - paid).toStringAsFixed(0)} USD',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _P.amber,
                                fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 12),
                      if (pays.isEmpty)
                        Text('Aucun paiement enregistré.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _P.inkSoft,
                                fontStyle: FontStyle.italic))
                      else
                        ...pays.map((pay) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: _P.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _P.line)),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: _P.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.paid_rounded,
                                        color: _P.green, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${((pay['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} USD • ${_payMethods[pay['method']] ?? pay['method']}',
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: _P.ink)),
                                        Text(
                                            '${(pay['label'] as String? ?? '').isEmpty ? 'Paiement' : pay['label']} • ${_fmtDate(pay['paid_at'] as String?)}',
                                            style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                color: _P.inkSoft)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: _P.red),
                                    onPressed: () =>
                                        _deletePayment(pay['id'] as String),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _P.green)),
                ),
                error: (e, _) => _errorTile(
                    'Table thix_vendor_payments absente ? Exécutez le SQL fourni.\n$e'),
              ),
            ),
            const SizedBox(height: 16),

            // ── INFO ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _P.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: _P.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Les éléments validés ici pourront être rendus publics pour les invités par le staff du mariage.',
                      style: GoogleFonts.inter(fontSize: 12, color: _P.blue, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _editDetails(Map<String, dynamic> vendor) async {
    final priceCtrl = TextEditingController(
        text: (vendor['price'] as num?)?.toDouble().toStringAsFixed(0) ?? '');
    final notesCtrl = TextEditingController(text: vendor['notes'] as String? ?? '');
    String status = _vendorStatuses.contains(vendor['status'])
        ? vendor['status'] as String
        : 'contacted';
    bool booked = vendor['is_booked'] as bool? ?? false;
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Détails de la prestation',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Prix confirmé (USD)', Icons.payments_rounded)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: _dec('Statut', Icons.flag_rounded),
                  items: _vendorStatuses
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(vendorStatusLabel(s))))
                      .toList(),
                  onChanged: (v) => setSt(() => status = v!),
                ),
                SwitchListTile(
                  value: booked,
                  activeColor: _P.green,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Prestation réservée',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  onChanged: (v) => setSt(() => booked = v),
                ),
                TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: _dec('Notes / conditions', Icons.edit_note_rounded)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      setSt(() => busy = true);
                      try {
                        await Supabase.instance.client
                            .from('thix_weeding_vendors')
                            .update({
                              'price': double.tryParse(priceCtrl.text.trim()),
                              'status': status,
                              'is_booked': booked,
                              'notes': notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            })
                            .eq('id', widget.vendorId);
                        ref.invalidate(vendorRowProvider(widget.vendorId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _toast('Détails mis à jour ✓', _P.green);
                      } catch (e) {
                        setSt(() => busy = false);
                        _toast('Erreur: $e', _P.red);
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _P.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Enregistrer',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    priceCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _addDocument() async {
    final nameCtrl = TextEditingController();
    XFile? picked;
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Ajouter un document',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: nameCtrl,
                  decoration: _dec('Nom du document', Icons.description_outlined,
                      hint: 'Ex: Contrat signé, Acompte…')),
              const SizedBox(height: 12),
              if (picked == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final f = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 1600);
                          if (f != null) setSt(() => picked = f);
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text('Galerie',
                            style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final f = await _picker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 85,
                              maxWidth: 1600);
                          if (f != null) setSt(() => picked = f);
                        },
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text('Caméra', style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    ),
                  ],
                )
              else Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _P.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _P.green.withOpacity(0.4))),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: _P.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(picked!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: _P.red),
                        onPressed: () => setSt(() => picked = null),
                      ),
                    ],
                  )),
            ],
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))),
            ElevatedButton.icon(
              onPressed: (busy || picked == null)
                  ? null
                  : () async {
                      setSt(() => busy = true);
                      try {
                        final c = Supabase.instance.client;
                        final bytes = await picked!.readAsBytes();
                        final rawName = picked!.name;
                        final ext = rawName.contains('.')
                            ? rawName.split('.').last.toLowerCase()
                            : 'jpg';
                        final safeExt =
                            ['png', 'jpg', 'jpeg', 'webp'].contains(ext) ? ext : 'jpg';
                        final path =
                            'vendor-docs/${widget.vendorId}/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
                        await c.storage
                            .from('thix-provider-media')
                            .uploadBinary(path, bytes,
                                fileOptions: const FileOptions(
                                    cacheControl: '3600', upsert: false));
                        final url =
                            c.storage.from('thix-provider-media').getPublicUrl(path);
                        await c.from('thix_vendor_documents').insert({
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'vendor_id': widget.vendorId,
                          'wedding_id': widget.weddingId,
                          'name': nameCtrl.text.trim().isEmpty
                              ? 'Document'
                              : nameCtrl.text.trim(),
                          'url': url,
                          'kind': 'image',
                          'created_at': DateTime.now().toIso8601String(),
                        });
                        ref.invalidate(vendorDocsProvider(widget.vendorId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _toast('Document ajouté ✓', _P.green);
                      } catch (e) {
                        setSt(() => busy = false);
                        _toast('Erreur: $e', _P.red);
                      }
                    },
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text('Uploader',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _P.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _deleteDocument(String id) async {
    final ok = await _confirm('Supprimer ce document ?');
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('thix_vendor_documents')
          .delete()
          .eq('id', id);
      ref.invalidate(vendorDocsProvider(widget.vendorId));
      _toast('Document supprimé', _P.red);
    } catch (e) {
      _toast('Erreur: $e', _P.red);
    }
  }

  Future<void> _addPayment(Map<String, dynamic>? vendor) async {
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String method = 'especes';
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Enregistrer un paiement',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Montant (USD)', Icons.attach_money_rounded)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: _dec('Méthode', Icons.account_balance_wallet_rounded),
                items: _payMethods.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setSt(() => method = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: labelCtrl,
                  decoration: _dec('Libellé', Icons.label_outline_rounded,
                      hint: 'Ex: Acompte 40%')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) {
                        _toast('Montant invalide', _P.amber);
                        return;
                      }
                      setSt(() => busy = true);
                      try {
                        await Supabase.instance.client
                            .from('thix_vendor_payments')
                            .insert({
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'vendor_id': widget.vendorId,
                          'wedding_id': widget.weddingId,
                          'amount': amount,
                          'method': method,
                          'label': labelCtrl.text.trim().isEmpty
                              ? null
                              : labelCtrl.text.trim(),
                          'paid_at': DateTime.now().toIso8601String(),
                        });
                        ref.invalidate(vendorPaymentsProvider(widget.vendorId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _toast('Paiement enregistré ✓', _P.green);
                      } catch (e) {
                        setSt(() => busy = false);
                        _toast('Erreur: $e', _P.red);
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _P.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Enregistrer',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    labelCtrl.dispose();
  }

  Future<void> _deletePayment(String id) async {
    final ok = await _confirm('Supprimer ce paiement ?');
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('thix_vendor_payments')
          .delete()
          .eq('id', id);
      ref.invalidate(vendorPaymentsProvider(widget.vendorId));
      _toast('Paiement supprimé', _P.red);
    } catch (e) {
      _toast('Erreur: $e', _P.red);
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool?> _confirm(String message) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _P.red, foregroundColor: Colors.white),
                child: Text('Supprimer',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
          ],
        ),
      );

  // ═════════════════════════════════════════════════════════════════════════
  // HELPERS UI
  // ═════════════════════════════════════════════════════════════════════════
  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Widget _card({
    required IconData icon,
    required Color color,
    required String title,
    Widget? action,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );

  Widget _errorTile(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _P.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _P.amber.withOpacity(0.3))),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _P.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, height: 1.4)),
            ),
          ],
        ),
      );

  InputDecoration _dec(String label, IconData icon, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
        hintStyle: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft.withOpacity(0.6)),
        prefixIcon: Icon(icon, size: 18, color: _P.rose),
        filled: true,
        fillColor: _P.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );
}
