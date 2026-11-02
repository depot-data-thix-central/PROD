// lib/presentation/thix_weeding/pages/provider_portal/provider_detail_page.dart
// ============================================================================
// THIX WEDDING — PAGE DÉTAIL PRESTATAIRE (PRODUCTION ENTERPRISE)
// ✅ Hero image + galerie horizontale
// ✅ Code THIX copiable
// ✅ Sheet de réservation (sans auth obligatoire)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseSoft = Color(0xFFFFF0F3);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color gold = Color(0xFFFFD700);
  static const Color red = Color(0xFFEF4444);
}

class ProviderDetailPage extends ConsumerWidget {
  final String providerId;
  const ProviderDetailPage({super.key, required this.providerId});

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $code copié', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(providerByIdProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        if (provider == null) {
          return Scaffold(
            backgroundColor: _P.bg,
            body: Center(child: Text('Prestataire introuvable', style: GoogleFonts.inter(color: _P.inkSoft))),
          );
        }

        final cover = provider.galleryUrls.isNotEmpty
            ? provider.galleryUrls.first
            : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&q=80';

        return Scaffold(
          backgroundColor: _P.bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // HERO
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: _P.surface,
                foregroundColor: _P.ink,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _P.ink),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _P.roseSoft)),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: _P.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.verified, size: 13, color: _P.green),
                              const SizedBox(width: 4),
                              Text(provider.level.displayName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.green)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: _P.roseSoft, borderRadius: BorderRadius.circular(10)),
                            child: Text(provider.category.displayName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.rose)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Nom + note
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(provider.businessName, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)),
                          ),
                          Row(children: [
                            const Icon(Icons.star_rounded, size: 18, color: _P.gold),
                            const SizedBox(width: 4),
                            Text('${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: _P.inkSoft),
                        const SizedBox(width: 4),
                        Text(provider.city ?? 'RDC', style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 16),

                      // Code Thix copiable
                      GestureDetector(
                        onTap: () => _copyCode(context, provider.uniqueCode),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.line)),
                          child: Row(children: [
                            const Icon(Icons.qr_code_2_rounded, color: _P.rose, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Code Thix', style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                                Text(provider.uniqueCode, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: 1)),
                              ]),
                            ),
                            const Icon(Icons.copy_rounded, size: 16, color: _P.inkSoft),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      if ((provider.description ?? '').isNotEmpty) ...[
                        Text('À propos', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 6),
                        Text(provider.description!, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.5)),
                        const SizedBox(height: 20),
                      ],

                      // Tarifs
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]), borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          const Icon(Icons.payments_outlined, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Tarifs', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
                              Text(
                                provider.minPrice != null
                                    ? 'À partir de ${provider.minPrice!.toStringAsFixed(0)}${provider.currency == 'USD' ? r'$' : provider.currency}'
                                    : 'Sur devis — contactez-nous',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      // Galerie
                      if (provider.galleryUrls.isNotEmpty) ...[
                        Text('Galerie (${provider.galleryUrls.length})', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: provider.galleryUrls.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(provider.galleryUrls[i], width: 110, height: 110, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 110, height: 110, color: _P.line)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _P.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))]),
            child: SafeArea(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _openBooking(context, ref, provider),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text('Demander une réservation', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(backgroundColor: _P.bg, body: Center(child: CircularProgressIndicator(color: _P.rose))),
      error: (e, _) => Scaffold(backgroundColor: _P.bg, body: Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: _P.inkSoft)))),
    );
  }

  void _openBooking(BuildContext context, WidgetRef ref, ThixProviderModel provider) {
    final user = Supabase.instance.client.auth.currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(provider: provider, hasAuth: user != null),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET DE RÉSERVATION (fonctionne avec ou sans auth)
// ═══════════════════════════════════════════════════════════════════════════
class _BookingSheet extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final bool hasAuth;
  const _BookingSheet({required this.provider, required this.hasAuth});

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  List<Map<String, dynamic>> _weddings = [];
  bool _loadingWeddings = true;
  String? _weddingId;
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadWeddings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _guestsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWeddings() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _loadingWeddings = false);
        return;
      }
      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select('id, bride_name, groom_name')
          .eq('owner_id', user.id);
      if (!mounted) return;
      setState(() {
        _weddings = List<Map<String, dynamic>>.from(res);
        if (_weddings.length == 1) _weddingId = _weddings.first['id'] as String;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingWeddings = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    // Cas sans auth : on demande le nom du client
    if (!widget.hasAuth && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez saisir votre nom', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: _P.rose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }

    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Téléphone requis', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: _P.rose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }

    setState(() => _submitting = true);

    try {
      String clientName;
      String weddingId;

      if (widget.hasAuth && _weddingId != null) {
        final wedding = _weddings.firstWhere((w) => w['id'] == _weddingId);
        clientName = '${wedding['bride_name'] ?? ''} & ${wedding['groom_name'] ?? ''}'.trim();
        weddingId = _weddingId!;
      } else {
        // Mode sans auth : on crée un mariage "fantôme" ou on utilise un ID générique
        clientName = _nameCtrl.text.trim();
        weddingId = 'guest-${DateTime.now().millisecondsSinceEpoch}';
      }

      await ref.read(createReservationProvider)(
        providerId: widget.provider.id,
        weddingId: weddingId,
        clientName: clientName.isEmpty ? 'Client invité' : clientName,
        clientPhone: _phoneCtrl.text.trim(),
        eventDate: _date,
        eventType: widget.provider.category.displayName,
        guestCount: int.tryParse(_guestsCtrl.text.trim()),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande envoyée au prestataire ✔', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: _P.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: _P.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Réserver ${widget.provider.businessName}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 16),

            // Cas avec auth : choix du mariage
            if (widget.hasAuth) ...[
              if (_loadingWeddings)
                const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.rose)))
              else if (_weddings.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _P.roseSoft, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: _P.rose, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Créez d\'abord votre mariage depuis l\'espace staff pour pouvoir réserver.', style: GoogleFonts.inter(fontSize: 12, color: _P.rose, fontWeight: FontWeight.w600))),
                  ]),
                )
              else
                DropdownButtonFormField<String>(
                  value: _weddingId,
                  decoration: InputDecoration(
                    labelText: 'Votre mariage',
                    filled: true,
                    fillColor: _P.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.rose, width: 2)),
                  ),
                  items: _weddings
                      .map((w) => DropdownMenuItem(
                            value: w['id'] as String,
                            child: Text('${w['bride_name'] ?? ''} & ${w['groom_name'] ?? ''}', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _weddingId = v),
                ),
              const SizedBox(height: 14),
            ],

            // Cas sans auth : champ nom
            if (!widget.hasAuth) ...[
              TextField(
                controller: _nameCtrl,
                decoration: _sheetInput('Votre nom complet *', Icons.person_outline),
              ),
              const SizedBox(height: 14),
            ],

            // Date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.line)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, color: _P.rose, size: 18),
                  const SizedBox(width: 10),
                  Text(DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(_date), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: _sheetInput('Votre téléphone *', Icons.phone)),
            const SizedBox(height: 14),
            TextField(controller: _guestsCtrl, keyboardType: TextInputType.number, decoration: _sheetInput('Nombre d\'invités (optionnel)', Icons.group_outlined)),
            const SizedBox(height: 14),
            TextField(controller: _notesCtrl, maxLines: 3, decoration: _sheetInput('Message au prestataire (optionnel)', Icons.edit_note_outlined)),
            const SizedBox(height: 20),

            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Envoyer la demande', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  InputDecoration _sheetInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _P.surface,
      prefixIcon: Icon(icon, color: _P.rose, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.rose, width: 2)),
    );
  }
}
