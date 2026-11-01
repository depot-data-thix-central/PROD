// lib/presentation/thix_weeding/pages/staff/budget/expense_form_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — EXPENSE FORM (PRODUCTION v2 — USD + ÉQUILIBRÉ)
// ✅ Devise USD ($) partout (décimal autorisé)
// ✅ Les paiements partiels créent un PaymentModel → équilibre le budget
// ✅ Mode édition : recharge les paiements existants
// ✅ FIX : nullable category, Supabase Storage API, balancedSummaryProvider
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

// 12 catégories
const List<_Cat> _CATEGORIES = [
  _Cat('salle', 'Salle', Icons.place_outlined, Color(0xFF0B3B8F)),
  _Cat('decoration', 'Décoration', Icons.auto_awesome, Color(0xFFFF6B9D)),
  _Cat('traiteur', 'Traiteur', Icons.restaurant, Color(0xFFD97706)),
  _Cat('boissons', 'Boissons', Icons.local_bar, Color(0xFF7C3AED)),
  _Cat('photographie', 'Photographie', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  _Cat('videographie', 'Vidéographie', Icons.videocam_outlined, Color(0xFF059669)),
  _Cat('musique', 'Musique & DJ', Icons.music_note, Color(0xFFDB2777)),
  _Cat('tenues', 'Tenues', Icons.checkroom, Color(0xFF0891B2)),
  _Cat('maquillage', 'Maquillage', Icons.auto_fix_high, Color(0xFFBE185D)),
  _Cat('transport', 'Transport', Icons.directions_car, Color(0xFF4338CA)),
  _Cat('hebergement', 'Hébergement', Icons.hotel, Color(0xFF92400E)),
  _Cat('divers', 'Divers', Icons.category_outlined, Color(0xFF64748B)),
];

class _Cat {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.key, this.label, this.icon, this.color);

  static _Cat find(String key) =>
      _CATEGORIES.firstWhere((c) => c.key == key, orElse: () => _CATEGORIES.last);
}

/// Formatter décimal USD : autorise chiffres + 1 point décimal + 2 décimales max
class _UsdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text.replaceAll(',', '.');
    // Autorise vide, chiffres, et un seul point
    if (t.isEmpty) return newValue.copyWith(text: t);
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(t)) return oldValue;
    return newValue.copyWith(text: t);
  }
}

// ============================================================================
// PAGE
// ============================================================================
class ExpenseFormPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editExpenseId;

  const ExpenseFormPage({super.key, required this.weddingId, this.editExpenseId});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  // Form
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // State
  String? _vendorId;
  String _category = 'divers';
  bool _isPaid = false;
  bool _partialPayment = false;
  DateTime _expenseDate = DateTime.now();
  Uint8List? _receiptImage;
  String? _receiptFileName;

  // Paiements déjà enregistrés pour cette dépense (en mode édition)
  double _existingPayments = 0.0;

  bool _isLoading = false;
  bool _isInitLoading = false;

  bool get _isEdit => widget.editExpenseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExpenseForEdit();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _paidAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // DATA
  // ============================================================================
  Future<void> _loadExpenseForEdit() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('thix_weeding_expenses')
          .select()
          .eq('id', widget.editExpenseId!)
          .single();
      final expense = ExpenseModel.fromJson(data);
      _titleCtrl.text = expense.title;
      _amountCtrl.text = expense.amount.toString();
      _vendorId = expense.vendorId;
      // ✅ FIX : gestion du nullable category
      _category = (expense.category?.isNotEmpty ?? false) ? expense.category! : 'divers';
      _isPaid = expense.isPaid;

      // Charger paiements déjà enregistrés pour cette dépense
      try {
        final existing = await Supabase.instance.client
            .from('thix_weeding_payments')
            .select('amount, status')
            .eq('expense_id', expense.id);
        _existingPayments = List<Map<String, dynamic>>.from(existing)
            .where((p) => p['status'] == 'completed')
            .fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble());
        if (_existingPayments > 0) {
          _partialPayment = true;
          _paidAmountCtrl.text = _existingPayments.toString();
        }
      } catch (_) {}

      setState(() {});
    } catch (e) {
      if (mounted) _showError('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final totalAmount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
      final paidAmount = _partialPayment && _paidAmountCtrl.text.isNotEmpty
          ? double.parse(_paidAmountCtrl.text.replaceAll(',', '.'))
          : (_isPaid ? totalAmount : 0.0);

      final data = {
        'wedding_id': widget.weddingId,
        'vendor_id': _vendorId,
        'title': _titleCtrl.text.trim(),
        'amount': totalAmount,
        'category': _category,
        'is_paid': paidAmount >= totalAmount,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'expense_date': _expenseDate.toIso8601String().split('T')[0],
      };

      String? receiptUrl;
      if (_receiptImage != null) {
        receiptUrl = await _uploadReceipt();
        data['receipt_url'] = receiptUrl;
      }

      String expenseId;
      if (!_isEdit) {
        final created = await Supabase.instance.client
            .from('thix_weeding_expenses')
            .insert(data)
            .select()
            .single();
        expenseId = created['id'] as String;
      } else {
        await Supabase.instance.client
            .from('thix_weeding_expenses')
            .update(data)
            .eq('id', widget.editExpenseId!);
        expenseId = widget.editExpenseId!;
      }

      // ─── Création/mise à jour du PaymentModel (équilibrage comptable) ───
      if (paidAmount > 0) {
        await _upsertPayment(
          expenseId: expenseId,
          title: _titleCtrl.text.trim(),
          amount: paidAmount,
          vendorId: _vendorId,
        );
      } else if (_isEdit && _existingPayments > 0) {
        // Si l'utilisateur passe de payée → impayée, on supprime les paiements
        await Supabase.instance.client
            .from('thix_weeding_payments')
            .delete()
            .eq('expense_id', expenseId);
      }

      // Refresh providers
      ref.invalidate(expensesProvider(widget.weddingId));
      ref.invalidate(paymentsProvider(widget.weddingId));
      ref.invalidate(budgetProvider(widget.weddingId));
      // ✅ FIX : balancedSummaryProvider commenté (n'existe pas dans ce scope)
      // ref.invalidate(balancedSummaryProvider(widget.weddingId));

      _showSuccess(_isEdit
          ? 'Dépense mise à jour (${_fmtUsd(paidAmount)} payé)'
          : 'Dépense créée — ${_fmtUsd(paidAmount)} décaissé');

      if (mounted) context.pop();
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Crée ou met à jour un PaymentModel lié à la dépense
  /// → Le balancedSummaryProvider le compte dans "Payé"
  Future<void> _upsertPayment({
    required String expenseId,
    required String title,
    required double amount,
    String? vendorId,
  }) async {
    // Cherche un paiement existant pour cette dépense
    final existing = await Supabase.instance.client
        .from('thix_weeding_payments')
        .select('id')
        .eq('expense_id', expenseId)
        .maybeSingle();

    final row = {
      'wedding_id': widget.weddingId,
      'title': 'Paiement : $title',
      'amount': amount,
      'status': 'completed',
      'method': 'cash',
      'expense_id': expenseId,
      'vendor_id': vendorId,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (existing == null) {
      await Supabase.instance.client.from('thix_weeding_payments').insert(row);
    } else {
      await Supabase.instance.client
          .from('thix_weeding_payments')
          .update(row)
          .eq('id', existing['id']);
    }
  }

  Future<String?> _uploadReceipt() async {
    if (_receiptImage == null) return null;
    try {
      final fileName =
          '${widget.weddingId}/${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';
      // ✅ FIX : Supabase.instance.client.storage au lieu de Supabase.instance.storage
      await Supabase.instance.client.storage.from('thix-wedding-receipts').uploadBinary(
            fileName,
            _receiptImage!,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );
      // ✅ FIX : Supabase.instance.client.storage au lieu de Supabase.instance.storage
      return Supabase.instance.client.storage
          .from('thix-wedding-receipts')
          .getPublicUrl(fileName);
    } catch (e) {
      _showError('Erreur upload justificatif: $e');
      return null;
    }
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _receiptImage = bytes;
        _receiptFileName = image.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Date de la dépense',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _R.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _R.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _expenseDate) {
      setState(() => _expenseDate = picked);
    }
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Format USD simple (pour toasts/retours)
  String _fmtUsd(double v) {
    final neg = v < 0;
    final abs = v.abs();
    final whole = abs.floor();
    final cents = ((abs - whole) * 100).round();
    final s = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    final cStr = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
    return '${neg ? '-' : ''}\$$buf$cStr';
  }

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));

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
                  // ── INFORMATIONS ────────────────────────────────────────
                  _SectionCard(
                    title: 'Informations',
                    icon: Icons.info_outline,
                    color: _R.blue,
                    children: [
                      _RoyalTextField(
                        controller: _titleCtrl,
                        label: 'Titre de la dépense',
                        hint: 'Ex: Acompte traiteur',
                        icon: Icons.title_outlined,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Titre requis' : null,
                      ),
                      const SizedBox(height: 16),
                      _RoyalTextField(
                        controller: _amountCtrl,
                        label: 'Montant total (USD)',
                        hint: '3500.00',
                        icon: Icons.payments_outlined,
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        suffix: 'USD \$',
                        formatter: _UsdInputFormatter(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Montant requis';
                          final parsed = double.tryParse(v.replaceAll(',', '.'));
                          if (parsed == null) return 'Nombre invalide';
                          if (parsed <= 0) return 'Montant doit être > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _DatePickerField(date: _expenseDate, onTap: _pickDate),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── CATÉGORIE ───────────────────────────────────────────
                  _SectionCard(
                    title: 'Catégorie',
                    icon: Icons.category_outlined,
                    color: _R.gold,
                    children: [
                      _CategorySelector(
                        selected: _category,
                        onChanged: (cat) => setState(() => _category = cat),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── PRESTATAIRE ─────────────────────────────────────────
                  _SectionCard(
                    title: 'Prestataire',
                    icon: Icons.storefront_outlined,
                    color: _R.purple,
                    children: [
                      _VendorDropdown(
                        vendorsAsync: vendorsAsync,
                        selected: _vendorId,
                        onChanged: (v) => setState(() => _vendorId = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── PAIEMENT ────────────────────────────────────────────
                  _SectionCard(
                    title: 'Statut de paiement',
                    icon: Icons.account_balance_wallet_outlined,
                    color: _R.green,
                    children: [
                      _PaymentToggle(
                        isPaid: _isPaid,
                        onChanged: (v) => setState(() {
                          _isPaid = v;
                          if (!v) _paidAmountCtrl.clear();
                        }),
                      ),
                      if (_isPaid) ...[
                        const SizedBox(height: 16),
                        _PartialPaymentToggle(
                          enabled: _partialPayment,
                          onChanged: (v) => setState(() {
                            _partialPayment = v;
                            if (!v) _paidAmountCtrl.clear();
                          }),
                        ),
                        if (_partialPayment) ...[
                          const SizedBox(height: 16),
                          _RoyalTextField(
                            controller: _paidAmountCtrl,
                            label: 'Montant déjà payé (USD)',
                            hint: '2000.00',
                            icon: Icons.check_circle_outline,
                            keyboard: const TextInputType.numberWithOptions(decimal: true),
                            suffix: 'USD \$',
                            formatter: _UsdInputFormatter(),
                            validator: (v) {
                              if (_partialPayment && (v == null || v.isEmpty)) {
                                return 'Montant payé requis';
                              }
                              if (v != null && v.isNotEmpty) {
                                final paid = double.tryParse(v.replaceAll(',', '.'));
                                final total =
                                    double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
                                if (paid == null) return 'Nombre invalide';
                                if (total != null && paid > total) {
                                  return 'Montant payé > montant total';
                                }
                              }
                              return null;
                            },
                          ),
                          // Indicateur visuel du pourcentage payé
                          if (_paidAmountCtrl.text.isNotEmpty &&
                              _amountCtrl.text.isNotEmpty)
                            Builder(builder: (_) {
                              final paid = double.tryParse(
                                      _paidAmountCtrl.text.replaceAll(',', '.')) ??
                                  0;
                              final total = double.tryParse(
                                      _amountCtrl.text.replaceAll(',', '.')) ??
                                  1;
                              final ratio = (paid / total).clamp(0.0, 1.0);
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Progression',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _R.text2)),
                                        Text('${(ratio * 100).toStringAsFixed(1)}%',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: _R.blue)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        minHeight: 5,
                                        value: ratio,
                                        backgroundColor: _R.border,
                                        valueColor:
                                            const AlwaysStoppedAnimation(_R.green),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Reste à payer : ${_fmtUsd((total - paid).clamp(0, double.infinity))}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: _R.rose,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── JUSTIFICATIF ────────────────────────────────────────
                  _SectionCard(
                    title: 'Justificatif',
                    icon: Icons.receipt_long_outlined,
                    color: _R.rose,
                    children: [
                      _ReceiptUploader(
                        image: _receiptImage,
                        fileName: _receiptFileName,
                        onPick: _pickReceipt,
                        onRemove: () => setState(() {
                          _receiptImage = null;
                          _receiptFileName = null;
                        }),
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
                        label: 'Notes',
                        hint: 'Informations complémentaires...',
                        icon: Icons.edit_note_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

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
      title: Text(
        isEdit ? 'Modifier dépense' : 'Nouvelle dépense',
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w800, color: _R.blue, fontSize: 18),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => context.pop(),
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            isEdit ? 'Mettre à jour' : 'Créer',
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
// TEXT FIELD ROYAL
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
        suffixStyle: GoogleFonts.inter(
            color: _R.text2, fontWeight: FontWeight.w600, fontSize: 12),
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
// DATE PICKER
// ============================================================================
class _DatePickerField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: _R.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: _R.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date de la dépense',
                      style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _R.text2),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CATEGORY SELECTOR
// ============================================================================
class _CategorySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _CATEGORIES.length,
      itemBuilder: (context, index) {
        final cat = _CATEGORIES[index];
        final isSelected = cat.key == selected;
        return Material(
          color: isSelected ? cat.color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(cat.key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? cat.color : _R.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? cat.color : cat.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      cat.icon,
                      color: isSelected ? Colors.white : cat.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? cat.color : _R.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
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

  const _VendorDropdown({
    required this.vendorsAsync,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return vendorsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _R.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: _R.rose)),
      data: (vendors) {
        return DropdownButtonFormField<String>(
          value: selected,
          decoration: InputDecoration(
            labelText: 'Prestataire lié (optionnel)',
            labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
            prefixIcon: const Icon(Icons.storefront_outlined, color: _R.blue),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          dropdownColor: Colors.white,
          style: GoogleFonts.inter(fontSize: 14, color: _R.text),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Sans prestataire',
                  style: GoogleFonts.inter(color: _R.text2)),
            ),
            ...vendors.map((v) => DropdownMenuItem<String>(
                  value: v.id,
                  child: Row(
                    children: [
                      Icon(Icons.store_outlined, size: 16, color: _R.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(v.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

// ============================================================================
// PAYMENT TOGGLE
// ============================================================================
class _PaymentToggle extends StatelessWidget {
  final bool isPaid;
  final ValueChanged<bool> onChanged;

  const _PaymentToggle({required this.isPaid, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isPaid ? _R.green.withOpacity(0.1) : _R.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid ? _R.green : _R.amber,
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Déjà payé ?',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isPaid ? _R.green : _R.amber,
          ),
        ),
        subtitle: Text(
          isPaid
              ? 'Sera compté dans le total décaissé'
              : 'Reste à payer (dette prestataire)',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isPaid ? _R.green : _R.amber,
          ),
        ),
        value: isPaid,
        activeColor: _R.green,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

// ============================================================================
// PARTIAL PAYMENT TOGGLE
// ============================================================================
class _PartialPaymentToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PartialPaymentToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: enabled ? _R.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enabled ? _R.blue : _R.border),
      ),
      child: SwitchListTile(
        title: Text(
          'Paiement partiel',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? _R.blue : _R.text2,
          ),
        ),
        subtitle: Text(
          'Précisez le montant déjà versé (créera un enregistrement de paiement)',
          style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
        ),
        value: enabled,
        activeColor: _R.blue,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

// ============================================================================
// RECEIPT UPLOADER
// ============================================================================
class _ReceiptUploader extends StatelessWidget {
  final Uint8List? image;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ReceiptUploader({
    this.image,
    this.fileName,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: _R.border, width: 2, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _R.rose.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: _R.rose, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ajouter un justificatif',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Photo de facture ou reçu',
                  style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _R.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _R.green),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              image!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName ?? 'justificatif.jpg',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Justificatif ajouté',
                  style: GoogleFonts.inter(fontSize: 11, color: _R.green),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: _R.rose),
            onPressed: onRemove,
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
                    child:
                        CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isEdit ? Icons.check : Icons.add,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Mettre à jour la dépense' : 'Créer la dépense',
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
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2),
            ),
          ],
        ),
      ),
    );
  }
}
