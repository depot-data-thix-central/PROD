// lib/presentation/thix_money/models/wallet_model.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletModel {
  final String id; // uuid = auth.uid()
  final String thixId; // THIX-CI-... vérifié en base
  final int soldeCdf;
  final int soldeUsd;
  final String devisePref;
  final DateTime updatedAt;

  WalletModel({
    required this.id,
    required this.thixId,
    required this.soldeCdf,
    required this.soldeUsd,
    required this.devisePref,
    required this.updatedAt,
  });

  // Vérification que le thix_id existe bien dans profiles
  static Future<bool> verifyThixIdExists(String thixId) async {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('thix_id')
        .eq('thix_id', thixId)
        .maybeSingle();
    return res != null;
  }

  factory WalletModel.fromJson(Map<String, dynamic> j) {
    return WalletModel(
      id: j['id'] as String,
      thixId: j['thix_id'] as String,
      soldeCdf: (j['solde_cdf'] as num?)?.toInt() ?? 0,
      soldeUsd: (j['solde_usd'] as num?)?.toInt() ?? 0,
      devisePref: j['devise_pref'] as String? ?? 'CDF',
      updatedAt: DateTime.parse(j['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'thix_id': thixId,
    'solde_cdf': soldeCdf,
    'solde_usd': soldeUsd,
    'devise_pref': devisePref,
  };
}
