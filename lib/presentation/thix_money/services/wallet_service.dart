// lib/presentation/thix_money/services/wallet_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletModel {
  final String id;
  final String thixId;
  final int soldeCdf;
  final int soldeUsd;
  final String devisePref;
  WalletModel({required this.id, required this.thixId, required this.soldeCdf, required this.soldeUsd, this.devisePref = 'CDF'});
  factory WalletModel.fromJson(Map<String, dynamic> j) => WalletModel(
    id: j['id']?? j['thix_id']?? '',
    thixId: j['thix_id']?? '',
    soldeCdf: (j['solde_cdf']??0) as int,
    soldeUsd: (j['solde_usd']??0) as int,
    devisePref: j['devise_pref']?? 'CDF',
  );
}

class WalletService {
  final _db = Supabase.instance.client;
  Future<String> getVerifiedThixId() async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    final res = await _db.from('profiles').select('thix_id').eq('id', user.id).single();
    final thixId = res['thix_id'] as String?;
    if (thixId == null || thixId.isEmpty || thixId == 'THIX-PENDING') throw Exception('THIX ID non vérifié');
    return thixId;
  }
  Future<WalletModel> getWallet() async {
    final thixId = await getVerifiedThixId();
    final res = await _db.from('thix_wallets').select().eq('thix_id', thixId).single();
    return WalletModel.fromJson(res);
  }
  Stream<WalletModel> streamWallet() async* {
    final thixId = await getVerifiedThixId();
    yield* _db.from('thix_wallets').stream(primaryKey: ['thix_id']).eq('thix_id', thixId).map((list) {
      if (list.isEmpty) return WalletModel(id: thixId, thixId: thixId, soldeCdf: 0, soldeUsd: 0);
      return WalletModel.fromJson(list.first);
    });
  }
}
