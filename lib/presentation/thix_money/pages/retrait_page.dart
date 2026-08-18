// lib/presentation/thix_money/pages/retrait_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';
import '../utils/validators.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import '../providers/wallet_provider.dart';

class RetraitPage extends ConsumerStatefulWidget {
  const RetraitPage({super.key});
  @override
  ConsumerState<RetraitPage> createState() => _RetraitPageState();
}

class _RetraitPageState extends ConsumerState<RetraitPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  String _devise = 'CDF';
  bool _loading = false;
  final _payment = PaymentService();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final wallet = await ref.read(walletStreamProvider.future);
      final montant = int.parse(_amount.text.replaceAll(RegExp(r'\D'), ''));
      if (_devise == 'CDF' && montant > wallet.soldeCdf) throw Exception('Solde insuffisant CDF');
      if (_devise == 'USD' && montant > wallet.soldeUsd) throw Exception('Solde insuffisant USD');

      final refTransa = await _payment.retrait(montant: montant, devise: _devise, phone: _phone.text);
      if (!mounted) return;
      showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle, color: Colors.green, size: 64), const SizedBox(height: 12), Text('Retrait $montant $_devise demandé', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('Ref: $refTransa\nVers: ${_phone.text}', textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))])));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Retrait'), backgroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        walletAsync.when(data: (w) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.warning_amber, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text('Solde: ${ThixFormatter.formatAmount(_devise == 'CDF'? w.soldeCdf : w.soldeUsd, _devise)}', style: const TextStyle(fontWeight: FontWeight.bold)))])), loading: () => const LinearProgressIndicator(), error: (_, __) => const SizedBox()),
        const SizedBox(height: 16),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'CDF', label: Text('CDF')), ButtonSegment(value: 'USD', label: Text('USD'))], selected: {_devise}, onSelectionChanged: (s) => setState(() => _devise = s.first)),
        const SizedBox(height: 16),
        TextFormField(controller: _phone, decoration: InputDecoration(labelText: 'Numéro retrait (M-Pesa/Airtel/Orange)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: ThixValidators.phone),
        const SizedBox(height: 12),
        TextFormField(controller: _amount, decoration: InputDecoration(labelText: 'Montant $_devise', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (v) => ThixValidators.montant(v, _devise), keyboardType: TextInputType.number),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _loading? const CircularProgressIndicator(color: Colors.white) : Text('Retirer $_devise', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}
