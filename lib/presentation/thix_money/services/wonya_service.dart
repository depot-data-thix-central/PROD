// lib/presentation/thix_money/services/wonya_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/ref_generator.dart';

class WonyaService {
  final _sb = Supabase.instance.client;

  // Récupère thix_id vérifié
  Future<String> _getThixId() async {
    final uid = _sb.auth.currentUser!.id;
    final res = await _sb.from('profiles').select('thix_id').eq('id', uid).single();
    return res['thix_id'] as String;
  }

  // INIT PAIEMENT SÉCURISÉ - passe par Edge Function, token Wonya jamais en client
  Future<String> initPayment({
    required String action, // C2B = Recharge, B2C = Envoi/Retrait
    required int montant,
    required String devise, // CDF ou USD
    required String phone,
    String? phoneDest,
    required String motif,
  }) async {
    final thixId = await _getThixId();
    final uid = _sb.auth.currentUser!.id;
    final refTransa = RefGenerator.generateRefTransa();
    final orderId = RefGenerator.generateOrderId();

    final body = {
      'RefTransa': refTransa,
      'Action': action,
      'Montant': montant,
      'Devise': devise,
      'MobileMoney': phone.replaceAll(RegExp(r'\D'), ''),
      'Motif': motif,
      'thixId': thixId,
      'userId': uid,
      'orderId': orderId,
      'phoneDest': phoneDest,
    };

    final res = await _sb.functions.invoke('wonya-init', body: body);
    if (res.status != 200) {
      throw Exception(res.data['error'] ?? 'Erreur WonyaPay');
    }

    // Insert pending avec thix_id vérifié
    await _sb.from('thix_transactions').insert({
      'ref_transa': refTransa,
      'thix_id': thixId,
      'user_id': uid,
      'type': action,
      'action_detail': action == 'C2B' ? 'RECHARGE' : (phoneDest != null ? 'ENVOI' : 'RETRAIT'),
      'montant': montant,
      'devise': devise,
      'phone': phone,
      'phone_dest': phoneDest,
      'statut': 'pending',
      'motif': motif,
      'order_id': orderId,
    });

    return refTransa;
  }
}
