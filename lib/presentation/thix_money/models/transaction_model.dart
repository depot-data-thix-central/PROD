// lib/presentation/thix_money/models/transaction_model.dart
class TransactionModel {
  final String id;
  final String refTransa; // 20 chars WonyaPay
  final String thixId; // FK vers profiles.thix_id - OBLIGATOIRE
  final String userId; // auth.uid() pour RLS
  final String type; // C2B, B2C
  final String actionDetail; // RECHARGE, ENVOI, RETRAIT
  final int montant;
  final String devise; // CDF, USD
  final String phone; // numéro initiateur
  final String? phoneDest; // numéro destinataire
  final String statut; // pending, succes, recu, echec, rembourse
  final String? motif;
  final String orderId;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.refTransa,
    required this.thixId,
    required this.userId,
    required this.type,
    required this.actionDetail,
    required this.montant,
    required this.devise,
    required this.phone,
    this.phoneDest,
    required this.statut,
    required this.orderId,
    required this.createdAt,
    this.motif,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> j) {
    return TransactionModel(
      id: j['id'] as String,
      refTransa: j['ref_transa'] as String,
      thixId: j['thix_id'] as String,
      userId: j['user_id'] as String,
      type: j['type'] as String,
      actionDetail: j['action_detail'] as String,
      montant: (j['montant'] as num).toInt(),
      devise: j['devise'] as String,
      phone: j['phone'] as String,
      phoneDest: j['phone_dest'] as String?,
      statut: j['statut'] as String,
      orderId: j['order_id'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      motif: j['motif'] as String?,
    );
  }
}
