import 'package:flutter/foundation.dart';

@immutable
class Supplier {
  const Supplier({required this.id, required this.projectCode, required this.name, required this.category, this.contactName, this.email, this.phone, this.product, this.price, this.leadTimeDays, this.status='research', this.score=0, this.priceScore=0, this.qualityScore=0, this.delayScore=0, this.reliabilityScore=0});
  final String id; final String projectCode; final String name; final String category;
  final String? contactName; final String? email; final String? phone; final String? product;
  final double? price; final int? leadTimeDays; final String status; // Validé, Négociation, Recherche
  final double score; final double priceScore; final double qualityScore; final double delayScore; final double reliabilityScore;

  double get calculatedScore => (priceScore + qualityScore + delayScore + reliabilityScore) / 4;

  factory Supplier.fromJson(Map<String,dynamic> j) => Supplier(
    id: j['id'].toString(), projectCode: j['project_code'].toString(), name: j['name'].toString(),
    category: j['category'].toString(), contactName: j['contact_name'] as String?, email: j['email'] as String?,
    phone: j['phone'] as String?, product: j['product'] as String?, price: (j['price'] as num?)?.toDouble(),
    leadTimeDays: (j['lead_time_days'] as num?)?.toInt(), status: j['status']?.toString() ?? 'research',
    score: (j['score'] as num?)?.toDouble() ?? 0, priceScore: (j['price_score'] as num?)?.toDouble() ?? 0,
    qualityScore: (j['quality_score'] as num?)?.toDouble() ?? 0, delayScore: (j['delay_score'] as num?)?.toDouble() ?? 0,
    reliabilityScore: (j['reliability_score'] as num?)?.toDouble() ?? 0,
  );
  Map<String,dynamic> toJson() => {'project_code': projectCode, 'name': name, 'category': category, 'contact_name': contactName, 'email': email, 'phone': phone, 'product': product, 'price': price, 'lead_time_days': leadTimeDays, 'status': status, 'score': calculatedScore, 'price_score': priceScore, 'quality_score': qualityScore, 'delay_score': delayScore, 'reliability_score': reliabilityScore};
}

@immutable
class RiskItem {
  const RiskItem({required this.id, required this.projectCode, required this.title, required this.category, required this.probability, required this.impact, this.owner, this.mitigationPlan, this.reviewDate, this.status='open'});
  final String id; final String projectCode; final String title; final String category; // financier, juridique, commercial, ops, tech, fournisseur, RH, marché
  final int probability; final int impact; // 1-5
  final String? owner; final String? mitigationPlan; final DateTime? reviewDate; final String status;
  int get level => probability * impact;
  String get levelLabel => level <= 4 ? 'Faible' : level <= 9 ? 'Moyen' : level <= 15 ? 'Élevé' : 'Critique';

  factory RiskItem.fromJson(Map<String,dynamic> j) => RiskItem(
    id: j['id'].toString(), projectCode: j['project_code'].toString(), title: j['title'].toString(),
    category: j['category'].toString(), probability: (j['probability'] as num).toInt(), impact: (j['impact'] as num).toInt(),
    owner: j['owner'] as String?, mitigationPlan: j['mitigation_plan'] as String?,
    reviewDate: j['review_date'] != null ? DateTime.tryParse(j['review_date'].toString()) : null,
    status: j['status']?.toString() ?? 'open',
  );
  Map<String,dynamic> toJson() => {'project_code': projectCode, 'title': title, 'category': category, 'probability': probability, 'impact': impact, 'owner': owner, 'mitigation_plan': mitigationPlan, 'review_date': reviewDate?.toIso8601String(), 'status': status};
}

@immutable
class ComplianceItem {
  const ComplianceItem({required this.id, required this.projectCode, required this.title, required this.status, this.source, this.verifiedAt, this.confidence='high'});
  final String id; final String projectCode; final String title; // RCCM, ID Fiscal, Licence sectorielle...
  final String status; // valid, warning, missing
  final String? source; final DateTime? verifiedAt; final String confidence;
  factory ComplianceItem.fromJson(Map<String,dynamic> j) => ComplianceItem(id: j['id'].toString(), projectCode: j['project_code'].toString(), title: j['title'].toString(), status: j['status'].toString(), source: j['source'] as String?, verifiedAt: j['verified_at'] != null ? DateTime.tryParse(j['verified_at'].toString()) : null, confidence: j['confidence']?.toString() ?? 'high');
  Map<String,dynamic> toJson() => {'project_code': projectCode, 'title': title, 'status': status, 'source': source, 'verified_at': verifiedAt?.toIso8601String(), 'confidence': confidence};
}
