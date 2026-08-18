// lib/presentation/thix_money/pages/recharge_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/payment_service.dart';
import '../utils/constants.dart';

class RechargePage extends ConsumerStatefulWidget {
  const RechargePage({super.key});
  @override
  ConsumerState<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends ConsumerState<RechargePage> {
  final _phone = TextEditingController(); final _montant = TextEditingController();
  String _devise = 'CDF'; bool _loading = false;
  final _payment = PaymentService();

  Future<void> _submit() async {
    if (_montant.text.isEmpty || _phone.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final ref = await _payment.recharge(montant: int.parse(_montant.text), devise: _devise, phone: _phone.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recharge lancée: $ref - THIX_ID vérifié'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Recharger')), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    SegmentedButton<String>(segments: const [ButtonSegment(value: 'CDF', label: Text('CDF')), ButtonSegment(value: 'USD', label: Text('USD'))], selected: {_devise}, onSelectionChanged: (s) => setState(() => _devise = s.first)),
    const SizedBox(height: 16),
    TextField(controller: _phone, decoration: InputDecoration(labelText: 'Numéro Mobile Money', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.phone),
    const SizedBox(height: 12),
    TextField(controller: _montant, decoration: InputDecoration(labelText: 'Montant', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _loading ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: ThixConstants.primary), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmer recharge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
  ])));
}
