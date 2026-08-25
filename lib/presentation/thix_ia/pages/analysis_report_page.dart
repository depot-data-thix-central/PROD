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

          // ========== RAPPORT ==========
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

          // ========== VALIDER ==========
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
  // EXTRACTION JSON → MARKDOWN
  // ═══════════════════════════════════════════════════════════

  String _extractContent(ProjectAnalysis a) {
    final rj = a.resultJson;

    if (rj != null && rj.isNotEmpty) {
      // content = String (souvent le gros JSON business plan)
      if (rj['content'] is String) {
        final parsed =
            _tryParseToMarkdown((rj['content'] as String).trim());
        if (parsed.isNotEmpty) return parsed;
      }
      // content = Map
      if (rj['content'] is Map) {
        return _jsonToMarkdown(
            Map<String, dynamic>.from(rj['content'] as Map));
      }
      // business_plan / finance / résumé à la racine
      if (rj.containsKey('business_plan') ||
          rj.containsKey('plan_financier') ||
          rj.containsKey('financial_model') ||
          rj.containsKey('resume_executif')) {
        return _jsonToMarkdown(Map<String, dynamic>.from(rj));
      }
      // parsed
      if (rj['parsed'] is Map) {
        return _jsonToMarkdown(
            Map<String, dynamic>.from(rj['parsed'] as Map));
      }
      // clés string de secours
      for (final key in [
        'report',
        'text',
        'response',
        'result',
        'answer',
        'data'
      ]) {
        final v = rj[key];
        if (v is String && v.trim().isNotEmpty) {
          final parsed = _tryParseToMarkdown(v.trim());
          if (parsed.isNotEmpty) return parsed;
        }
        if (v is Map) {
          return _jsonToMarkdown(Map<String, dynamic>.from(v));
        }
      }
      // reste du map (sans métadonnées techniques)
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

    // Fallback summary
    if (a.summary != null && a.summary!.trim().isNotEmpty) {
      final parsed = _tryParseToMarkdown(a.summary!.trim());
      if (parsed.isNotEmpty) return parsed;
      return a.summary!.trim();
    }

    return 'Aucun contenu disponible pour ce rapport.';
  }

  /// String JSON → Markdown (sans exiger la clé "content")
  String _tryParseToMarkdown(String s) {
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
        // JSON invalide → texte brut
      }
    }
    return text;
  }

  /// Map imbriqué → Markdown
  String _jsonToMarkdown(Map map, {int level = 0}) {
    final buffer = StringBuffer();
    final headingLevel = (level + 2).clamp(2, 6);
    final hashes = '#' * headingLevel;

    // Une seule clé utile → plonger dedans
    if (map.length == 1) {
      final onlyKey = map.keys.first.toString().toLowerCase();
      final onlyVal = map.values.first;
      if (onlyKey == 'content' ||
          onlyKey == 'business_plan' ||
          onlyKey == 'plan_financier' ||
          onlyKey == 'financial_model' ||
          onlyKey == 'report' ||
          onlyKey == 'data' ||
          onlyKey == 'result' ||
          onlyKey == 'parsed') {
        if (onlyVal is Map) {
          return _jsonToMarkdown(Map<String, dynamic>.from(onlyVal),
              level: level);
        }
        if (onlyVal is String) {
          return _tryParseToMarkdown(onlyVal);
        }
      }
    }

    map.forEach((key, value) {
      final k = key.toString().toLowerCase();
      if (k == 'model' ||
          k == 'ai_model' ||
          k == 'ai_model_used' ||
          k == 'tokens' ||
          k == 'usage' ||
          k == 'prompt_version') {
        return;
      }

      final title = _humanizeKey(key.toString());

      if (value is Map) {
        buffer.writeln('$hashes $title');
        buffer.writeln();
        buffer.write(_jsonToMarkdown(Map<String, dynamic>.from(value),
            level: level + 1));
      } else if (value is List) {
        buffer.writeln('$hashes $title');
        buffer.writeln();
        for (final item in value) {
          if (item is Map) {
            final poste =
                item['poste'] ?? item['role'] ?? item['title'] ?? item['segment'];
            final nombre = item['nombre'] ?? item['count'] ?? item['taille'];
            final resp = item['responsabilites'] ??
                item['responsibilities'] ??
                item['description'] ??
                item['besoins'];
            if (poste != null) {
              final n = nombre != null ? ' ($nombre)' : '';
              buffer.writeln('- **$poste**$n');
              if (resp != null && resp.toString().trim().isNotEmpty) {
                buffer.writeln('  - ${resp.toString().trim()}');
              }
              final profil = item['profil'];
              if (profil != null && profil.toString().trim().isNotEmpty) {
                buffer.writeln('  - Profil : ${profil.toString().trim()}');
              }
              final canaux = item['canaux'];
              if (canaux != null && canaux.toString().trim().isNotEmpty) {
                buffer.writeln('  - Canaux : ${canaux.toString().trim()}');
              }
            } else {
              buffer.write(_jsonToMarkdown(Map<String, dynamic>.from(item),
                  level: level + 1));
            }
          } else if (item != null && item.toString().trim().isNotEmpty) {
            buffer.writeln('- ${item.toString().trim()}');
          }
        }
        buffer.writeln();
      } else if (value != null && value.toString().trim().isNotEmpty) {
        final text = value.toString().trim();
        if (text.length > 90 || text.contains('\n')) {
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
      'effectifs': 'Effectifs',
      'effectif initial': 'Effectif initial',
      'recrutement': 'Recrutement',
      'partenariats cles': 'Partenariats clés',
      'strategie commerciale marketing': 'Stratégie commerciale & marketing',
      'ciblage': 'Ciblage',
      'menaces': 'Menaces',
      'opportunites': 'Opportunités',
      'forces': 'Forces',
      'faiblesses': 'Faiblesses',
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
