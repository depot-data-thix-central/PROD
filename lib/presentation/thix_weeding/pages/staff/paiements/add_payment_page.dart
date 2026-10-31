// lib/presentation/thix_weeding/pages/staff/paiements/add_payment_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — ADD PAYMENT (PRODUCTION)
// Design royal + Sélecteurs visuels + Dropdowns enrichis + Validation
// Branché sur providers EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
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
// MÉTHODES DE PAIEMENT
// ============================================================================
const List<_PayMethod> _METHODS = [
  _PayMethod('mobile_money', 'Mobile Money', Icons.phone_android, Color(0xFFD97706)),
  _PayMethod('cash', 'Espèces', Icons.money, Color(0xFF059669)),
  _PayMethod('bank', 'Virement bancaire', Icons.account_balance, Color(0xFF0B3B8F)),
  _PayMethod('card', 'Carte bancaire', Icons.credit_card, Color(0xFF6B46C1)),
  _PayMethod('check', 'Chèque', Icons.receipt_long, Color(0xFF78716C)),
];

class _PayMethod {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _PayMethod(this.value, this.label, this.icon, this.color);
}

_PayMethod _findMethod(String v) =>
    _METHODS.firstWhere((m) => m.value == v, orElse: () => _METHODS[0]);

// ============================================================================
// STATUTS PAIEMENT
// ============================================================================
const List<_PayStatus> _STATUSES = [
  _PayStatus('pending', 'En attente', Icons.pending, Color(0xFFD97706)),
  _PayStatus('completed', 'Complété', Icons.check_circle, Color(0xFF059669)),
  _PayStatus('failed', 'Échoué', Icons.error_outline, Color(0xFFE31C4E)),
  _PayStatus('refunded', 'Remboursé', Icons.undo, Color(0xFF6B7280)),
];

class _PayStatus {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _PayStatus(this.value, this.label, this.icon, this.color);
}

_PayStatus _findStatus(String v) =>
    _STATUSES.firstWhere((s) => s.value == v, orElse: () => _STATUSES[0]);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class AddPaymentPage extends ConsumerStatefulWidget {
  final String weddingId;
  const AddPaymentPage({super.key, required this.weddingId});

  @override
  ConsumerState<AddPaymentPage> createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends ConsumerState<AddPaymentPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCodeCtrl = TextEditingController();

  String _method = 'mobile_money';
  String _status = 'pending';
  String? _vendorId;
  String? _expenseId;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCodeCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // SAVE
  // ============================================================================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amountText = _amountCtrl.text.replaceAll(RegExp(r'\D'), '');
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        if (mounted) _showError('Montant invalide');
        return;
      }

      final inserted = await Supabase.instance.client
          .from('thix_weeding_payments')
          .insert({
            'wedding_id': widget.weddingId,
            'vendor_id': _vendorId,
            'expense_id': _expenseId,
            'amount': amount,
            'method': _method,
            'status': _status,
            'reference_code': _refCodeCtrl.text.trim().isEmpty ? null : _refCodeCtrl.text.trim(),
          })
          .select()
          .single();

      ref.invalidate(paymentsProvider(widget.weddingId));
      ref.invalidate(expensesProvider(widget.weddingId));
      ref.invalidate(paymentsSummaryProvider(widget.weddingId));

      if (mounted) {
        _showSuccess('Paiement créé • ID: ${(inserted['id'] as String).substring(0, 8)} ✓');
        context.pop();
      }
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));
    final expensesAsync = ref.watch(expensesProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── APP BAR ──────────────────────────────────────────────
              _FormAppBar(onSave: _save, isLoading: _isLoading),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── MONTANT ────────────────────────────────────────
                    _SectionCard(
                      title: 'Montant du paiement',
                      icon: Icons.payments_outlined,
                      color: _R.green,
                      children: [
                        _AmountField(controller: _amountCtrl),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── LIAISONS ───────────────────────────────────────
                    _SectionCard(
                      title: 'Liaisons (optionnel)',
                      icon: Icons.link_outlined,
                      color: _R.purple,
                      children: [
                        _VendorDropdown(
                          vendorsAsync: vendorsAsync,
                          selected: _vendorId,
                          onChanged: (v) => setState(() => _vendorId = v),
                        ),
                        const SizedBox(height: 14),
                        _ExpenseDropdown(
                          expensesAsync: expensesAsync,
                          selected: _expenseId,
                          onChanged: (v) => setState(() => _expenseId = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── MÉTHODE DE PAIEMENT ────────────────────────────
                    _SectionCard(
                      title: 'Méthode de paiement',
                      icon: Icons.account_balance_wallet_outlined,
                      color: _R.gold,
                      children: [
                        _MethodSelector(
                          selected: _method,
                          onChanged: (m) => setState(() => _method = m),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── STATUT ─────────────────────────────────────────
                    _SectionCard(
                      title: 'Statut',
                      icon: Icons.flag_outlined,
                      color: _R.blue,
                      children: [
                        _StatusSelector(
                          selected: _status,
                          onChanged: (s) => setState(() => _status = s),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── RÉFÉRENCE ──────────────────────────────────────
                    _SectionCard(
                      title: 'Référence transaction',
                      icon: Icons.tag_outlined,
                      color: _R.text2,
                      children: [
                        _RoyalTextField(
                          controller: _refCodeCtrl,
                          label: 'Code de référence (optionnel)',
                          hint: 'Ex: TXN-2026-001234',
                          icon: Icons.fingerprint_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── BOUTON SOUMETTRE ───────────────────────────────
                    _SubmitButton(isLoading: _isLoading, onTap: _save),

                    // ── NOTE INFO ──────────────────────────────────────
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_R.blue.withOpacity(0.06), _R.purple.withOpacity(0.06)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _R.blue.withOpacity(0.15)),
                      ),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _R.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.info_outline, color: _R.blue, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Un ID UUID unique sera généré automatiquement pour ce paiement. Le résumé financier sera mis à jour en temps réel.',
                            style: GoogleFonts.inter(fontSize: 11, color: _R.blue, height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                  ]),
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
// APP BAR
// ============================================================================
class _FormAppBar extends StatelessWidget {
  final VoidCallback onSave;
  final bool isLoading;

  const _FormAppBar({required this.onSave, required this.isLoading});

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
        'Nouveau paiement',
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
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('Créer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
              ),
            ),
          ),
        ),
      ],
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

  const _SectionCard({required this.title, required this.icon, required this.color, required this.children});

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
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================================
// AMOUNT FIELD (grand format)
// ============================================================================
class _AmountField extends StatelessWidget {
  final TextEditingController controller;

  const _AmountField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: _R.green),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: _R.border),
        suffixText: 'FCFA',
        suffixStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _R.text2),
        filled: true,
        fillColor: _R.green.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _R.green.withOpacity(0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _R.green.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _R.green, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _R.rose)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Montant requis';
        final cleaned = v.replaceAll(RegExp(r'\D'), '');
        final amount = double.tryParse(cleaned);
        if (amount == null || amount <= 0) return 'Montant invalide';
        return null;
      },
    );
  }
}

// ============================================================================
// VENDOR DROPDOWN
// ============================================================================
class _VendorDropdown extends StatelessWidget {
  final AsyncValue<List<VendorModel>> vendorsAsync;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _VendorDropdown({required this.vendorsAsync, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return vendorsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: _R.border), borderRadius: BorderRadius.circular(12)),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const Text('Erreur chargement prestataires', style: TextStyle(color: _R.rose)),
      data: (vendors) {
        return DropdownButtonFormField<String>(
          value: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Prestataire lié (optionnel)',
            labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
            prefixIcon: const Icon(Icons.storefront_outlined, color: _R.purple),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.purple, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          dropdownColor: Colors.white,
          style: GoogleFonts.inter(fontSize: 14, color: _R.text),
          items: [
            DropdownMenuItem<String>(value: null, child: Text('Aucun prestataire', style: GoogleFonts.inter(color: _R.text2))),
            ...vendors.map((v) => DropdownMenuItem<String>(
                  value: v.id,
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _R.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.store, size: 12, color: _R.purple)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (v.price != null && v.price! > 0)
                      Text('${_fmtMoneyShort(v.price!)} FCFA', style: GoogleFonts.inter(fontSize: 10, color: _R.text2)),
                  ]),
                )),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

// ============================================================================
// EXPENSE DROPDOWN
// ============================================================================
class _ExpenseDropdown extends StatelessWidget {
  final AsyncValue<List<ExpenseModel>> expensesAsync;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ExpenseDropdown({required this.expensesAsync, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return expensesAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: _R.border), borderRadius: BorderRadius.circular(12)),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const Text('Erreur chargement dépenses', style: TextStyle(color: _R.rose)),
      data: (expenses) {
        return DropdownButtonFormField<String>(
          value: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Dépense liée (optionnel)',
            labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
            prefixIcon: const Icon(Icons.receipt_long_outlined, color: _R.amber),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.amber, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          dropdownColor: Colors.white,
          style: GoogleFonts.inter(fontSize: 14, color: _R.text),
          items: [
            DropdownMenuItem<String>(value: null, child: Text('Aucune dépense', style: GoogleFonts.inter(color: _R.text2))),
            ...expenses.map((e) => DropdownMenuItem<String>(
                  value: e.id,
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _R.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.receipt, size: 12, color: _R.amber)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${_fmtMoneyShort(e.amount)} FCFA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: e.isPaid ? _R.green : _R.amber)),
                  ]),
                )),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

// ============================================================================
// METHOD SELECTOR (Grid visuelle)
// ============================================================================
class _MethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _MethodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _METHODS.map((m) {
        final isSelected = m.value == selected;
        return Material(
          color: isSelected ? m.color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(m.value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? m.color : _R.border, width: isSelected ? 2 : 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(m.icon, size: 18, color: isSelected ? Colors.white : m.color),
                const SizedBox(width: 8),
                Text(m.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _R.text)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// STATUS SELECTOR (Row visuelle)
// ============================================================================
class _StatusSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _STATUSES.map((s) {
        final isSelected = s.value == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: isSelected ? s.color : Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onChanged(s.value),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? s.color : _R.border, width: isSelected ? 1.5 : 1),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.icon, size: 18, color: isSelected ? Colors.white : s.color),
                    const SizedBox(height: 4),
                    Text(s.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _R.text)),
                  ]),
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
// TEXT FIELD ROYAL
// ============================================================================
class _RoyalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _RoyalTextField({required this.controller, required this.label, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: _R.text2.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _R.blue, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ============================================================================
// SUBMIT BUTTON
// ============================================================================
class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isLoading ? null : _R.greenG,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading ? null : [BoxShadow(color: _R.green.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: isLoading ? _R.border : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_card, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text('Créer le paiement', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtMoneyShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.round().toString();
}
