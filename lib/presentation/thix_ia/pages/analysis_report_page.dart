// lib/presentation/thix_ia/pages/analysis_report_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_analysis.dart';

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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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
          // HEADER
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
                      child: Icon(Icons.analytics_rounded,
                          color: ThixPolicy.primary, size: 22),
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

          // RAPPORT
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

          // SOURCES
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Sources',
                style: ThixPolicy.labelStyle.copyWith(fontSize: 13)),
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

          // AVERTISSEMENT LÉGAL
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

          // VALIDER
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
  // EXTRACTION ROBUSTE + JSON → MARKDOWN
  // ═══════════════════════════════════════════════════════════

  String _extractContent(ProjectAnalysis a) {
    final rj = a.resultJson;

    // --- Cas Map (données structurées) ---
    if (rj != null && rj.isNotEmpty) {
      // content string → parser
      if (rj['content'] is String) {
        final parsed = _forceJsonToMarkdown((rj['content'] as String).trim());
        if (parsed.isNotEmpty) return parsed;
      }
      // content Map
      if (rj['content'] is Map) {
        return _jsonToMarkdown(Map<String, dynamic>.from(rj['content'] as Map));
      }
      // business_plan / finance à la racine
      if (rj.containsKey('business_plan') ||
          rj.containsKey('plan_financier') ||
          rj.containsKey('financial_model') ||
          rj.containsKey('resume_executif')) {
        return _jsonToMarkdown(Map<String, dynamic>.from(rj));
      }
      if (rj['parsed'] is Map) {
        return _jsonToMarkdown(Map<String, dynamic>.from(rj['parsed'] as Map));
      }
      // report / text / etc. en string
      for (final key in ['report', 'text', 'response', 'result', 'answer', 'data']) {
        final v = rj[key];
        if (v is String && v.trim().isNotEmpty) {
          final parsed = _forceJsonToMarkdown(v.trim());
          if (parsed.isNotEmpty) return parsed;
        }
        if (v is Map) {
          return _jsonToMarkdown(Map<String, dynamic>.from(v));
        }
      }
      // tout le map restant
      final cleaned = Map<String, dynamic>.from(rj)
        ..remove('model')
        ..remove('ai_model')
        ..remove('ai_model_used')
        ..remove('tokens')
        ..remove('usage')
        ..remove('search');
      if (cleaned.isNotEmpty) {
        return _jsonToMarkdown(cleaned);
      }
    }

    // --- Fallback summary ---
    if (a.summary != null && a.summary!.trim().isNotEmpty) {
      final parsed = _forceJsonToMarkdown(a.summary!.trim());
      if (parsed.isNotEmpty) return parsed;
      return a.summary!.trim();
    }

    return 'Aucun contenu disponible pour ce rapport.';
  }

  /// Force le passage JSON string → Markdown (sans exiger la clé "content")
  String _forceJsonToMarkdown(String s) {
    if (s.isEmpty) return '';
    var text = s
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\"', '"')
        .replaceAll('\\"', '"');

    if (text.length > 1 &&
        ((text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith("'") && text.endsWith("'")))) {
      text = text.substring(1, text.length - 1).trim();
    }

    // Tout string qui commence par { ou [ est traité comme JSON
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return _jsonToMarkdown(Map<String, dynamic>.from(decoded));
        }
        if (decoded is List) {
          final buf = StringBuffer();
          for (final item in decoded) {
            if (item is Map) {
              buf.write(_jsonToMarkdown(Map<String, dynamic>.from(item)));
            } else if (item != null) {
              buf.writeln('- $item');
            }
          }
          return buf.toString();
        }
      } catch (_) {
        // JSON invalide → on laisse le texte
      }
    }
    return text;
  }
  /// Accepte String | Map | List et renvoie du Markdown
  String _anyToMarkdown(dynamic value, {int level = 0}) {
    if (value == null) return '';

    // --- String ---
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty) return '';
      final parsed = _tryParseToMarkdown(s);
      return parsed.isNotEmpty ? parsed : s;
    }

    // --- Map ---
    if (value is Map) {
      return _jsonToMarkdown(Map<String, dynamic>.from(value));
    }

    // --- List ---
    if (value is List) {
      final buf = StringBuffer();
      for (final item in value) {
        if (item is Map) {
          buf.write(_jsonToMarkdown(Map<String, dynamic>.from(item)));
        } else if (item != null && item.toString().trim().isNotEmpty) {
          buf.writeln('- ${item.toString().trim()}');
        }
      }
      return buf.toString();
    }

    return value.toString();
  }

  /// Conversion Map JSON → Markdown structuré (titres, listes, gras)
  String _jsonToMarkdown(Map<String, dynamic> map, {int level = 0}) {
    final buf = StringBuffer();
    final headingLevel = (level + 2).clamp(2, 6);
    final hashes = '#' * headingLevel;

    // Si une seule clé "content" / "business_plan" / "report" → plonger dedans
    if (map.length == 1) {
      final onlyKey = map.keys.first;
      final onlyVal = map[onlyKey];
      final k = onlyKey.toString().toLowerCase();
      if (k == 'content' ||
          k == 'business_plan' ||
          k == 'plan_financier' ||
          k == 'financial_model' ||
          k == 'report' ||
          k == 'data' ||
          k == 'result' ||
          k == 'parsed') {
        return _anyToMarkdown(onlyVal, level: level);
      }
    }

    // Si "content" est présent avec d'autres clés techniques, prioriser content
    if (map.containsKey('content') && map['content'] != null) {
      final c = map['content'];
      final rest = Map<String, dynamic>.from(map)
        ..remove('content')
        ..remove('model')
        ..remove('ai_model')
        ..remove('ai_model_used')
        ..remove('tokens')
        ..remove('usage')
        ..remove('search');
      final main = _anyToMarkdown(c, level: level);
      if (rest.isEmpty) return main;
      return '$main\n\n${_jsonToMarkdown(rest, level: level)}';
    }

    map.forEach((key, val) {
      final k = key.toString().toLowerCase();
      if (k == 'model' ||
          k == 'ai_model' ||
          k == 'ai_model_used' ||
          k == 'tokens' ||
          k == 'usage' ||
          k == 'prompt_version' ||
          k == 'search') {
        return;
      }

      final title = _humanizeKey(key.toString());

      if (val is Map) {
        buf.writeln('$hashes $title');
        buf.writeln();
        buf.write(_jsonToMarkdown(Map<String, dynamic>.from(val),
            level: level + 1));
      } else if (val is List) {
        buf.writeln('$hashes $title');
        buf.writeln();
        for (final item in val) {
          if (item is Map) {
            // Liste d'objets (ex: équipe)
            final poste = item['poste'] ?? item['role'] ?? item['title'];
            final nombre = item['nombre'] ?? item['count'];
            final resp =
                item['responsabilites'] ?? item['responsibilities'] ?? item['description'];
            if (poste != null) {
              final n = nombre != null ? ' (x$nombre)' : '';
              buf.writeln('- **$poste**$n');
              if (resp != null && resp.toString().trim().isNotEmpty) {
                buf.writeln('  - ${resp.toString().trim()}');
              }
            } else {
              buf.write(_jsonToMarkdown(Map<String, dynamic>.from(item),
                  level: level + 1));
            }
          } else if (item != null && item.toString().trim().isNotEmpty) {
            buf.writeln('- ${item.toString().trim()}');
          }
        }
        buf.writeln();
      } else if (val != null && val.toString().trim().isNotEmpty) {
        // Si la valeur string est elle-même du JSON encodé, on la déplie aussi
        final rawText = val.toString().trim();
        final text = (rawText.startsWith('{') || rawText.startsWith('['))
            ? _tryParseToMarkdown(rawText)
            : rawText;

        if (text.length > 90 || text.contains('\n')) {
          buf.writeln('$hashes $title');
          buf.writeln();
          buf.writeln(text);
          buf.writeln();
        } else {
          buf.writeln('**$title** : $text');
          buf.writeln();
        }
      }
    });

    return buf.toString();
  }

  String _humanizeKey(String key) {
    var cleaned = key
        .replaceAll('_', ' ')
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();

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
      'chiffre affaires previsionnel': "Chiffre d'affaires prévisionnel",
      'seuil rentabilite': 'Seuil de rentabilité',
      'investissement initial': 'Investissement initial',
      'partenaires strategiques': 'Partenaires stratégiques',
      'equipe': 'Équipe',
      'logistique': 'Logistique',
      'infrastructure': 'Infrastructure',
      'id projet': 'ID projet',
      'pour les consommateurs': 'Pour les consommateurs',
      'pour l environnement': "Pour l'environnement",
      'pour la societe': 'Pour la société',
      'ciblage': 'Ciblage',
      'segments clients': 'Segments clients',
      'strategie commerciale marketing': 'Stratégie commerciale et marketing',
      'menaces': 'Menaces',
      'opportunites': 'Opportunités',
      'partenariats cles': 'Partenariats clés',
      'effectif initial': 'Effectif initial',
      'recrutement': 'Recrutement',
      'qualite': 'Qualité',
      'administratif': 'Administratif',
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
    return '$day/$month/${d.year}';
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
