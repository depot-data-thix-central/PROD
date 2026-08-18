// lib/presentation/thix_weeding/pages/staff/paiements/add_payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class AddPaymentPage extends ConsumerStatefulWidget {
  final String weddingId;
  const AddPaymentPage({super.key, required this.weddingId});

  @override
  ConsumerState<AddPaymentPage> createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends ConsumerState<AddPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCodeCtrl = TextEditingController();

  String _method = 'mobile_money';
  String _status = 'pending';
  String? _vendorId;
  String? _expenseId;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final inserted = await Supabase.instance.client
          .from('thix_weeding_payments')
          .insert({
            'wedding_id': widget.weddingId,
            'vendor_id': _vendorId,
            'expense_id': _expenseId,
            'amount': double.parse(_amountCtrl.text),
            'method': _method,
            'status': _status,
            'reference_code': _refCodeCtrl.text.trim().isEmpty
                ? null
                : _refCodeCtrl.text.trim(),
          })
          .select()
          .single();

      ref.invalidate(paymentsProvider(widget.weddingId));
      ref.invalidate(expensesProvider(widget.weddingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Paiement créé ID: ${inserted['id'].toString().substring(0, 8)}',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));
    final expensesAsync = ref.watch(expensesProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Nouveau paiement'),
        backgroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Montant',
              children: [
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Montant FCFA *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requis' : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Liaisons',
              children: [
                vendorsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Erreur vendors'),
                  data: (List<VendorModel> vendors) =>
                      DropdownButtonFormField<String>(
                    value: _vendorId,
                    decoration: const InputDecoration(
                      labelText: 'Prestataire (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    items: vendors
                        .map(
                          (v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(v.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _vendorId = v),
                  ),
                ),
                const SizedBox(height: 12),
                expensesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Erreur expenses'),
                  data: (List<ExpenseModel> expenses) =>
                      DropdownButtonFormField<String>(
                    value: _expenseId,
                    decoration: const InputDecoration(
                      labelText: 'Dépense liée (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    items: expenses
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.title),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _expenseId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Détails',
              children: [
                DropdownButtonFormField<String>(
                  value: _method,
                  decoration: const InputDecoration(
                    labelText: 'Méthode',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'mobile_money',
                      child: Text('Mobile Money'),
                    ),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'bank',
                      child: Text('Virement bancaire'),
                    ),
                    DropdownMenuItem(value: 'card', child: Text('Carte')),
                  ],
                  onChanged: (v) => setState(() => _method = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('En attente'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Complété'),
                    ),
                    DropdownMenuItem(
                      value: 'failed',
                      child: Text('Échoué'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Référence / Code transaction',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Créer paiement avec ID unique',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Color(0xFF0B3B8F),
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}
