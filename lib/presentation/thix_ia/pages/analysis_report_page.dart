// lib/presentation/thix_ia/pages/analysis_report_page.dart
import 'dart:convert'; // NOUVEAU: Pour décoder le JSON brut
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // NOUVEAU: Pour un affichage parfait

import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_analysis.dart';

class AnalysisReportPage extends ConsumerWidget {
  const AnalysisReportPage({super.key, required this.analysis});

  final ProjectAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _extractContent(analysis);
    final sources = _extractSources(analysis);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(
          analysis.type,
          style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Copier le rapport',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rapport copié'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ========== HEADER ==========
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border),
              boxShadow: ThixPolicy.shadowCard(opacity: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: ThixPolicy.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            analysis.title ?? analysis.type,
                            style: ThixPolicy.bodyStyle
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            analysis.projectCode,
                            style: ThixPolicy.captionStyle.copyWith(
                              fontFamily: 'monospace',
                              color: ThixPolicy.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ThixPolicy.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Terminé',
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.smart_toy_outlined,
                      label: analysis.aiModelUsed ?? 'IA',
                    ),
                    const SizedBox(width: 8),
                    if (analysis.completedAt != null)
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: _formatDate(analysis.completedAt!),
                      ),
                    const Spacer(),
                    if (analysis.confidence > 0)
                      Text(
                        'Confiance ${(analysis.confidence * 100).toInt()}%',
                        style: ThixPolicy.captionStyle
                            .copyWith(color: ThixPolicy.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ========== CONTENU DU RAPPORT ==========
          Text(
            'Rapport',
            style: ThixPolicy.labelStyle.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border),
            ),
            // MODIFICATION ICI: MarkdownBody remplace SelectableText pour un rendu parfait
            child: MarkdownBody(
              data: content.isNotEmpty
                  ? content
                  : 'Aucun contenu disponible pour ce rapport.',
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: ThixPolicy.bodyStyle.copyWith(
                  height: 1.55,
                  fontSize: 14.5,
                  color: ThixPolicy.textMain,
                ),
                h1: ThixPolicy.titleStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                h2: ThixPolicy.titleStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                h3: ThixPolicy.titleStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                listBullet: TextStyle(color: ThixPolicy.primary),
              ),
            ),
          ),

          // ========== SOURCES ==========
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Sources',
              style: ThixPolicy.labelStyle.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...sources.asMap().entries.map((e) {
              final i = e.key + 1;
              final url = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$i',
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        url,
                        style: ThixPolicy.captionStyle
                            .copyWith(color: ThixPolicy.primary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ========== AVERTISSEMENT LÉGAL ==========
          if (analysis.type == 'legal' || analysis.type == 'tax') ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ce rapport est généré par intelligence artificielle à titre informatif. '
                      'Il ne constitue pas un avis juridique. Faites valider toute décision par un professionnel du droit.',
                      style: ThixPolicy.captionStyle.copyWith(
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- Helpers mis à jour et robustes (AVEC NETTOYAGE) ----------
  String _extractContent(ProjectAnalysis a) {
    String rawText = '';
    final rj = a.resultJson;

    if (rj != null) {
      if (rj['content'] is String && (rj['content'] as String).isNotEmpty) {
        rawText = rj['content'] as String;
      } else if (rj['parsed'] != null && rj['parsed'] is Map) {
        final parsedMap = rj['parsed'] as Map;
        if (parsedMap['content'] is String) rawText = parsedMap['content'];
        else if (parsedMap['report'] is String) rawText = parsedMap['report'];
      } else {
        final fallbackKeys = ['text', 'report', 'response', 'result', 'answer', 'data'];
        for (var key in fallbackKeys) {
          if (rj[key] is String && (rj[key] as String).isNotEmpty) {
            rawText = rj[key] as String;
            break;
          }
        }
        if (rawText.isEmpty && rj.isNotEmpty) {
           rawText = rj.toString(); 
        }
      }
    }
    
    if (rawText.isEmpty && a.summary != null && a.summary!.isNotEmpty) {
      rawText = a.summary!;
    }

    // ==========================================
    // LE GRAND NETTOYAGE (FIX POUR LA LISIBILITÉ)
    // ==========================================

    // 1. Si l'IA a renvoyé le JSON sous forme de texte brut avec des échappements
    if (rawText.trim().startsWith('{') && rawText.contains('"content"')) {
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is Map && decoded['content'] is String) {
          rawText = decoded['content'];
        }
      } catch (_) {} // Ignore silencieusement si ce n'est pas un JSON valide
    }

    // 2. Transformer les "\n" littéraux en VRAIS sauts de ligne pour le Markdown
    rawText = rawText.replaceAll('\\n', '\n');
    
    // 3. Nettoyer les guillemets d'échappement (ex: \")
    rawText = rawText.replaceAll('\\"', '"');

    // 4. Enlever les guillemets résiduels de début et de fin si la chaîne entière est entourée
    if (rawText.startsWith('"') && rawText.endsWith('"') && rawText.length > 1) {
      rawText = rawText.substring(1, rawText.length - 1);
    }

    return rawText.trim();
  }

  List<String> _extractSources(ProjectAnalysis a) {
    if (a.sources.isNotEmpty) return a.sources;
    final rj = a.resultJson;
    if (rj == null) return [];
    
    final search = rj['search'];
    if (search is Map && search['results'] is List) {
      return (search['results'] as List)
          .map((e) => e is Map ? (e['url']?.toString() ?? '') : '')
          .where((u) => u.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceStrong,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ThixPolicy.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: ThixPolicy.microStyle
                .copyWith(color: ThixPolicy.textSecondary),
          ),
        ],
      ),
    );
  }
}
