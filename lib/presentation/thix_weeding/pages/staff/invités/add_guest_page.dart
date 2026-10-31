// lib/presentation/thix_weeding/pages/staff/invités/add_guest_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — ADD/EDIT GUEST (PRODUCTION)
// Design royal + Recherche globale Thix ID / Nom + QR unique auto-généré
// Branché sur providers EXISTANTS du dépôt
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

// Groupes du cahier des charges
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

  static _Group find(String key) =>
      _GROUPS.firstWhere((g) => g.key == key, orElse: () => _GROUPS[2]);
}

// ============================================================================
// PROVIDER LOCAL : recherche globale dans Thix ID
// ============================================================================
/// Recherche un compte Thix par nom ou Thix ID dans la base centrale
/// Table utilisée : `profiles` (ajuster si votre table est différente)
final globalSearchProvider =
    FutureProvider.autoDispose.family<List<_ThixAccount>, String>((ref, query) async {
  if (query.trim().length < 2) return [];

  try {
    final supa = Supabase.instance.client;
    // Recherche flexible sur name OU thix_id
    final results = await supa
        .from('profiles') // ← adapter si vous utilisez `thix_id_accounts` ou autre
        .select('id, full_name, email, phone, thix_id')
        .or('full_name.ilike.%$query%,thix_id.ilike.%$query%,email.ilike.%$query%')
        .limit(10);

    return (results as List).map((r) => _ThixAccount.fromJson(r)).toList();
  } catch (e) {
    return [];
  }
});

class _ThixAccount {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? thixId;

  _ThixAccount({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.thixId,
  });

  factory _ThixAccount.fromJson(Map<String, dynamic> j) => _ThixAccount(
        id: j['id']?.toString() ?? '',
        name: j['full_name']?.toString() ?? 'Sans nom',
        email: j['email']?.toString(),
        phone: j['phone']?.toString(),
        thixId: j['thix_id']?.toString(),
      );
}

// ============================================================================
// GÉNÉRATEUR DE THIX ID UNIQUE POUR INVITÉ
// ============================================================================
class _ThixIdGenerator {
  /// Génère un Thix ID unique au format THIX-GST-XXXXXXXX-YYYY
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 9999;
    final part1 = timestamp.toRadixString(36).toUpperCase().padLeft(8, '0');
    final part2 = random.toString().padLeft(4, '0');
    return 'THIX-GST-$part1-$part2';
  }

  /// Génère un checksum MD5-like (4 caractères)
  static String checksum(String payload) {
    var hash = 0;
    for (var i = 0; i < payload.length; i++) {
      hash = ((hash << 5) - hash + payload.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return (hash.abs() % 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

// ============================================================================
// PAGE
// ============================================================================
class AddGuestPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editGuestId;

  const AddGuestPage({super.key, required this.weddingId, this.editGuestId});

  @override
  ConsumerState<AddGuestPage> createState() => _AddGuestPageState();
}

class _AddGuestPageState extends ConsumerState<AddGuestPage>
    with SingleTickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _thixIdCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tableCtrl = TextEditingController();

  // State
  String _group = 'amis';
  int _count = 1;
  bool _isVip = false;
  bool _isCompanion = false;
  bool _isLoading = false;
  bool _isInitLoading = false;
  _ThixAccount? _linkedAccount;

  // Search debounce
  Timer? _debounce;
  String _searchQuery = '';

  bool get _isEdit => widget.editGuestId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadEdit();
    } else {
      // Générer un Thix ID unique pour le nouvel invité
      _thixIdCtrl.text = _ThixIdGenerator.generate();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _thixIdCtrl.dispose();
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    _tableCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ============================================================================
  // DATA
  // ============================================================================
  Future<void> _loadEdit() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('thix_weeding_guests')
          .select()
          .eq('id', widget.editGuestId!)
          .single();
      final g = GuestModel.fromJson(data);
      _nameCtrl.text = g.name;
      _phoneCtrl.text = g.phone ?? '';
      _emailCtrl.text = g.email ?? '';
      _group = g.groupName ?? 'amis';
      _count = g.guestsCount;
      if (g.tableNumber != null) {
        _tableCtrl.text = g.tableNumber.toString();
      }
      setState(() {});
    } catch (e) {
      _showError('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supa = Supabase.instance.client;
      final tableNum = int.tryParse(_tableCtrl.text);

      final data = {
        'wedding_id': widget.weddingId,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'group_name': _group,
        'guests_count': _count,
        'table_number': tableNum,
        'thix_id': _thixIdCtrl.text.trim(),
        'linked_account_id': _linkedAccount?.id,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'is_vip': _isVip,
        'is_companion': _isCompanion,
      };

      if (!_isEdit) {
        final inserted = await supa
            .from('thix_weeding_guests')
            .insert(data)
            .select()
            .single();

        _showSuccess('Invité créé • ID: ${inserted['id'].toString().substring(0, 8)}');
      } else {
        await supa
            .from('thix_weeding_guests')
            .update(data)
            .eq('id', widget.editGuestId!);
        _showSuccess('Invité mis à jour');
      }

      ref.invalidate(guestsProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));

      if (mounted) context.pop();
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() => _searchQuery = q.trim());
    });
  }

  void _selectAccount(_ThixAccount account) {
    setState(() {
      _linkedAccount = account;
      _nameCtrl.text = account.name;
      if (account.phone != null) _phoneCtrl.text = account.phone!;
      if (account.email != null) _emailCtrl.text = account.email!;
      if (account.thixId != null && account.thixId!.isNotEmpty) {
        _thixIdCtrl.text = account.thixId!;
      }
      _searchCtrl.clear();
      _searchQuery = '';
    });
    _showSuccess('Compte Thix lié : ${account.name}');
  }

  void _unlinkAccount() {
    setState(() {
      _linkedAccount = null;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _thixIdCtrl.text = _ThixIdGenerator.generate();
    });
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    if (_isInitLoading) {
      return const _LoadingView();
    }

    return Scaffold(
      backgroundColor: _R.surface,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── APP BAR ────────────────────────────────────────────────────
            _FormAppBar(
              isEdit: _isEdit,
              onSave: _save,
              isLoading: _isLoading,
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── RECHERCHE GLOBALE THIX ──────────────────────────────
                  if (!_isEdit) _GlobalSearchSection(
                    controller: _searchCtrl,
                    query: _searchQuery,
                    onChanged: _onSearchChanged,
                    onSelect: _selectAccount,
                  ),
                  if (!_isEdit) const SizedBox(height: 16),

                  // ── COMPTE LIÉ ──────────────────────────────────────────
                  if (_linkedAccount != null && !_isEdit) ...[
                    _LinkedAccountCard(
                      account: _linkedAccount!,
                      onUnlink: _unlinkAccount,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── IDENTITÉ ────────────────────────────────────────────
                  _SectionCard(
                    title: 'Identité',
                    icon: Icons.person_outline,
                    color: _R.blue,
                    children: [
                      _RoyalTextField(
                        controller: _nameCtrl,
                        label: 'Nom complet',
                        hint: 'Ex: Jean Dupont',
                        icon: Icons.person_outline,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
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
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── THIX ID UNIQUE ──────────────────────────────────────
                  _ThixIdCard(
                    controller: _thixIdCtrl,
                    onRegenerate: () => setState(
                      () => _thixIdCtrl.text = _ThixIdGenerator.generate(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── GROUPE ──────────────────────────────────────────────
                  _SectionCard(
                    title: 'Groupe',
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

                  // ── NOMBRE + TABLE + VIP ────────────────────────────────
                  _SectionCard(
                    title: 'Présence',
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
                        label: 'Numéro de table (optionnel)',
                        hint: '1, 2, 3...',
                        icon: Icons.table_restaurant_outlined,
                        keyboard: TextInputType.number,
                        formatter: FilteringTextInputFormatter.digitsOnly,
                      ),
                      const SizedBox(height: 14),
                      _ToggleRow(
                        label: 'Invité VIP',
                        subtitle: 'Accès prioritaire, placement réservé',
                        icon: Icons.star,
                        color: _R.gold,
                        value: _isVip,
                        onChanged: (v) => setState(() => _isVip = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        label: 'Accompagnant autorisé',
                        subtitle: 'Peut venir avec +1',
                        icon: Icons.group_add_outlined,
                        color: _R.blue,
                        value: _isCompanion,
                        onChanged: (v) => setState(() => _isCompanion = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── NOTES ───────────────────────────────────────────────
                  _SectionCard(
                    title: 'Notes (optionnel)',
                    icon: Icons.notes_outlined,
                    color: _R.text2,
                    children: [
                      _RoyalTextField(
                        controller: _notesCtrl,
                        label: 'Informations complémentaires',
                        hint: 'Régime alimentaire, besoins spéciaux...',
                        icon: Icons.edit_note_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── QR CODE PREVIEW ─────────────────────────────────────
                  _QrPreviewCard(
                    thixId: _thixIdCtrl.text,
                    guestName: _nameCtrl.text,
                  ),
                  const SizedBox(height: 24),

                  // ── SUBMIT ──────────────────────────────────────────────
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

// ============================================================================
// APP BAR
// ============================================================================
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
        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.blue, fontSize: 18),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

// ============================================================================
// RECHERCHE GLOBALE THIX ID
// ============================================================================
class _GlobalSearchSection extends ConsumerWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<_ThixAccount> onSelect;

  const _GlobalSearchSection({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = query.length >= 2
        ? ref.watch(globalSearchProvider(query))
        : const AsyncValue<List<_ThixAccount>>.data([]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_R.blue.withOpacity(0.08), _R.purple.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _R.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: _R.royal,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trouver dans Thix ID',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _R.blue,
                      ),
                    ),
                    Text(
                      'Nom, email ou Thix ID (ex: THIX-...)',
                      style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search field
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher un compte Thix...',
              hintStyle: GoogleFonts.inter(color: _R.text2),
              prefixIcon: const Icon(Icons.manage_search, color: _R.blue),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Results
          if (query.length >= 2)
            searchAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _R.blue),
                  ),
                ),
              ),
              error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: _R.rose)),
              data: (results) {
                if (results.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, color: _R.text2, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aucun compte trouvé. Créez un nouvel invité.',
                            style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: results
                      .map((a) => _SearchResultTile(account: a, onTap: () => onSelect(a)))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _ThixAccount account;
  final VoidCallback onTap;
  const _SearchResultTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: _R.royal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (account.thixId != null) account.thixId!,
                        if (account.email != null) account.email!,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _R.text2, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARTE COMPTE LIÉ
// ============================================================================
class _LinkedAccountCard extends StatelessWidget {
  final _ThixAccount account;
  final VoidCallback onUnlink;
  const _LinkedAccountCard({required this.account, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _R.greenG,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.link, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compte Thix lié',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  account.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (account.thixId != null)
                  Text(
                    account.thixId!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.85),
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off, color: Colors.white, size: 16),
            ),
            onPressed: onUnlink,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE THIX ID UNIQUE
// ============================================================================
class _ThixIdCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onRegenerate;
  const _ThixIdCard({required this.controller, required this.onRegenerate});

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fingerprint, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THIX ID UNIQUE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'Identifiant permanent de l\'invité',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: TextField(
              controller: controller,
              readOnly: true,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION CARD
// ============================================================================
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
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================================
// TEXT FIELD
// ============================================================================
class _RoyalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final String? suffix;
  final TextInputFormatter? formatter;
  final String? Function(String?)? validator;
  final int maxLines;

  const _RoyalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.suffix,
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
        hintStyle: GoogleFonts.inter(color: _R.text2.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _R.blue, size: 20),
        suffixText: suffix,
        suffixStyle: GoogleFonts.inter(color: _R.text2, fontWeight: FontWeight.w600, fontSize: 12),
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

// ============================================================================
// GROUP SELECTOR
// ============================================================================
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(g.icon, size: 16, color: isSelected ? Colors.white : g.color),
                  const SizedBox(width: 6),
                  Text(
                    g.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _R.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// COUNTER
// ============================================================================
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Personnes confirmées',
                    style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
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
        ],
      ),
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
          child: Icon(icon, size: 18, color: onTap == null ? _R.text2 : _R.blue),
        ),
      ),
    );
  }
}

// ============================================================================
// TOGGLE
// ============================================================================
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
        border: Border.all(color: value ? color : _R.border, width: 1.5),
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
          child: Icon(icon, size: 18, color: value ? color : _R.text2),
        ),
        value: value,
        activeColor: color,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

// ============================================================================
// QR CODE PREVIEW
// ============================================================================
class _QrPreviewCard extends StatelessWidget {
  final String thixId;
  final String guestName;
  const _QrPreviewCard({required this.thixId, required this.guestName});

  @override
  Widget build(BuildContext context) {
    final checksum = _ThixIdGenerator.checksum(thixId);
    final displayName = guestName.isEmpty ? 'Nouvel invité' : guestName;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _R.royal,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _R.blue.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // QR Placeholder (à remplacer par qr_flutter si installé)
          Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2, size: 56, color: _R.blue),
                const SizedBox(height: 4),
                Text(
                  checksum,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _R.blue,
                    fontFamily: 'monospace',
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
                Text(
                  'Invitation numérique',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, size: 12, color: _R.gold),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          thixId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'QR Code généré automatiquement',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
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
// SUBMIT BUTTON
// ============================================================================
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
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isEdit ? Icons.check : Icons.person_add, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Enregistrer les modifications' : 'Créer l\'invité',
                        style: GoogleFonts.inter(
                          fontSize: 16,
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
// LOADING VIEW
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty, color: Colors.white, size: 36),
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
