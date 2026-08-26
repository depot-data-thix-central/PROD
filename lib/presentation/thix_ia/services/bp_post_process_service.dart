import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/business_plan_config.dart';
import '../repositories/bp_config_repository.dart';

/// Après génération BP :
/// 1) Parse contenu → sections livre A4
/// 2) Upsert thix_bp_documents + project_documents
/// 3) Injecte budget / OKRs / roadmap dans Exécution
class BpPostProcessService {
  BpPostProcessService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> processCompletedBusinessPlan({
    required String projectCode,
    required String analysisId,
    required String rawContent,
    Map<String, dynamic>? founderConfigJson,
  }) async {
    final founder = founderConfigJson != null
        ? BusinessPlanConfig.fromJson({
            ...founderConfigJson,
            'project_code': projectCode,
          })
        : await BpConfigRepository().getByProject(projectCode);

    // 1) Structurer les sections (livre)
    final sections = _parseSections(rawContent, founder);

    // 2) Snapshot financier pour Exécution
    final financial = _extractFinancial(sections, founder);

    // 3) Sauvegarder document BP éditable
    final userId = _client.auth.currentUser?.id;
    final docRow = await _client
        .from('thix_bp_documents')
        .upsert({
          'project_code': projectCode,
          'analysis_id': analysisId,
          'title': founder?.productName != null
              ? 'Business Plan – ${founder!.productName}'
              : 'Business Plan',
          'status': 'draft',
          'sections': sections,
          'financial_snapshot': financial,
          if (userId != null) 'owner_id': userId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'project_code')
        .select()
        .maybeSingle();

    // Si pas de contrainte unique project_code, fallback insert
    final bpDocId = docRow?['id']?.toString() ??
        (await _client
                .from('thix_bp_documents')
                .insert({
                  'project_code': projectCode,
                  'analysis_id': analysisId,
                  'title': 'Business Plan',
                  'status': 'draft',
                  'sections': sections,
                  'financial_snapshot': financial,
                  if (userId != null) 'owner_id': userId,
                })
                .select()
                .single())['id']
            .toString();

    // 4) Générer PDF A4 + upload Storage + ligne project_documents
    try {
      final pdfBytes = await buildA4Pdf(
        projectCode: projectCode,
        title: sections['title']?.toString() ?? 'Business Plan',
        sections: sections,
      );
      await _uploadPdfAndRegister(
        projectCode: projectCode,
        bpDocId: bpDocId,
        bytes: pdfBytes,
      );
    } catch (e) {
      debugPrint('PDF upload skipped: $e');
    }

    // 5) Injecter Exécution
    await _injectExecution(
      projectCode: projectCode,
      bpDocId: bpDocId,
      financial: financial,
      founder: founder,
      sections: sections,
    );
  }

  Map<String, dynamic> _parseSections(
    String raw,
    BusinessPlanConfig? founder,
  ) {
    // Essaie JSON ; sinon découpe markdown par titres
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final j = jsonDecode(raw.substring(start, end + 1));
        if (j is Map) return Map<String, dynamic>.from(j);
      }
    } catch (_) {}

    return {
      'title': founder?.productName ?? 'Business Plan',
      'executive_summary': _extractBetween(raw, [
        'résumé exécutif',
        'executive summary',
        '1.'
      ], [
        '2.',
        'présentation'
      ]),
      'value_proposition': _extractBetween(raw, [
        'proposition de valeur',
        'présentation'
      ], [
        '3.',
        'marché'
      ]),
      'market': _extractBetween(raw, ['marché', '3.'], ['4.', 'stratégie']),
      'strategy':
          _extractBetween(raw, ['stratégie', '4.'], ['5.', 'organisation']),
      'team': _extractBetween(raw, ['équipe', 'organisation', '5.'], [
        '6.',
        'financier'
      ]),
      'financials':
          _extractBetween(raw, ['financier', '6.'], ['7.', 'risques']),
      'risks': _extractBetween(raw, ['risques', '7.'], ['8.', 'feuille']),
      'roadmap': _extractBetween(raw, ['feuille de route', 'roadmap', '8.'], [
        'fin',
        'conclusion'
      ]),
      'raw': raw,
    };
  }

  String _extractBetween(
      String text, List<String> starts, List<String> ends) {
    final lower = text.toLowerCase();
    int i = -1;
    for (final s in starts) {
      i = lower.indexOf(s.toLowerCase());
      if (i >= 0) break;
    }
    if (i < 0) return '';
    int j = text.length;
    for (final e in ends) {
      final k = lower.indexOf(e.toLowerCase(), i + 3);
      if (k > i && k < j) j = k;
    }
    return text.substring(i, j).trim();
  }

  Map<String, dynamic> _extractFinancial(
    Map<String, dynamic> sections,
    BusinessPlanConfig? founder,
  ) {
    final capital = founder?.initialCapital ?? 0.0;
    final target = founder?.fundingTarget ?? 0.0;
    final raised = capital; // pour l’instant = capital fondateur
    final gap = (target - raised).clamp(0, double.infinity);

    return {
      'initial_capital': capital,
      'funding_target': target,
      'funding_raised': raised,
      'funding_gap': gap,
      'allocation': founder?.fundAllocation,
      'year1_goal': founder?.year1Goal,
      'product_name': founder?.productName,
      'stage': founder?.stage,
      'usp': founder?.usp,
    };
  }

  Future<Uint8List> buildA4Pdf({
    required String projectCode,
    required String title,
    required Map<String, dynamic> sections,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final order = [
      ('Résumé exécutif', 'executive_summary'),
      ('Proposition de valeur', 'value_proposition'),
      ('Marché', 'market'),
      ('Stratégie', 'strategy'),
      ('Équipe', 'team'),
      ('Finances', 'financials'),
      ('Risques', 'risks'),
      ('Feuille de route', 'roadmap'),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('THIX IA',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900)),
              pw.Text(projectCode,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          pw.Divider(color: PdfColors.indigo200),
          pw.SizedBox(height: 8),
        ]),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Généré le $date',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
            pw.Text('Page \( {ctx.pageNumber}/ \){ctx.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        build: (ctx) => [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          for (final e in order) ...[
            if ((sections[e.$2]?.toString() ?? '').trim().isNotEmpty) ...[
              pw.Text(e.$1,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(sections[e.$2].toString(),
                  style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _uploadPdfAndRegister({
    required String projectCode,
    required String bpDocId,
    required Uint8List bytes,
  }) async {
    final path =
        '\( projectCode/business_plan_ \){DateTime.now().millisecondsSinceEpoch}.pdf';
    await _client.storage.from('project-documents').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    await _client.from('thix_bp_documents').update({
      'pdf_path': path,
      'pdf_size': bytes.length,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bpDocId);

    // Ligne visible dans l’onglet Documents
    await _client.from('project_documents').insert({
      'project_code': projectCode,
      'file_name': 'Business_Plan_A4.pdf',
      'file_path': path,
      'file_type': 'pdf',
      'file_size': bytes.length,
      'mime_type': 'application/pdf',
      'status': 'indexed',
      'summary': 'Business Plan généré par THIX IA (format A4)',
    });
  }

  Future<void> _injectExecution({
    required String projectCode,
    required String bpDocId,
    required Map<String, dynamic> financial,
    required BusinessPlanConfig? founder,
    required Map<String, dynamic> sections,
  }) async {
    final capital = (financial['initial_capital'] as num?)?.toDouble() ?? 0;
    final target = (financial['funding_target'] as num?)?.toDouble() ?? 0;
    final raised = (financial['funding_raised'] as num?)?.toDouble() ?? capital;
    final gap = (financial['funding_gap'] as num?)?.toDouble() ?? 0;

    // Budget
    await _client.from('thix_execution_budget').upsert({
      'project_code': projectCode,
      'initial_capital': capital,
      'funding_target': target,
      'funding_raised': raised,
      'funding_gap': gap,
      'allocation': founder?.fundAllocation != null
          ? {'raw': founder!.fundAllocation}
          : {},
      'year1_goal': founder?.year1Goal,
      'source_bp_doc_id': bpDocId,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'project_code');

    // Trésorerie
    if (capital > 0) {
      await BpConfigRepository().seedExecution(projectCode);
      await _client.from('thix_execution_projects').upsert({
        'project_code': projectCode,
        'treasury': capital,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'project_code');
    }

    // Objectif stratégique (gap de financement)
    if (target > 0) {
      await _client.from('thix_execution_goals').upsert({
        'project_code': projectCode,
        'title': 'Atteindre la levée de fonds',
        'description':
            'Objectif : \\[ {target.toStringAsFixed(0)}. Déjà : \ \]{raised.toStringAsFixed(0)}. Reste : \\[ {gap.toStringAsFixed(0)}',
        'target_value': target,
        'current_value': raised,
        'unit': 'USD',
        'status': 'active',
        'progress': target > 0 ? ((raised / target) * 100).clamp(0, 100) : 0,
      }, onConflict: 'project_code,title');
    }

    // Tâches roadmap simplifiées
    final tasks = [
      if (gap > 0) 'Préparer le pitch investisseurs (reste \ \]{gap.toStringAsFixed(0)})',
      if (founder?.missingRoles != null)
        'Recruter : ${founder!.missingRoles}',
      if (founder?.acquisitionChannel != null)
        'Lancer acquisition : ${founder!.acquisitionChannel}',
      'Valider conformité légale / licences',
      'Finaliser MVP / produit',
    ];

    for (final t in tasks) {
      try {
        await _client.from('thix_execution_tasks').insert({
          'project_code': projectCode,
          'title': t,
          'category': 'BP',
          'priority': 'high',
          'status': 'todo',
          'origin': 'bp_auto',
          'progress': 0,
        });
      } catch (_) {}
    }
  }
}
