// ============================================================
// FICHIER 24 : admin/admin_budget_form_page.dart
// ============================================================
// lib/presentation/mon_pays/admin/admin_budget_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/province_budget.dart';
import '../providers/provinces_provider.dart';

class AdminBudgetFormPage extends ConsumerStatefulWidget {
  final String provinceId;
  final ProvinceBudgetPriority? budget;
  const AdminBudgetFormPage({required this.provinceId, this.budget, super.key});

  @override
  ConsumerState<AdminBudgetFormPage> createState() => _AdminBudgetFormPageState();
}

class _AdminBudgetFormPageState extends ConsumerState<AdminBudgetFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _yearController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _pdfUrlController;
  bool _isEditing = false;
  String? _budgetId;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _isEditing = b != null;
    _budgetId = b?.id;
    _titleController = TextEditingController(text: b?.title ?? '');
    _yearController = TextEditingController(text: b?.year.toString() ?? DateTime.now().year.toString());
    _descriptionController = TextEditingController(text: b?.description ?? '');
    _amountController = TextEditingController(text: b?.allocatedAmount?.toString() ?? '');
    _pdfUrlController = TextEditingController(text: b?.pdfUrl ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _pdfUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la priorité budgétaire' : 'Ajouter une priorité budgétaire'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titre *'),
                  validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _yearController,
                  decoration: const InputDecoration(labelText: 'Année *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Montant alloué (USD)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pdfUrlController,
                  decoration: const InputDecoration(labelText: 'URL du PDF (plan de développement)'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isEditing ? 'Modifier' : 'Ajouter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final budget = ProvinceBudgetPriority(
      id: _budgetId ?? '',
      provinceId: widget.provinceId,
      year: int.parse(_yearController.text.trim()),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      allocatedAmount: double.tryParse(_amountController.text.trim()),
      pdfUrl: _pdfUrlController.text.trim().isEmpty ? null : _pdfUrlController.text.trim(),
    );
    final service = ref.read(provincesServiceProvider);
    try {
      if (_isEditing) {
        await service.updateBudgetPriority(budget);
      } else {
        await service.addBudgetPriority(budget);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Priorité budgétaire enregistrée'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
