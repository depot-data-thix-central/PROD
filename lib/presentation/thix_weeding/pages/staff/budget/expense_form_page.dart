// lib/presentation/thix_weeding/pages/staff/budget/expense_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TES 3 FICHIERS CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editExpenseId;
  const ExpenseFormPage({super.key, required this.weddingId, this.editExpenseId});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  // FORM
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // STATE
  String? _vendorId;
  bool _isPaid = false;
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
    super.dispose();
  }

  // ================= DATA =================

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
      _amountCtrl.text = expense.amount.toStringAsFixed(0);
      _vendorId = expense.vendorId;
      _isPaid = expense.isPaid;
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement: $e')));
      }
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'wedding_id': widget.weddingId,
        'vendor_id': _vendorId,
        'title': _titleCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text),
        'category': 'general', // tu peux ajouter un select category si besoin
        'is_paid': _isPaid,
      };

      if (!_isEdit) {
        await ref.read(budgetServiceProvider).createExpense(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dépense créée')));
      } else {
        await Supabase.instance.client.from('thix_weeding_expenses').update(data).eq('id', widget.editExpenseId!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dépense mise à jour')));
      }

      // Refresh les providers centraux
      ref.invalidate(expensesProvider(widget.weddingId));
      ref.invalidate(budgetProvider(widget.weddingId));
      ref.invalidate(paymentsSummaryProvider(widget.weddingId));

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));

    if (_isInitLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Chargement...')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier dépense' : 'Ajouter dépense'),
        backgroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              title: 'Informations',
              children: [
                _buildTitleField(),
                const SizedBox(height: 16),
                _buildAmountField(),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Liaison',
              children: [
                _buildVendorDropdown(vendorsAsync),
                const SizedBox(height: 16),
                _buildPaidSwitch(),
              ],
            ),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() => TextFormField(
        controller: _titleCtrl,
        decoration: const InputDecoration(
          labelText: 'Titre *',
          hintText: 'Ex: Acompte traiteur',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.title),
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Titre requis' : null,
      );

  Widget _buildAmountField() => TextFormField(
        controller: _amountCtrl,
        decoration: const InputDecoration(
          labelText: 'Montant FCFA *',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.payments_outlined),
        ),
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Montant requis';
          if (double.tryParse(v) == null) return 'Nombre invalide';
          return null;
        },
      );

  Widget _buildVendorDropdown(AsyncValue<List<VendorModel>> vendorsAsync) {
    return vendorsAsync.when(
      loading: () => const DropdownButtonFormField<String>(
        items: [],
        onChanged: null,
        decoration: InputDecoration(labelText: 'Prestataire (chargement...)', border: OutlineInputBorder()),
      ),
      error: (e, s) => DropdownButtonFormField<String>(
        value: _vendorId,
        items: const [],
        onChanged: (v) => setState(() => _vendorId = v),
        decoration: const InputDecoration(labelText: 'Prestataire (optionnel)', border: OutlineInputBorder()),
      ),
      data: (vendors) {
        return DropdownButtonFormField<String>(
          value: _vendorId,
          decoration: const InputDecoration(
            labelText: 'Prestataire lié (optionnel)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.storefront),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sans prestataire')),
            ...vendors.map((VendorModel v) => DropdownMenuItem(value: v.id, child: Text(v.name))),
          ],
          onChanged: (v) => setState(() => _vendorId = v),
        );
      },
    );
  }

  Widget _buildPaidSwitch() => Container(
        decoration: BoxDecoration(color: _isPaid ? Colors.green.withOpacity(0.08) : Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _isPaid ? Colors.green : Colors.grey.shade300)),
        child: SwitchListTile(
          title: const Text('Déjà payé ?', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(_isPaid ? 'Sera compté dans dépensé' : 'Reste à payer'),
          value: _isPaid,
          activeColor: Colors.green,
          onChanged: (v) => setState(() => _isPaid = v),
        ),
      );

  Widget _buildSubmitButton() => FilledButton(
        onPressed: _isLoading ? null : _save,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_isEdit ? 'Mettre à jour' : 'Créer dépense', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );
}

// Petit widget interne pour lisibilité
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 16),
          ...children,
        ]),
      );
}
