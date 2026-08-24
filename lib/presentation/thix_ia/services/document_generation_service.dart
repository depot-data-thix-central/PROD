// lib/presentation/thix_ia/services/document_generation_service.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/project_memory.dart';
import '../models/thix_project.dart';
import '../models/project_analysis.dart';
import 'ai_service.dart';

enum DocumentType {
  businessPlan,
  pitch,
  profile,
  conceptualNote,
  executiveSummary,
}

extension DocumentTypeX on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.businessPlan:
        return 'Business Plan complet';
      case DocumentType.pitch:
        return 'Pitch Deck (1 page)';
      case DocumentType.profile:
        return 'Profil projet';
      case DocumentType.conceptualNote:
        return 'Note conceptuelle';
      case DocumentType.executiveSummary:
        return 'Résumé exécutif';
    }
  }

  String get filePrefix {
    switch (this) {
      case DocumentType.businessPlan:
        return 'BusinessPlan';
      case DocumentType.pitch:
        return 'Pitch';
      case DocumentType.profile:
        return 'Profil';
      case DocumentType.conceptualNote:
        return 'NoteConceptuelle';
      case DocumentType.executiveSummary:
        return 'ResumeExecutif';
    }
  }
}

class DocumentGenerationService {
  DocumentGenerationService({required this.aiService});

  final AiService aiService;

  /// Génère un document PDF professionnel à partir de la mémoire + analyses
  Future<Uint8List> generate({
    required DocumentType type,
    required ThixProject project,
    required ProjectMemory memory,
    required List<ProjectAnalysis> validatedAnalyses,
  }) async {
    // 1. Construire le contexte riche pour l'IA
    final context = _buildContext(project, memory, validatedAnalyses);

    // 2. Demander à l'IA le contenu structuré
    final content = await _askAiForContent(type, context);

    // 3. Générer le PDF propre
    return _buildPdf(
      type: type,
      project: project,
      content: content,
      memory: memory,
    );
  }

  String _buildContext(
    ThixProject project,
    ProjectMemory memory,
    List<ProjectAnalysis> analyses,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('=== PROJET ===');
    buffer.writeln('Code : ${project.projectCode}');
    buffer.writeln('Nom : ${project.name}');
    buffer.writeln('Secteur : ${project.sector}');
    buffer.writeln('Pays : ${project.country}');
    if (project.city != null) buffer.writeln('Ville : ${project.city}');
    if (project.summary != null) buffer.writeln('Idée : ${project.summary}');
    buffer.writeln();

    buffer.writeln('=== MÉMOIRE VALIDÉE ===');
    for (final fact in memory.facts) {
      buffer.writeln('- [${fact.type}] ${fact.content} (confiance: ${fact.confidence})');
    }
    buffer.writeln();

    buffer.writeln('=== ANALYSES VALIDÉES ===');
    for (final a in analyses) {
      buffer.writeln('--- ${a.title ?? a.type} ---');
      final content = a.resultJson?['content']?.toString() ?? a.summary ?? '';
      buffer.writeln(content.length > 1500 ? '${content.substring(0, 1500)}...' : content);
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<Map<String, dynamic>> _askAiForContent(
    DocumentType type,
    String context,
  ) async {
    final prompts = {
      DocumentType.businessPlan: '''
Tu es un expert en business plan pour l'Afrique centrale.
À partir du contexte suivant, génère un business plan structuré en JSON strict :

{
  "executive_summary": "...",
  "problem": "...",
  "solution": "...",
  "market": "...",
  "competition": "...",
  "business_model": "...",
  "go_to_market": "...",
  "team": "...",
  "financials": {
    "assumptions": ["..."],
    "revenue_year1": "...",
    "costs_year1": "...",
    "break_even": "...",
    "funding_need": "..."
  },
  "roadmap": ["Mois 1-3: ...", "Mois 4-6: ...", "..."],
  "risks": ["..."]
}

Contexte :
$context
''',
      DocumentType.pitch: '''
Génère un pitch deck ultra-concis en JSON :
{
  "hook": "phrase d'accroche 1 ligne",
  "problem": "2-3 phrases",
  "solution": "2-3 phrases",
  "market": "taille + opportunité",
  "traction": "ce qui existe déjà",
  "ask": "ce que l'on demande (montant / partenaires)",
  "why_us": "pourquoi cette équipe"
}
Contexte :
$context
''',
      DocumentType.profile: '''
Génère un profil projet professionnel en JSON :
{
  "title": "...",
  "tagline": "...",
  "description": "paragraphe 120-150 mots",
  "sector": "...",
  "location": "...",
  "stage": "Idée / MVP / Croissance",
  "key_metrics": ["...", "..."],
  "highlights": ["...", "...", "..."]
}
Contexte :
$context
''',
      DocumentType.conceptualNote: '''
Génère une note conceptuelle claire en JSON :
{
  "title": "...",
  "context": "...",
  "objectives": ["...", "..."],
  "approach": "...",
  "expected_impact": "...",
  "next_steps": ["...", "..."]
}
Contexte :
$context
''',
      DocumentType.executiveSummary: '''
Génère un résumé exécutif en JSON :
{
  "title": "...",
  "summary": "150-200 mots",
  "opportunity": "...",
  "solution": "...",
  "ask": "..."
}
Contexte :
$context
''',
    };

    final res = await aiService.call(
      action: ThixAiAction.businessPlan,
      message: prompts[type]!,
      jsonMode: true,
      temperature: 0.25,
      maxTokens: 4096,
    );

    if (res.success && res.parsed != null) {
      return res.parsed!;
    }

    // Fallback minimal
    return {
      'executive_summary': res.content ?? 'Contenu non disponible',
      'error': res.error,
    };
  }

  Future<Uint8List> _buildPdf({
    required DocumentType type,
    required ThixProject project,
    required Map<String, dynamic> content,
    required ProjectMemory memory,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'THIX IA',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.Text(
                  project.projectCode,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.indigo200),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Généré le $date', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text(
              'Page ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => _buildPages(type, project, content),
      ),
    );

    return pdf.save();
  }

  List<pw.Widget> _buildPages(
    DocumentType type,
    ThixProject project,
    Map<String, dynamic> content,
  ) {
    switch (type) {
      case DocumentType.businessPlan:
        return _businessPlanPages(project, content);
      case DocumentType.pitch:
        return _pitchPages(project, content);
      case DocumentType.profile:
        return _profilePages(project, content);
      case DocumentType.conceptualNote:
        return _conceptualPages(project, content);
      case DocumentType.executiveSummary:
        return _executivePages(project, content);
    }
  }

  List<pw.Widget> _businessPlanPages(ThixProject p, Map<String, dynamic> c) {
    final cityString = p.city != null ? ' • ${p.city}' : '';
    return [
      pw.Header(
        level: 0,
        child: pw.Text(
          'BUSINESS PLAN',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Text(p.name, style: pw.TextStyle(fontSize: 16, color: PdfColors.indigo800)),
      pw.SizedBox(height: 8),
      pw.Text('${p.sector} • ${p.country}$cityString'),
      pw.SizedBox(height: 24),

      _section('1. Résumé exécutif', c['executive_summary']?.toString() ?? ''),
      _section('2. Problème', c['problem']?.toString() ?? ''),
      _section('3. Solution', c['solution']?.toString() ?? ''),
      _section('4. Marché', c['market']?.toString() ?? ''),
      _section('5. Concurrence', c['competition']?.toString() ?? ''),
      _section('6. Modèle économique', c['business_model']?.toString() ?? ''),
      _section('7. Go-to-Market', c['go_to_market']?.toString() ?? ''),

      pw.SizedBox(height: 16),
      pw.Text('8. Données financières', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      if (c['financials'] is Map) ...[
        _kv('Revenus année 1', c['financials']['revenue_year1']?.toString()),
        _kv('Coûts année 1', c['financials']['costs_year1']?.toString()),
        _kv('Seuil de rentabilité', c['financials']['break_even']?.toString()),
        _kv('Besoin de financement', c['financials']['funding_need']?.toString()),
      ],

      pw.SizedBox(height: 16),
      pw.Text('9. Feuille de route', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      if (c['roadmap'] is List)
        ...List<pw.Widget>.from(
          (c['roadmap'] as List).map((e) => pw.Bullet(text: e.toString())),
        ),

      pw.SizedBox(height: 16),
      pw.Text('10. Risques', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      if (c['risks'] is List)
        ...List<pw.Widget>.from(
          (c['risks'] as List).map((e) => pw.Bullet(text: e.toString())),
        ),
    ];
  }

  List<pw.Widget> _pitchPages(ThixProject p, Map<String, dynamic> c) {
    return [
      pw.Header(level: 0, child: pw.Text('PITCH', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 12),
      pw.Text(c['hook']?.toString() ?? p.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
      pw.SizedBox(height: 20),
      _section('Problème', c['problem']?.toString() ?? ''),
      _section('Solution', c['solution']?.toString() ?? ''),
      _section('Marché', c['market']?.toString() ?? ''),
      _section('Traction', c['traction']?.toString() ?? ''),
      _section('Pourquoi nous', c['why_us']?.toString() ?? ''),
      _section('Demande', c['ask']?.toString() ?? ''),
    ];
  }

  List<pw.Widget> _profilePages(ThixProject p, Map<String, dynamic> c) {
    final locationString = p.city != null ? '${p.country}, ${p.city}' : p.country;
    return [
      pw.Header(level: 0, child: pw.Text('PROFIL PROJET', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 12),
      pw.Text(c['title']?.toString() ?? p.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Text(c['tagline']?.toString() ?? '', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
      pw.SizedBox(height: 16),
      _section('Description', c['description']?.toString() ?? ''),
      _kv('Secteur', c['sector']?.toString() ?? p.sector),
      _kv('Localisation', c['location']?.toString() ?? locationString),
      _kv('Stade', c['stage']?.toString() ?? 'Idée'),
      if (c['highlights'] is List) ...[
        pw.SizedBox(height: 12),
        pw.Text('Points forts', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...List<pw.Widget>.from((c['highlights'] as List).map((e) => pw.Bullet(text: e.toString()))),
      ],
    ];
  }

  List<pw.Widget> _conceptualPages(ThixProject p, Map<String, dynamic> c) {
    return [
      pw.Header(level: 0, child: pw.Text('NOTE CONCEPTUELLE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 12),
      pw.Text(c['title']?.toString() ?? p.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      _section('Contexte', c['context']?.toString() ?? ''),
      if (c['objectives'] is List) ...[
        pw.Text('Objectifs', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...List<pw.Widget>.from((c['objectives'] as List).map((e) => pw.Bullet(text: e.toString()))),
        pw.SizedBox(height: 12),
      ],
      _section('Approche', c['approach']?.toString() ?? ''),
      _section('Impact attendu', c['expected_impact']?.toString() ?? ''),
      if (c['next_steps'] is List) ...[
        pw.Text('Prochaines étapes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...List<pw.Widget>.from((c['next_steps'] as List).map((e) => pw.Bullet(text: e.toString()))),
      ],
    ];
  }

  List<pw.Widget> _executivePages(ThixProject p, Map<String, dynamic> c) {
    return [
      pw.Header(level: 0, child: pw.Text('RÉSUMÉ EXÉCUTIF', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 16),
      _section(c['title']?.toString() ?? p.name, c['summary']?.toString() ?? ''),
      _section('Opportunité', c['opportunity']?.toString() ?? ''),
      _section('Solution', c['solution']?.toString() ?? ''),
      _section('Demande', c['ask']?.toString() ?? ''),
    ];
  }

  pw.Widget _section(String title, String body) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
        pw.SizedBox(height: 4),
        pw.Text(body, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4)),
        pw.SizedBox(height: 14),
      ],
    );
  }

  pw.Widget _kv(String key, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(key, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value ?? '—', style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }
}
