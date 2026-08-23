// lib/presentation/thix_ia/models/project_memory.dart
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';

/// ============================================================================
/// PROJECT MEMORY ENGINE §7 du cahier
/// Mémoire structurée durable, pas un historique de chat
/// ============================================================================

class ProjectMemory extends Equatable {
  const ProjectMemory({
    required this.projectCode,
    required this.identity,
    required this.context,
    this.facts = const [],
    this.ideas = const [],
    this.decisions = const [],
    this.openQuestions = const [],
    this.lastUpdated,
  });

  final String projectCode;
  final ProjectIdentity identity;
  final ProjectContext context;
  final List<ProjectFact> facts;
  final List<ProjectIdea> ideas;
  final List<ProjectDecision> decisions;
  final List<String> openQuestions;
  final DateTime? lastUpdated;

  factory ProjectMemory.fromJson(Map<String, dynamic> json) {
    return ProjectMemory(
      projectCode: JsonUtils.stringValue(json, 'project_code'),
      identity: ProjectIdentity.fromJson(JsonUtils.asMap(json['identity'])),
      context: ProjectContext.fromJson(JsonUtils.asMap(json['context'])),
      facts: JsonUtils.asList(json['facts'], fromMap: ProjectFact.fromJson),
      ideas: JsonUtils.asList(json['ideas'], fromMap: ProjectIdea.fromJson),
      decisions: JsonUtils.asList(json['decisions'], fromMap: ProjectDecision.fromJson),
      openQuestions: JsonUtils.stringList(json, 'open_questions'),
      lastUpdated: JsonUtils.dateTimeValue(json, 'last_updated'),
    );
  }

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'identity': identity.toJson(),
        'context': context.toJson(),
        'facts': facts.map((e) => e.toJson()).toList(),
        'ideas': ideas.map((e) => e.toJson()).toList(),
        'decisions': decisions.map((e) => e.toJson()).toList(),
        'open_questions': openQuestions,
        'last_updated': lastUpdated?.toIso8601String(),
      };

  @override
  List<Object?> get props => [projectCode, lastUpdated, facts.length];
}

// ────────────────────────────────────────────────────────────────────────────
// Sous-objets
// ────────────────────────────────────────────────────────────────────────────

class ProjectIdentity extends Equatable {
  const ProjectIdentity({
    required this.name,
    required this.sector,
    required this.country,
    this.city,
    this.ownerName,
    this.objectives = const [],
  });

  final String name;
  final String sector;
  final String country;
  final String? city;
  final String? ownerName;
  final List<String> objectives;

  factory ProjectIdentity.fromJson(Map<String, dynamic> json) => ProjectIdentity(
        name: JsonUtils.stringValue(json, 'name'),
        sector: JsonUtils.stringValue(json, 'sector'),
        country: JsonUtils.stringValue(json, 'country'),
        city: JsonUtils.stringValue(json, 'city'),
        ownerName: JsonUtils.stringValue(json, 'owner_name'),
        objectives: JsonUtils.stringList(json, 'objectives'),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'sector': sector,
        'country': country,
        'city': city,
        'owner_name': ownerName,
        'objectives': objectives,
      };

  @override
  List<Object?> get props => [name, sector, country];
}

class ProjectContext extends Equatable {
  const ProjectContext({
    this.problem,
    this.solution,
    this.targetCustomers = const [],
    this.valueProposition,
    this.hypotheses = const [],
  });

  final String? problem;
  final String? solution;
  final List<String> targetCustomers;
  final String? valueProposition;
  final List<String> hypotheses;

  factory ProjectContext.fromJson(Map<String, dynamic> json) => ProjectContext(
        problem: JsonUtils.stringValue(json, 'problem'),
        solution: JsonUtils.stringValue(json, 'solution'),
        targetCustomers: JsonUtils.stringList(json, 'target_customers'),
        valueProposition: JsonUtils.stringValue(json, 'value_proposition'),
        hypotheses: JsonUtils.stringList(json, 'hypotheses'),
      );

  Map<String, dynamic> toJson() => {
        'problem': problem,
        'solution': solution,
        'target_customers': targetCustomers,
        'value_proposition': valueProposition,
        'hypotheses': hypotheses,
      };

  @override
  List<Object?> get props => [problem, solution];
}

class ProjectFact extends Equatable {
  const ProjectFact({
    required this.id,
    required this.type, // fact, estimation, hypothesis, recommendation
    required this.content,
    this.sourceUrl,
    this.sourceName,
    this.confidence = 0.8,
    this.dateCollected,
    this.dateVerified,
  });

  final String id;
  final String type;
  final String content;
  final String? sourceUrl;
  final String? sourceName;
  final double confidence;
  final DateTime? dateCollected;
  final DateTime? dateVerified;

  factory ProjectFact.fromJson(Map<String, dynamic> json) => ProjectFact(
        id: JsonUtils.stringValue(json, 'id'),
        type: JsonUtils.stringValue(json, 'type', fallback: 'fact'),
        content: JsonUtils.stringValue(json, 'content'),
        sourceUrl: JsonUtils.stringValue(json, 'source_url'),
        sourceName: JsonUtils.stringValue(json, 'source_name'),
        confidence: JsonUtils.doubleValue(json, 'confidence', fallback: 0.8),
        dateCollected: JsonUtils.dateTimeValue(json, 'date_collected'),
        dateVerified: JsonUtils.dateTimeValue(json, 'date_verified'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
        'source_url': sourceUrl,
        'source_name': sourceName,
        'confidence': confidence,
        'date_collected': dateCollected?.toIso8601String(),
        'date_verified': dateVerified?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, type, confidence];
}

class ProjectIdea extends Equatable {
  const ProjectIdea({required this.id, required this.title, this.description, this.createdAt});

  final String id;
  final String title;
  final String? description;
  final DateTime? createdAt;

  factory ProjectIdea.fromJson(Map<String, dynamic> json) => ProjectIdea(
        id: JsonUtils.stringValue(json, 'id'),
        title: JsonUtils.stringValue(json, 'title'),
        description: JsonUtils.stringValue(json, 'description'),
        createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'description': description};

  @override
  List<Object?> get props => [id];
}

class ProjectDecision extends Equatable {
  const ProjectDecision({required this.id, required this.title, this.reason, this.decidedAt, this.decidedBy});

  final String id;
  final String title;
  final String? reason;
  final DateTime? decidedAt;
  final String? decidedBy;

  factory ProjectDecision.fromJson(Map<String, dynamic> json) => ProjectDecision(
        id: JsonUtils.stringValue(json, 'id'),
        title: JsonUtils.stringValue(json, 'title'),
        reason: JsonUtils.stringValue(json, 'reason'),
        decidedAt: JsonUtils.dateTimeValue(json, 'decided_at'),
        decidedBy: JsonUtils.stringValue(json, 'decided_by'),
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'reason': reason};

  @override
  List<Object?> get props => [id];
}
