// lib/presentation/thix_money/services/payment_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'wallet_service.dart';

class PaymentService {
  final _db = Supabase.instance.client;
  final _walletService = WalletService();

  Future<String> _getThixId() => _walletService.getVerifiedThixId();

  // 1. ENVOI THIX à THIX - reste en RPC, pas besoin de clé externe
  Future<String> send({required int montant, required String devise, required String destThixId, String phoneDest = ''}) async {
    final thixId = await _getThixId();
    if (thixId == destThixId) throw Exception('Impossible de vous envoyer à vous-même');
    final refTransa = 'THIX-${DateTime.now().millisecondsSinceEpoch}';
    final dest = await _db.from('profiles').select('thix_id').eq('thix_id', destThixId).maybeSingle();
    if (dest == null) throw Exception('Destinataire THIX ID introuvable');
    await _db.rpc('transfer_thix', params: {
      'p_from_thix_id': thixId,
      'p_to_thix_id': destThixId,
      'p_amount': montant,
      'p_devise': devise,
      'p_ref': refTransa,
    });
    return refTransa;
  }

  // 2. RECHARGE - Passe par wonya-init où est cachée WONYA_API_KEY
  Future<String> recharge({required int montant, required String devise, required String phone}) async {
    if (montant < 1000) throw Exception('Minimum 1 000');
    final thixId = await _getThixId();
    
    final res = await _db.functions.invoke('wonya-init', body: {
      'phone': phone,
      'amount': montant,
      'thix_id': thixId,
      'devise': devise,
    });
    
    if (res.status != 200) throw Exception('Erreur Wonya: ${res.data}');
    return res.data['ref_transa'] as String;
  }

  // 3. RETRAIT - Passe par wonya-retrait où est cachée WONYA_API_KEY
  Future<String> retrait({required int montant, required String devise, required String phone}) async {
    final thixId = await _getThixId();
    final wallet = await _walletService.getWallet();
    final solde = devise == 'CDF' ? wallet.soldeCdf : wallet.soldeUsd;
    if (solde < montant) throw Exception('Solde insuffisant. Dispo: $solde $devise');
    if (montant < 2000) throw Exception('Minimum retrait 2 000');

    final res = await _db.functions.invoke('wonya-retrait', body: {
      'phone': phone,
      'amount': montant,
      'thix_id': thixId,
      'devise': devise,
    });

    if (res.status != 200) throw Exception('Erreur retrait: ${res.data}');
    return res.data['ref_transa'] as String;
  }

  Future<String> withdraw({required int montant, required String devise, required String phone}) => retrait(montant: montant, devise: devise, phone: phone);
  Future<String> topup({required int montant, required String devise, required String phone}) => recharge(montant: montant, devise: devise, phone: phone);
}
