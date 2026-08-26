import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════
// SUPPLIER
// ═══════════════════════════════════════════════════════════════

@immutable
class Supplier {
  const Supplier({
    required this.id,
    required this.projectCode,
    required this.name,
    required this.category,
    this.contactName,
    this.email,
    this.phone,
    this.contact,
    this.product,
    this.price,
    this.leadTimeDays,
    this.notes,
    this.status = 'Recherche',
    this.score = 0,
    this.priceScore = 0,
    this.qualityScore = 0,
    this.delayScore = 0,
    this.reliabilityScore = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectCode;
  final String name;
  final String category;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? contact; // email / téléphone libre
  final String? product;
  final double? price;
  final int? leadTimeDays;
  final String? notes;
  final String status; // Recherche | Négociation | Validé | Inactif
  final double score;
  final double priceScore;
  final double qualityScore;
  final double delayScore;
  final double reliabilityScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get calculatedScore =>
      (priceScore + qualityScore + delayScore + reliabilityScore) / 4;

  bool get isValidated => status == 'Validé';
  bool get isNegotiating => status == 'Négociation';

  factory Supplier.fromJson(Map<String, dynamic> j) {
    return Supplier(
      id: j['id']?.toString() ?? '',
      projectCode: j['project_code']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      category: j['category']?.toString() ?? 'Général',
      contactName: j['contact_name']?.toString(),
      email: j['email']?.toString(),
      phone: j['phone']?.toString(),
      contact: j['contact']?.toString(),
      product: j['product']?.toString(),
      price: (j['price'] as num?)?.toDouble(),
      leadTimeDays: (j['lead_time_days'] as num?)?.toInt(),
      notes: j['notes']?.toString(),
      status: j['status']?.toString() ?? 'Recherche',
      score: (j['score'] as num?)?.toDouble() ?? 0,
      priceScore: (j['price_score'] as num?)?.toDouble() ?? 0,
      qualityScore: (j['quality_score'] as num?)?.toDouble() ?? 0,
      delayScore: (j['delay_score'] as num?)?.toDouble() ?? 0,
      reliabilityScore: (j['reliability_score'] as num?)?.toDouble() ?? 0,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'name': name,
        'category': category,
        if (contactName != null) 'contact_name': contactName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (contact != null) 'contact': contact,
        if (product != null) 'product': product,
        if (price != null) 'price': price,
        if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
        if (notes != null) 'notes': notes,
        'status': status,
        'score': calculatedScore,
        'price_score': priceScore,
        'quality_score': qualityScore,
        'delay_score': delayScore,
        'reliability_score': reliabilityScore,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Supplier copyWith({
    String? name,
    String? category,
    String? status,
    double? priceScore,
    double? qualityScore,
    double? delayScore,
    double? reliabilityScore,
    String? contact,
    String? notes,
  }) {
    return Supplier(
      id: id,
      projectCode: projectCode,
      name: name ?? this.name,
      category: category ?? this.category,
      contactName: contactName,
      email: email,
      phone: phone,
      contact: contact ?? this.contact,
      product: product,
      price: price,
      leadTimeDays: leadTimeDays,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      score: score,
      priceScore: priceScore ?? this.priceScore,
      qualityScore: qualityScore ?? this.qualityScore,
      delayScore: delayScore ?? this.delayScore,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════
// RISK
// ═══════════════════════════════════════════════════════════════

@immutable
class RiskItem {
  const RiskItem({
    required this.id,
    required this.projectCode,
    required this.title,
    required this.category,
    required this.probability,
    required this.impact,
    this.owner,
    this.mitigationPlan,
    this.reviewDate,
    this.status = 'open',
    this.createdAt,
  });

  final String id;
  final String projectCode;
  final String title;
  final String category;
  // financier | juridique | commercial | ops | tech | fournisseur | RH | marché
  final int probability; // 1-5
  final int impact; // 1-5
  final String? owner;
  final String? mitigationPlan;
  final DateTime? reviewDate;
  final String status; // open | mitigated | closed
  final DateTime? createdAt;

  int get level => probability * impact;

  String get levelLabel {
    if (level <= 4) return 'Faible';
    if (level <= 9) return 'Moyen';
    if (level <= 15) return 'Élevé';
    return 'Critique';
  }

  bool get isCritical => level >= 16;
  bool get isHigh => level >= 12;

  factory RiskItem.fromJson(Map<String, dynamic> j) {
    return RiskItem(
      id: j['id']?.toString() ?? '',
      projectCode: j['project_code']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      category: j['category']?.toString() ?? 'ops',
      probability: (j['probability'] as num?)?.toInt() ?? 1,
      impact: (j['impact'] as num?)?.toInt() ?? 1,
      owner: j['owner']?.toString(),
      mitigationPlan: j['mitigation_plan']?.toString(),
      reviewDate: j['review_date'] != null
          ? DateTime.tryParse(j['review_date'].toString())
          : null,
      status: j['status']?.toString() ?? 'open',
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'title': title,
        'category': category,
        'probability': probability,
        'impact': impact,
        if (owner != null) 'owner': owner,
        if (mitigationPlan != null) 'mitigation_plan': mitigationPlan,
        if (reviewDate != null) 'review_date': reviewDate!.toIso8601String(),
        'status': status,
      };

  RiskItem copyWith({
    String? title,
    String? category,
    int? probability,
    int? impact,
    String? owner,
    String? mitigationPlan,
    String? status,
  }) {
    return RiskItem(
      id: id,
      projectCode: projectCode,
      title: title ?? this.title,
      category: category ?? this.category,
      probability: probability ?? this.probability,
      impact: impact ?? this.impact,
      owner: owner ?? this.owner,
      mitigationPlan: mitigationPlan ?? this.mitigationPlan,
      reviewDate: reviewDate,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiskItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════
// COMPLIANCE
// ═══════════════════════════════════════════════════════════════

@immutable
class ComplianceItem {
  const ComplianceItem({
    required this.id,
    required this.projectCode,
    required this.title,
    required this.status,
    this.source,
    this.verifiedAt,
    this.confidence = 'high',
    this.notes,
  });

  final String id;
  final String projectCode;
  final String title; // RCCM, ID Fiscal, Licence sectorielle…
  final String status; // valid | warning | missing
  final String? source;
  final DateTime? verifiedAt;
  final String confidence; // high | medium | low
  final String? notes;

  bool get isValid => status == 'valid';
  bool get isMissing => status == 'missing';
  bool get needsAttention => status == 'warning' || status == 'missing';

  factory ComplianceItem.fromJson(Map<String, dynamic> j) {
    return ComplianceItem(
      id: j['id']?.toString() ?? '',
      projectCode: j['project_code']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      status: j['status']?.toString() ?? 'missing',
      source: j['source']?.toString(),
      verifiedAt: j['verified_at'] != null
          ? DateTime.tryParse(j['verified_at'].toString())
          : null,
      confidence: j['confidence']?.toString() ?? 'high',
      notes: j['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'title': title,
        'status': status,
        if (source != null) 'source': source,
        if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
        'confidence': confidence,
        if (notes != null) 'notes': notes,
      };

  ComplianceItem copyWith({
    String? title,
    String? status,
    String? source,
    DateTime? verifiedAt,
    String? confidence,
    String? notes,
  }) {
    return ComplianceItem(
      id: id,
      projectCode: projectCode,
      title: title ?? this.title,
      status: status ?? this.status,
      source: source ?? this.source,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      confidence: confidence ?? this.confidence,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplianceItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
