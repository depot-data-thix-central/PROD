// lib/presentation/thix_money/pages/send_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';
import '../providers/wallet_provider.dart';
import '../utils/formatter.dart';

class SendPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  const SendPage({super.key, this.initialData});
  @override
  ConsumerState<SendPage> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  final _destCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();
  String _devise = 'CDF';
  bool _loading = false;
  bool _verifying = false;
  Map<String, dynamic>? _recipient;
  Timer? _debounce;
  final _payment = PaymentService();

  static const _primary = Color(0xFF2F5BFF);
  static const _bg = Color(0xFFF6F8FF);

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _destCtrl.text = widget.initialData!['thix_id'] ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
    _destCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_destCtrl.text.trim().length >= 3) {
        _verify();
      } else {
        setState(() => _recipient = null);
      }
    });
  }

  Future<void> _verify() async {
    final input = _destCtrl.text.trim();
    if (input.length < 3) return;
    setState(() {
      _verifying = true;
      _recipient = null;
    });
    try {
      final db = Supabase.instance.client;
      Map<String, dynamic>? res;

      // Correction : 'photo_url' a été retiré des sélections
      res = await db.from('profiles')
          .select('thix_id, display_name, thix_chat, contact_phone')
          .ilike('thix_id', input)
          .maybeSingle();

      if (res == null) {
        res = await db.from('profiles')
            .select('thix_id, display_name, thix_chat, contact_phone')
            .ilike('thix_chat', input.replaceAll('@', ''))
            .maybeSingle();
      }

      if (res == null && input.length >= 9) {
        res = await db.from('profiles')
            .select('thix_id, display_name, thix_chat, contact_phone')
            .eq('contact_phone', input)
            .maybeSingle();
      }

      final myId = await ref.read(currentThixIdProvider.future);
      if (res != null && res['thix_id'] == myId) {
        res = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous ne pouvez pas vous envoyer a vous-meme')),
          );
        }
      }
      if (mounted) setState(() => _recipient = res);
    } catch (e) {
      debugPrint('verify $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _send() async {
    if (_recipient == null) return;
    final montant = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (montant < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum 1000')));
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ConfirmSheet(amount: montant, devise: _devise, recipient: _recipient!, motif: _motifCtrl.text),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final refTransa = await _payment.send(montant: montant, devise: _devise, destThixId: _recipient!['thix_id'], phoneDest: _recipient!['contact_phone'] ?? '');
      ref.invalidate(walletStreamProvider);
      if (!mounted) return;
      await showDialog(context: context, barrierDismissible: false, builder: (_) => _SuccessDialog(ref: refTransa, recipient: _recipient!['display_name'], amount: montant, devise: _devise));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _destCtrl.removeListener(_onChanged);
    _destCtrl.dispose();
    _amountCtrl.dispose();
    _motifCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletStreamProvider);
    final isReady = _recipient != null && _amountCtrl.text.isNotEmpty && !_loading;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)), title: const Text('Envoyer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          wallet.when(
            data: (w) {
              final solde = _devise == 'CDF' ? w.soldeCdf : w.soldeUsd;
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.06))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_wallet_rounded, color: _primary)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Solde disponible', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(ThixFormatter.formatAmount(solde, _devise), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                ]),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.06))),
            child: Row(children: [
              _DeviseChip(selected: _devise == 'CDF', label: 'CDF', onTap: () => setState(() => _devise = 'CDF')),
              _DeviseChip(selected: _devise == 'USD', label: 'USD \$', onTap: () => setState(() => _devise = 'USD')),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Destinataire', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _destCtrl,
            decoration: InputDecoration(
              hintText: 'THIX ID, @thix_chat ou telephone',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _verifying
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : _recipient != null
                      ? const Icon(Icons.verified_rounded, color: Colors.green)
                      : const Icon(Icons.shield_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.06))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _primary, width: 1.2)),
            ),
          ),
          const SizedBox(height: 12),
          if (_recipient != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.2))),
              child: Row(children: [
                CircleAvatar(radius: 22, backgroundColor: const Color(0xFFEFF2FF), child: Text(_recipient!['display_name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: _primary))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_recipient!['display_name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_recipient!['thix_id'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
                  ]),
                ),
              ]),
            ),
          if (_recipient == null && _destCtrl.text.length > 7 && !_verifying)
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.error_outline, size: 18, color: Colors.red), SizedBox(width: 8), Expanded(child: Text('Aucun compte trouve', style: TextStyle(fontSize: 12, color: Colors.red)))])),
          const SizedBox(height: 20),
          const Text('Montant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '$_devise ',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.06))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _primary, width: 1.2)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [5000, 10000, 20000, 50000].map((v) {
              return ChoiceChip(
                label: Text('$v'),
                selected: false,
                onSelected: (_) {
                  _amountCtrl.text = v.toString();
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _motifCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Motif (optionnel)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.06))),
            ),
          ),
        ]),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))]),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isReady ? _send : null,
              style: ElevatedButton.styleFrom(backgroundColor: _primary, disabledBackgroundColor: Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_recipient == null ? 'Verifiez le destinataire' : 'Envoyer ${_amountCtrl.text} $_devise', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviseChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _DeviseChip({required this.selected, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: selected ? const Color(0xFF2F5BFF) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.black))),
        ),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final int amount;
  final String devise;
  final Map<String, dynamic> recipient;
  final String motif;
  const _ConfirmSheet({required this.amount, required this.devise, required this.recipient, required this.motif});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 20),
        const Text('Confirmer l\'envoi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF6F8FF), borderRadius: BorderRadius.circular(16)), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('A'), Text(recipient['display_name'], style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('THIX ID'), Text(recipient['thix_id'], style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700))]),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Montant'), Text('$amount $devise', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2F5BFF)))]),
        ])),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F5BFF)), child: const Text('Confirmer', style: TextStyle(color: Colors.white)))),
        ]),
      ]),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String ref;
  final String recipient;
  final int amount;
  final String devise;
  const _SuccessDialog({required this.ref, required this.recipient, required this.amount, required this.devise});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white)), const SizedBox(width: 12), const Text('Envoi reussi')]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vous avez envoye $amount $devise a $recipient'),
        const SizedBox(height: 12),
        Text('Ref: $ref', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}
