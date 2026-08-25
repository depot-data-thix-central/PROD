// lib/presentation/thix_ia/pages/analysis_report_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_analysis.dart';
// TODO: Décommente et adapte le chemin vers ton provider de mémoire
// import '../providers/project_memory_provider.dart';
// import '../providers/analyses_provider.dart';

class AnalysisReportPage extends ConsumerStatefulWidget {
  const AnalysisReportPage({super.key, required this.analysis});

  final ProjectAnalysis analysis;

  @override
  ConsumerState<AnalysisReportPage> createState() => _AnalysisReportPageState();
}

class _AnalysisReportPageState extends ConsumerState<AnalysisReportPage> {
  bool isValidating = false;

  Future<void> _validateAndSendToMemory(
      ProjectAnalysis analysis, String contentToSave) async {
    setState(() => isValidating = true);

    try {
      // TODO: Décommente quand projectMemoryProvider est prêt
      /*
      await ref.read(projectMemoryProvider.notifier).addFact(
            type: 'validated_analysis',
            content: '【${analysis.type.toUpperCase()}】 ${analysis.title ?? analysis.type}\n\n$contentToSave',
            sourceName: analysis.title,
            confidence: analysis.confidence > 0 ? analysis.confidence : 0.9,
          );
      */

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Analyse validée et envoyée en Mémoire !',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _extractContent(widget.analysis);
    final sources = _extractSources(widget.analysis);

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
          _typeLabel(widget.analysis.type),
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
                            widget.analysis.title ??
                                _typeLabel(widget.analysis.type),
                            style: ThixPolicy.bodyStyle
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.analysis.projectCode,
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
                          horizontal: 10, vertical: 4),
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
                      label: widget.analysis.aiModelUsed ?? 'IA',
                    ),
                    const SizedBox(width: 8),
                    if (widget.analysis.completedAt != null)
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: _formatDate(widget.analysis.completedAt!),
                      ),
                    const Spacer(),
                    if (widget.analysis.confidence > 0)
                      Text(
                        'Confiance ${(widget.analysis.confidence * 100).toInt()}%',
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
          Text('Rapport', style: ThixPolicy.labelStyle.copyWith(fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border),
            ),
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
                h1: ThixPolicy.titleStyle
                    .copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                h2: ThixPolicy.titleStyle
                    .copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                h3: ThixPolicy.titleStyle
                    .copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                h4: ThixPolicy.titleStyle
                    .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                listBullet: TextStyle(color: ThixPolicy.primary),
                strong: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMain,
                ),
              ),
            ),
          ),

          // ========== SOURCES ==========
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Sources', style: ThixPolicy.labelStyle.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            ...sources.asMap().entries.map((e) {
              final i = e.key + 1;
              final url = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          if (widget.analysis.type == 'legal' ||
              widget.analysis.type == 'tax') ...[
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
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: Colors.amber.shade800),
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

          // ========== VALIDER EN MÉMOIRE ==========
          Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isValidating
                        ? null
                        : () => _validateAndSendToMemory(
                            widget.analysis, content),
                    icon: isValidating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.verified_rounded, size: 20),
                    label: Text(
                      isValidating
                          ? 'Envoi en cours...'
                          : 'Valider & envoyer en Mémoire',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: ThixPolicy.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cette analyse sera ajoutée à la mémoire du projet et servira à générer les documents officiels.',
                  textAlign: TextAlign.center,
                  style: ThixPolicy.captionStyle
                      .copyWith(color: ThixPolicy.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EXTRACTION + CONVERSION JSON → MARKDOWN
  // ═══════════════════════════════════════════════════════════

  String _extractContent(ProjectAnalysis a) {
    String rawText = '';
    final rj = a.resultJson;

    if (rj != null) {
      // 1) content = String (marché, concurrence, légal…)
      if (rj['content'] is String && (rj['content'] as String).isNotEmpty) {
        rawText = rj['content'] as String;
      }
      // 2) content = Map (business plan, finance…)
      else if (rj['content'] is Map) {
        rawText = _jsonToMarkdown(Map<String, dynamic>.from(rj['content'] as Map));
      }
      // 3) parsed.*
      else if (rj['parsed'] is Map) {
        final parsed = Map<String, dynamic>.from(rj['parsed'] as Map);
        if (parsed['content'] is String) {
          rawText = parsed['content'] as String;
        } else if (parsed['content'] is Map) {
          rawText = _jsonToMarkdown(Map<String, dynamic>.from(parsed['content'] as Map));
        } else if (parsed['report'] is String) {
          rawText = parsed['report'] as String;
        } else if (parsed['business_plan'] is Map) {
          rawText = _jsonToMarkdown({'business_plan': parsed['business_plan']});
        } else {
          rawText = _jsonToMarkdown(parsed);
        }
      }
      // 4) clés racines fréquentes
      else if (rj['business_plan'] is Map) {
        rawText = _jsonToMarkdown({'business_plan': rj['business_plan']});
      } else if (rj['plan_financier'] is Map || rj['financial_model'] is Map) {
        rawText = _jsonToMarkdown(Map<String, dynamic>.from(rj));
      } else if (rj['report'] is String) {
        rawText = rj['report'] as String;
      } else if (rj['text'] is String) {
        rawText = rj['text'] as String;
      } else if (rj['response'] is String) {
        rawText = rj['response'] as String;
      } else if (rj['result'] is String) {
        rawText = rj['result'] as String;
      } else if (rj['answer'] is String) {
        rawText = rj['answer'] as String;
      } else if (rj['data'] is String) {
        rawText = rj['data'] as String;
      } else if (rj['data'] is Map) {
        rawText = _jsonToMarkdown(Map<String, dynamic>.from(rj['data'] as Map));
      }
      // 5) dernier recours : tout le JSON formaté
      else if (rj.isNotEmpty) {
        // Enlever les clés purement techniques avant formatage
        final cleaned = Map<String, dynamic>.from(rj)
          ..remove('model')
          ..remove('ai_model')
          ..remove('ai_model_used')
          ..remove('tokens')
          ..remove('usage')
          ..remove('search');
        if (cleaned.isNotEmpty) {
          rawText = _jsonToMarkdown(cleaned);
        }
      }
    }

    // Fallback summary
    if (rawText.isEmpty && a.summary != null && a.summary!.isNotEmpty) {
      rawText = a.summary!;
    }

    // Si c’est encore une string JSON
    if (rawText.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          if (m['content'] is String) {
            rawText = m['content'] as String;
          } else if (m['content'] is Map) {
            rawText = _jsonToMarkdown(Map<String, dynamic>.from(m['content'] as Map));
          } else {
            m.remove('model');
            m.remove('ai_model');
            rawText = _jsonToMarkdown(m);
          }
        }
      } catch (_) {}
    }

    // Nettoyage échappements
    rawText = rawText.replaceAll('\\n', '\n');
    rawText = rawText.replaceAll('\\"', '"');
    rawText = rawText.replaceAll(r'\"', '"');

    if (rawText.startsWith('"') && rawText.endsWith('"') && rawText.length > 1) {
      rawText = rawText.substring(1, rawText.length - 1);
    }

    // Enlever un éventuel préfixe technique "model: xxx, content:"
    rawText = rawText.replaceAll(
      RegExp(r'^\{?\s*model:\s*[^\s,\}]+,?\s*content:\s*', caseSensitive: false),
      '',
    );

    return rawText.trim();
  }

  /// Convertit un Map JSON imbriqué en Markdown lisible
  String _jsonToMarkdown(Map map, {int level = 0}) {
    final buffer = StringBuffer();

    map.forEach((key, value) {
      final k = key.toString().toLowerCase();
      // Ignorer métadonnées techniques
      if (k == 'model' ||
          k == 'ai_model' ||
          k == 'ai_model_used' ||
          k == 'tokens' ||
          k == 'usage' ||
          k == 'prompt_version') {
        return;
      }

      final title = _humanizeKey(key.toString());
      final headingLevel = (level + 2).clamp(2, 6);
      final hashes = '#' * headingLevel;

      if (value is Map) {
        buffer.writeln('$hashes $title');
        buffer.writeln();
        buffer.write(
            _jsonToMarkdown(Map<String, dynamic>.from(value), level: level + 1));
      } else if (value is List) {
        buffer.writeln('$hashes $title');
        buffer.writeln();
        for (final item in value) {
          if (item is Map) {
            buffer.write(_jsonToMarkdown(
                Map<String, dynamic>.from(item),
                level: level + 1));
          } else if (item != null && item.toString().trim().isNotEmpty) {
            buffer.writeln('- ${item.toString().trim()}');
          }
        }
        buffer.writeln();
      } else if (value != null && value.toString().trim().isNotEmpty) {
        final text = value.toString().trim();
        // Texte long → paragraphe sous un titre
        if (text.length > 80 || text.contains('\n')) {
          buffer.writeln('$hashes $title');
          buffer.writeln();
          buffer.writeln(text);
          buffer.writeln();
        } else {
          buffer.writeln('**$title** : $text');
          buffer.writeln();
        }
      }
    });

    return buffer.toString();
  }

  String _humanizeKey(String key) {
    // resume_executif → Resume executif, puis capitaliser
    var cleaned = key
        .replaceAll('_', ' ')
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();

    // Petites traductions utiles
    const labels = {
      'business plan': 'Business Plan',
      'resume executif': 'Résumé exécutif',
      'objectifs strategiques': 'Objectifs stratégiques',
      'analyse marche': 'Analyse de marché',
      'analyse marche ciblee': 'Analyse de marché ciblée',
      'plan financier': 'Plan financier',
      'financial model': 'Modèle financier',
      'retour sur investissement': 'Retour sur investissement',
      'proposition valeur unique': 'Proposition de valeur unique',
      'presentation projet': 'Présentation du projet',
      'innovations': 'Innovations',
      'positionnement': 'Positionnement',
      'marches cibles': 'Marchés cibles',
      'pour les consommateurs': 'Pour les consommateurs',
      'pour l environnement': "Pour l'environnement",
      'pour la societe': 'Pour la société',
    };

    final lower = cleaned.toLowerCase();
    if (labels.containsKey(lower)) return labels[lower]!;

    if (cleaned.isEmpty) return key;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
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
    return '$day/\( month/ \){d.year}';
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'business_plan':
      case 'business':
        return 'Business Plan';
      case 'market':
      case 'market_study':
        return 'Étude de marché';
      case 'competitor':
      case 'competition':
        return 'Analyse concurrentielle';
      case 'legal':
        return 'Analyse réglementaire';
      case 'tax':
        return 'Analyse fiscale';
      case 'finance':
      case 'financial_model':
        return 'Plan financier';
      case 'strategy':
        return 'Stratégie';
      default:
        return type;
    }
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
