// lib/presentation/thix_money/widgets/balance_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallet_provider.dart';
import '../utils/formatter.dart';
import '../utils/constants.dart';

class BalanceCard extends ConsumerStatefulWidget {
  const BalanceCard({super.key});
  @override
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  bool _hide = false;
  bool _isCdf = true;
  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletStreamProvider);
    return walletAsync.when(
      loading: () => Container(height: 170, margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: ThixConstants.primary, borderRadius: BorderRadius.circular(24)), child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      error: (e, _) => Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text('Erreur wallet thix_id: $e', style: const TextStyle(color: Colors.white, fontSize: 12)))])),
      data: (w) {
        final amount = _isCdf ? w.soldeCdf : w.soldeUsd;
        final devise = _isCdf ? 'CDF' : 'USD';
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A1550), ThixConstants.primary, Color(0xFF2A4BD7)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: ThixConstants.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.verified, color: Colors.white, size: 12), const SizedBox(width: 4), Text(w.thixId, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]))]),
              Row(children: [IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 18)), IconButton(onPressed: () => setState(() => _isCdf = !_isCdf), icon: const Icon(Icons.swap_horiz, color: Colors.white70, size: 18))]),
            ]),
            const SizedBox(height: 8),
            const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_hide ? '••••••••' : ThixFormatter.formatAmount(amount, devise), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 12),
            Row(children: [
              _Pill(label: 'CDF ${ThixFormatter.formatAmount(w.soldeCdf, 'CDF')}', active: _isCdf, onTap: () => setState(() => _isCdf = true)),
              const SizedBox(width: 8),
              _Pill(label: 'USD ${ThixFormatter.formatAmount(w.soldeUsd, 'USD')}', active: !_isCdf, onTap: () => setState(() => _isCdf = false)),
            ]),
          ]),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: active ? Colors.white : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? ThixConstants.primary : Colors.white))));
}
