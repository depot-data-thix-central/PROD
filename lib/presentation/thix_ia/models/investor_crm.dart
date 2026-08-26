// lib/presentation/thix_ia/models/investor_crm.dart
import 'package:flutter/foundation.dart';

enum InvestorStage {
  identified,
  contacted,
  deckSent,
  meeting,
  dueDiligence,
  termSheet,
  committed,
  passed,
}

enum InvestorType { angel, vc, familyOffice, corporate, accelerator, other }
enum InvestorPriority { low, medium, high, critical }

extension InvestorStageX on InvestorStage {
  String get label {
    switch (this) {
      case InvestorStage.identified: return 'Identifié';
      case InvestorStage.contacted: return 'Contacté';
      case InvestorStage.deckSent: return 'Deck envoyé';
      case InvestorStage.meeting: return 'Meeting';
      case InvestorStage.dueDiligence: return 'Due Diligence';
      case InvestorStage.termSheet: return 'Term Sheet';
      case InvestorStage.committed: return 'Engagé';
      case InvestorStage.passed: return 'Passé';
    }
  }

  Color get color {
    switch (this) {
      case InvestorStage.identified: return const Color(0xFF9E9E9E);
      case InvestorStage.contacted: return const Color(0xFF42A5F5);
      case InvestorStage.deckSent: return const Color(0xFF5C6BC0);
      case InvestorStage.meeting: return const Color(0xFF26A69A);
      case InvestorStage.dueDiligence: return const Color(0xFFFFA726);
      case InvestorStage.termSheet: return const Color(0xFFAB47BC);
      case InvestorStage.committed: return const Color(0xFF66BB6A);
      case InvestorStage.passed: return const Color(0xFFEF5350);
    }
  }
}

@immutable
class Investor {
  const Investor({
    required this.id,
    required this.projectCode,
    required this.name,
    required this.firm,
    required this.email,
    this.phone,
    this.linkedin,
    required this.type,
    required this.stage,
    required this.priority,
    this.checkSizeMin,
    this.checkSizeMax,
    this.thesis,
    this.source,
    this.lastContactAt,
    this.nextFollowUpAt,
    this.deckSentAt,
    this.notes,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectCode;
  final String name;
  final String firm;
  final String email;
  final String? phone;
  final String? linkedin;
  final InvestorType type;
  final InvestorStage stage;
  final InvestorPriority priority;
  final double? checkSizeMin;
  final double? checkSizeMax;
  final String? thesis;
  final String? source;
  final DateTime? lastContactAt;
  final DateTime? nextFollowUpAt;
  final DateTime? deckSentAt;
  final String? notes;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOverdue {
    if (nextFollowUpAt == null) return false;
    return nextFollowUpAt!.isBefore(DateTime.now()) &&
        stage != InvestorStage.committed &&
        stage != InvestorStage.passed;
  }

  String get checkSizeLabel {
    if (checkSizeMin == null && checkSizeMax == null) return '—';
    if (checkSizeMin != null && checkSizeMax != null) {
      return '\\[ {(checkSizeMin! / 1000).toStringAsFixed(0)}k – \ \]{(checkSizeMax! / 1000).toStringAsFixed(0)}k';
    }
    final v = checkSizeMin ?? checkSizeMax!;
    return '\\[ {(v / 1000).toStringAsFixed(0)}k';
  }

  factory Investor.fromJson(Map<String, dynamic> j) => Investor(
        id: j['id'].toString(),
        projectCode: j['project_code'].toString(),
        name: j['name']?.toString() ?? '',
        firm: j['firm']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        phone: j['phone']?.toString(),
        linkedin: j['linkedin']?.toString(),
        type: InvestorType.values.firstWhere(
            (e) => e.name == j['type'],
            orElse: () => InvestorType.other),
        stage: InvestorStage.values.firstWhere(
            (e) => e.name == j['stage'],
            orElse: () => InvestorStage.identified),
        priority: InvestorPriority.values.firstWhere(
            (e) => e.name == j['priority'],
            orElse: () => InvestorPriority.medium),
        checkSizeMin: (j['check_size_min'] as num?)?.toDouble(),
        checkSizeMax: (j['check_size_max'] as num?)?.toDouble(),
        thesis: j['thesis']?.toString(),
        source: j['source']?.toString(),
        lastContactAt: j['last_contact_at'] != null
            ? DateTime.tryParse(j['last_contact_at'].toString())
            : null,
        nextFollowUpAt: j['next_follow_up_at'] != null
            ? DateTime.tryParse(j['next_follow_up_at'].toString())
            : null,
        deckSentAt: j['deck_sent_at'] != null
            ? DateTime.tryParse(j['deck_sent_at'].toString())
            : null,
        notes: j['notes']?.toString(),
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'name': name,
        'firm': firm,
        'email': email,
        'phone': phone,
        'linkedin': linkedin,
        'type': type.name,
        'stage': stage.name,
        'priority': priority.name,
        'check_size_min': checkSizeMin,
        'check_size_max': checkSizeMax,
        'thesis': thesis,
        'source': source,
        'last_contact_at': lastContactAt?.toIso8601String(),
        'next_follow_up_at': nextFollowUpAt?.toIso8601String(),
        'deck_sent_at': deckSentAt?.toIso8601String(),
        'notes': notes,
        'tags': tags,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Investor copyWith({
    String? name,
    String? firm,
    String? email,
    String? phone,
    String? linkedin,
    InvestorType? type,
    InvestorStage? stage,
    InvestorPriority? priority,
    double? checkSizeMin,
    double? checkSizeMax,
    String? thesis,
    String? source,
    DateTime? lastContactAt,
    DateTime? nextFollowUpAt,
    DateTime? deckSentAt,
    String? notes,
    List<String>? tags,
  }) =>
      Investor(
        id: id,
        projectCode: projectCode,
        name: name ?? this.name,
        firm: firm ?? this.firm,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        linkedin: linkedin ?? this.linkedin,
        type: type ?? this.type,
        stage: stage ?? this.stage,
        priority: priority ?? this.priority,
        checkSizeMin: checkSizeMin ?? this.checkSizeMin,
        checkSizeMax: checkSizeMax ?? this.checkSizeMax,
        thesis: thesis ?? this.thesis,
        source: source ?? this.source,
        lastContactAt: lastContactAt ?? this.lastContactAt,
        nextFollowUpAt: nextFollowUpAt ?? this.nextFollowUpAt,
        deckSentAt: deckSentAt ?? this.deckSentAt,
        notes: notes ?? this.notes,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

@immutable
class InvestorActivity {
  const InvestorActivity({
    required this.id,
    required this.investorId,
    required this.projectCode,
    required this.type, // email | call | meeting | note | deck | followup
    required this.title,
    this.body,
    this.createdAt,
  });

  final String id;
  final String investorId;
  final String projectCode;
  final String type;
  final String title;
  final String? body;
  final DateTime? createdAt;

  factory InvestorActivity.fromJson(Map<String, dynamic> j) => InvestorActivity(
        id: j['id'].toString(),
        investorId: j['investor_id'].toString(),
        projectCode: j['project_code'].toString(),
        type: j['type']?.toString() ?? 'note',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString(),
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'investor_id': investorId,
        'project_code': projectCode,
        'type': type,
        'title': title,
        'body': body,
      };
}
