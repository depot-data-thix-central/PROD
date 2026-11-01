

// lib/presentation/thix_weeding/pages/staff/invités/add_guest_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — ADD/EDIT GUEST (PRODUCTION v4)
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STYLE MONOSPACE GLOBAL
// ═══════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM ROYAL
// ═══════════════════════════════════════════════════════════════════════════
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color cream = Color(0xFFFFF8E7);
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

// Groupes
const List<_Group> _GROUPS = [
  _Group('famille_marié', 'Famille du marié', Icons.family_restroom, Color(0xFF0B3B8F)),
  _Group('famille_mariée', 'Famille de la mariée', Icons.favorite, Color(0xFFE31C4E)),
  _Group('amis', 'Amis', Icons.people, Color(0xFF6B46C1)),
  _Group('collegues', 'Collègues', Icons.work, Color(0xFFD97706)),
  _Group('vip', 'VIP', Icons.star, Color(0xFFD4AF37)),
];

class _Group {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _Group(this.key, this.label, this.icon, this.color);
}

// ═══════════════════════════════════════════════════════════════════════════
// GÉNÉRATEUR DE THIX ID UNIQUE
// ═══════════════════════════════════════════════════════════════════════════
class _ThixIdGenerator {
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 9999;
    final part1 = timestamp.toRadixString(36).toUpperCase().padLeft(8, '0');
    final part2 = random.toString().padLeft(4, '0');
    return 'THIX-GST-$part1-$part2';
  }

  static String checksum(String payload) {
    var hash = 0;
    for (var i = 0; i < payload.length; i++) {
      hash = ((hash << 5) - hash + payload.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return (hash.abs() % 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class AddGuestPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editGuestId;

  const AddGuestPage({super.key, required this.weddingId, this.editGuestId});

  @override
  ConsumerState<AddGuestPage> createState() => _AddGuestPageState();
}

class _AddGuestPageState extends ConsumerState<AddGuestPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tableCtrl = TextEditingController();

  late String _publicThixId;
  String? _dbGuestId;

  String _group = 'amis';
  int _count = 1;
  bool _isVip = false;
  bool _isCompanion = false;
  bool _isLoading = false;
  bool _isInitLoading = false;
  bool _sendViaChat = true;
  bool _useThixSearch = true;
  bool _searchingThix = false;
  String? _linkedUserId;
  final _thixSearchCtrl = TextEditingController();

  bool get _isEdit => widget.editGuestId != null;

  @override
  void initState() {
    super.initState();

    if (_isEdit) {
      _dbGuestId = widget.editGuestId;
      _publicThixId = _ThixIdGenerator.generate();
      _loadEditData();
    } else {
      _publicThixId = _ThixIdGenerator.generate();
      _dbGuestId = null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _tableCtrl.dispose();
    _thixSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEditData() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('thix_weeding_guests')
          .select()
          .eq('id', _dbGuestId!)
          .single();

      final g = GuestModel.fromJson(data);

      _nameCtrl.text = g.name;
      _phoneCtrl.text = g.phone ?? '';
      _emailCtrl.text = g.email ?? '';
      _group = g.groupName ?? 'amis';
      _count = g.guestsCount;
      _isVip = g.isVip;
      _isCompanion = g.isCompanion;
      _tableCtrl.text = g.tableNumber?.toString() ?? '';
      _notesCtrl.text = g.notes ?? '';
      _publicThixId = g.thixId ?? _ThixIdGenerator.generate();

      setState(() {});
    } catch (e) {
      _showError('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }


  Future<void> _searchThixProfile() async {
    final code = _thixSearchCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      _showError('Saisissez un Thix ID valide');
      return;
    }
    setState(() => _searchingThix = true);
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, thix_id, display_name, full_name, contact_phone, phone_number, avatar_url, photo_url, username')
          .eq('thix_id', code)
          .maybeSingle();
      if (res == null) {
        _showError('Aucun profil THIX Hub trouvé pour "$code"');
        setState(() => _linkedUserId = null);
        return;
      }
      final name = (res['full_name'] as String?)?.trim().isNotEmpty == true
          ? res['full_name'] as String
          : (res['display_name'] as String?) ?? '';
      final phone = (res['contact_phone'] as String?) ?? (res['phone_number'] as String?) ?? '';
      _nameCtrl.text = name;
      _phoneCtrl.text = phone;
      _linkedUserId = res['id'] as String?;
      setState(() {});
      _showSuccess('Profil trouvé : $name');
    } catch (e) {
      _showError('Erreur recherche: $e');
    } finally {
      if (mounted) setState(() => _searchingThix = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supa = Supabase.instance.client;
      final tableNum = int.tryParse(_tableCtrl.text);

      final Map<String, dynamic> dbPayload = {
        'wedding_id': widget.weddingId,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'group_name': _group,
        'guests_count': _count,
        'table_number': tableNum,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'is_vip': _isVip,
        'is_companion': _isCompanion,
        'thix_id': _publicThixId,
        'user_id': _linkedUserId,
      };

      String? savedDbId;

      if (!_isEdit) {
        final res = await supa
            .from('thix_weeding_guests')
            .insert(dbPayload)
            .select()
            .single();
        savedDbId = res['id'] as String;
        _dbGuestId = savedDbId;

        if (_sendViaChat && savedDbId != null) {
          await _sendInvitationMessage(supa, savedDbId);
        }
      } else {
        await supa
            .from('thix_weeding_guests')
            .update(dbPayload)
            .eq('id', _dbGuestId!);
        savedDbId = _dbGuestId;
      }

      ref.invalidate(guestsProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
      ref.invalidate(myActiveInvitationsProvider);

      if (mounted) {
        _showSuccess(
          _isEdit ? 'Invité mis à jour ✓' : 'Invité créé & invitation envoyée ✓',
        );
        context.pop();
      }
    } catch (e) {
      _showError('Erreur sauvegarde: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ CORRIGÉ — null-safety : extraction des valeurs AVANT interpolation
  Future<void> _sendInvitationMessage(
    SupabaseClient supa,
    String dbGuestId,
  ) async {
    try {
      final wedding = await supa
          .from('thix_weeding_weddings')
          .select('bride_name, groom_name, wedding_date, venue')
          .eq('id', widget.weddingId)
          .maybeSingle();

      final brideName = wedding?['bride_name'] ?? '';
      final groomName = wedding?['groom_name'] ?? '';
      final weddingDateRaw = wedding?['wedding_date'];
      final venueRaw = wedding?['venue'];

      final dateStr = weddingDateRaw != null
          ? ' le ${_fmtDateLong(DateTime.parse(weddingDateRaw.toString()))}'
          : '';
      final venueStr = venueRaw != null ? ' à $venueRaw' : '';

      final msg = "Bonjour ${_nameCtrl.text.trim()} ! 🎉\n\n"
          "Vous êtes invité(e) au mariage de $brideName & $groomName$dateStr$venueStr.\n\n"
          "🔑 Votre Code d'accès Personnel (THIX ID):\n$_publicThixId\n\n"
          "Utilisez ce code sur thix.id pour voir votre invitation détaillée et confirmer votre présence.";

      await supa.from('thix_weeding_messages').insert({
        'wedding_id': widget.weddingId,
        'guest_id': dbGuestId,
        'sender_name': '$brideName & $groomName',
        'sender_type': 'staff',
        'content': msg,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Erreur envoi chat: $e');
    }
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitLoading) return const _LoadingView();

    return Scaffold(
      backgroundColor: _R.surface,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _FormAppBar(isEdit: _isEdit, onSave: _save, isLoading: _isLoading),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  if (!_isEdit) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _R.card(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comment ajouter ?', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: Material(
                              color: _useThixSearch ? _R.blue : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => setState(() => _useThixSearch = true),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _useThixSearch ? _R.blue : _R.border)),
                                  child: Text('Via Thix ID', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _useThixSearch ? Colors.white : _R.text)),
                                ),
                              ),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: Material(
                              color: !_useThixSearch ? _R.blue : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => setState(() => _useThixSearch = false),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: !_useThixSearch ? _R.blue : _R.border)),
                                  child: Text('Manuel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: !_useThixSearch ? Colors.white : _R.text)),
                                ),
                              ),
                            )),
                          ]),
                          if (_useThixSearch) ...[
                            const SizedBox(height: 12),
                            Text('Recherche THIX Hub (profiles.thix_id)', style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: TextField(
                                controller: _thixSearchCtrl,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Ex: THIX-XXXX-...',
                                  prefixIcon: const Icon(Icons.search, color: _R.blue),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onSubmitted: (_) => _searchThixProfile(),
                              )),
                              const SizedBox(width: 8),
                              Material(
                                color: _R.blue,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: _searchingThix ? null : _searchThixProfile,
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 52, height: 52,
                                    child: Center(child: _searchingThix
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.person_search, color: Colors.white)),
                                  ),
                                ),
                              ),
                            ]),
                            if (_linkedUserId != null) ...[
                              const SizedBox(height: 10),
                              Text('✓ Profil THIX Hub lié', style: GoogleFonts.inter(fontSize: 12, color: _R.green, fontWeight: FontWeight.w700)),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _SectionCard(
                    title: 'Identité',
                    icon: Icons.person_outline,
                    color: _R.blue,
                    children: [
                      _RoyalTextField(
                        controller: _nameCtrl,
                        label: 'Nom complet *',
                        hint: 'Ex: Jean Dupont',
                        icon: Icons.person_outline,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: _RoyalTextField(
                            controller: _phoneCtrl,
                            label: 'Téléphone',
                            hint: '+243 ...',
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoyalTextField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'nom@mail.com',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                          ),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _ThixIdGlobalCard(
                    thixId: _publicThixId,
                    onRegenerate: () => setState(
                      () => _publicThixId = _ThixIdGenerator.generate(),
                    ),
                    isReadOnly: _isEdit,
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Catégorie',
                    icon: Icons.group_outlined,
                    color: _R.purple,
                    children: [
                      _GroupSelector(
                        selected: _group,
                        onChanged: (g) => setState(() => _group = g),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Placement',
                    icon: Icons.event_seat_outlined,
                    color: _R.gold,
                    children: [
                      _CounterRow(
                        label: 'Nombre de personnes',
                        value: _count,
                        min: 1,
                        max: 20,
                        onChanged: (v) => setState(() => _count = v),
                      ),
                      const SizedBox(height: 14),
                      _RoyalTextField(
                        controller: _tableCtrl,
                        label: 'Table (optionnel)',
                        hint: '1, 2, 3...',
                        icon: Icons.table_restaurant_outlined,
                        keyboard: TextInputType.number,
                        formatter: FilteringTextInputFormatter.digitsOnly,
                      ),
                      const SizedBox(height: 14),
                      _ToggleRow(
                        label: 'Invité VIP',
                        subtitle: 'Accès prioritaire',
                        icon: Icons.star,
                        color: _R.gold,
                        value: _isVip,
                        onChanged: (v) => setState(() => _isVip = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        label: 'Accompagnant (+1)',
                        subtitle: 'Peut venir avec quelqu\'un',
                        icon: Icons.group_add_outlined,
                        color: _R.blue,
                        value: _isCompanion,
                        onChanged: (v) => setState(() => _isCompanion = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Notes internes',
                    icon: Icons.notes_outlined,
                    color: _R.text2,
                    children: [
                      _RoyalTextField(
                        controller: _notesCtrl,
                        label: 'Infos complémentaires',
                        hint: 'Allergies, régime spécial...',
                        icon: Icons.edit_note_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _LiveInvitationPreview(
                    weddingId: widget.weddingId,
                    name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Nouvel Invité',
                    thixId: _publicThixId,
                  ),
                  const SizedBox(height: 24),

                  if (!_isEdit) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _R.card(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _R.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                color: _R.blue,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Envoyer l\'invitation',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Switch(
                              value: _sendViaChat,
                              activeColor: _R.blue,
                              onChanged: (v) => setState(() => _sendViaChat = v),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            'Le message sera envoyé directement dans la messagerie Thix de l\'invité.',
                            style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  _SubmitButton(
                    isEdit: _isEdit,
                    isLoading: _isLoading,
                    onTap: _save,
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

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _ThixIdGlobalCard extends StatelessWidget {
  final String thixId;
  final VoidCallback onRegenerate;
  final bool isReadOnly;

  const _ThixIdGlobalCard({
    required this.thixId,
    required this.onRegenerate,
    required this.isReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _R.gold.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.public, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIX ID GLOBAL (PUBLIC)',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Identifiant unique utilisé pour la connexion et le QR Code',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            if (!isReadOnly)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRegenerate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Row(children: [
              Expanded(
                child: SelectableText(
                  thixId,
                  style: _mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: thixId));
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LiveInvitationPreview extends StatefulWidget {
  final String weddingId;
  final String name;
  final String thixId;

  const _LiveInvitationPreview({
    required this.weddingId,
    required this.name,
    required this.thixId,
  });

  @override
  State<_LiveInvitationPreview> createState() => _LiveInvitationPreviewState();
}

class _LiveInvitationPreviewState extends State<_LiveInvitationPreview> {
  bool _loading = true;
  String _bride = '';
  String _groom = '';
  String _date = '';
  String _time = '';
  String _place = '';
  String _title = 'Save The Date';
  String _intro = '';
  String _outro = '';
  String _heroUrl = '';
  Color _accent = const Color(0xFFC9A24B);
  Color _bg = const Color(0xFF1A1520);

  @override
  void initState() {
    super.initState();
    _loadStudioDesign();
  }

  Future<void> _loadStudioDesign() async {
    try {
      final row = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select(
              'bride_name, groom_name, wedding_date, venue, invitation_config')
          .eq('id', widget.weddingId)
          .maybeSingle();

      if (row == null || !mounted) {
        setState(() => _loading = false);
        return;
      }

      _bride = (row['bride_name'] as String?)?.trim() ?? '';
      _groom = (row['groom_name'] as String?)?.trim() ?? '';
      final venue = (row['venue'] as String?)?.trim() ?? '';
      final dateRaw = row['wedding_date'];
      if (dateRaw != null) {
        final dt = DateTime.tryParse(dateRaw.toString());
        if (dt != null) {
          const months = [
            'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
            'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
          ];
          _date = '${dt.day} ${months[dt.month - 1]} ${dt.year}'.toUpperCase();
        }
      }

      Map<String, dynamic>? cfg;
      final raw = row['invitation_config'];
      if (raw is Map) {
        cfg = Map<String, dynamic>.from(raw);
      }

      if (cfg != null) {
        _title = (cfg['title_text'] as String?)?.trim().isNotEmpty == true
            ? cfg['title_text'] as String
            : _title;
        _intro = (cfg['intro_text'] as String?) ?? '';
        _outro = (cfg['outro_text'] as String?) ?? '';
        _time = (cfg['time_text'] as String?) ?? '';
        _place = (cfg['place_text'] as String?)?.trim().isNotEmpty == true
            ? cfg['place_text'] as String
            : venue;
        _heroUrl = (cfg['hero_image_url'] as String?) ?? '';

        Color parseHex(dynamic hex, Color fb) {
          if (hex is! String || hex.isEmpty) return fb;
          try {
            final c = hex.replaceAll('#', '');
            return Color(int.parse('FF$c', radix: 16));
          } catch (_) {
            return fb;
          }
        }

        _accent = parseHex(cfg['primary_color'], _accent);
        _bg = parseHex(cfg['background_color'], _bg);
      } else {
        _place = venue;
      }

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.name.trim().isEmpty ? 'Nouvel Invité' : widget.name.trim();
    final couple = (_bride.isEmpty && _groom.isEmpty)
        ? 'Les mariés'
        : '$_bride & $_groom';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _R.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: _R.royal,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_outline, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aperçu invitation (design Studio)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _R.text,
                    ),
                  ),
                  Text(
                    'Même modèle que le Studio d\'Invitation',
                    style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (_loading)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 0.72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fond photo ou dégradé (comme Studio)
                    if (_heroUrl.isNotEmpty)
                      Image.network(
                        _heroUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: _bg),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(_bg, _accent, 0.15)!,
                              _bg,
                            ],
                          ),
                        ),
                      ),
                    // Voile sombre pour lisibilité
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.25),
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.78),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    // Cadre ornemental léger
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _accent.withOpacity(0.75),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Contenu
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 28, 18, 20),
                      child: Column(
                        children: [
                          Text(
                            _title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                              fontSize: 10,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Cher(e)',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            guest,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _intro.isNotEmpty
                                ? _intro
                                : 'Vous êtes invité(e) au mariage de',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            couple,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.greatVibes(
                              fontSize: 28,
                              color: _accent,
                            ),
                          ),
                          const Spacer(),
                          if (_date.isNotEmpty)
                            Text(
                              _time.isNotEmpty ? '$_date  ·  $_time' : _date,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cinzel(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                                color: _accent,
                              ),
                            ),
                          if (_place.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _place,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                          if (_outro.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _outro,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: _accent.withOpacity(0.95),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_2_rounded,
                                    size: 14, color: _accent),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.thixId,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _FormAppBar extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onSave;
  final bool isLoading;

  const _FormAppBar({
    required this.isEdit,
    required this.onSave,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: _R.text,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => context.pop(),
      ),
      title: Text(
        isEdit ? 'Modifier invité' : 'Nouvel invité',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: _R.blue,
          fontSize: 18,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: isLoading ? _R.border : _R.green,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: isLoading ? null : onSave,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            isEdit ? 'Enregistrer' : 'Créer',
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
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _RoyalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final TextInputFormatter? formatter;
  final String? Function(String?)? validator;
  final int maxLines;

  const _RoyalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.formatter,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatter != null ? [formatter!] : null,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
        hintStyle: GoogleFonts.inter(
          color: _R.text2.withOpacity(0.6),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: _R.blue, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.rose),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}

class _GroupSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GroupSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _GROUPS.map((g) {
        final isSelected = g.key == selected;
        return Material(
          color: isSelected ? g.color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(g.key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? g.color : _R.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  g.icon,
                  size: 16,
                  color: isSelected ? Colors.white : g.color,
                ),
                const SizedBox(width: 6),
                Text(
                  g.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : _R.text,
                  ),
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _R.blue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _R.blue.withOpacity(0.15)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                'Personnes confirmées',
                style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
              ),
            ],
          ),
        ),
        _CounterBtn(
          icon: Icons.remove,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: _R.royal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$value',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _CounterBtn(
          icon: Icons.add,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ]),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? _R.border : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? _R.text2 : _R.blue,
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color : _R.border,
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: value ? color : _R.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? color.withOpacity(0.15) : _R.border.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: value ? color : _R.text2,
          ),
        ),
        value: value,
        activeColor: color,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isEdit;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.isEdit,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isLoading ? null : _R.royal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading
            ? null
            : [
                BoxShadow(
                  color: _R.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: isLoading ? _R.border : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isEdit ? Icons.check : Icons.person_add,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Enregistrer modifications' : 'Créer l\'invité',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

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
            decoration: const BoxDecoration(
              gradient: _R.goldG,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_empty, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement...',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _R.text2,
            ),
          ),
        ]),
      ),
    );
  }
}

String _fmtDateLong(DateTime dt) {
  const months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
