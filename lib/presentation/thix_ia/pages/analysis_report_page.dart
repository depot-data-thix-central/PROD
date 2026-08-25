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
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
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
                  height: 1.5,
                  fontSize: 14,
                  color: ThixPolicy.textMain,
                ),
                h1: ThixPolicy.titleStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ThixPolicy.primary,
                  height: 1.3,
                ),
                h2: ThixPolicy.titleStyle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: ThixPolicy.textMain,
                  height: 1.3,
                ),
                h3: ThixPolicy.titleStyle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMain,
                  height: 1.3,
                ),
                h4: ThixPolicy.bodyStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ThixPolicy.primary,
                ),
                listBullet: TextStyle(
                  color: ThixPolicy.primary,
                  fontSize: 14,
                ),
                listIndent: 20,
                strong: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMain,
                  fontSize: 14,
                ),
                em: ThixPolicy.bodyStyle.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
                blockquote: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                  fontSize: 13,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: ThixPolicy.primary, width: 3),
                  ),
                ),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: ThixPolicy.border,
                      width: 1,
                    ),
                  ),
                ),
                // Tableaux — API 0.7.x uniquement
                tableHead: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: ThixPolicy.primary,
                ),
                tableBody: TextStyle(
                  fontSize: 12.5,
                  color: ThixPolicy.textMain,
                  height: 1.35,
                ),
                tableHeadAlign: TextAlign.left,
                tableBorder: TableBorder.all(
                  color: ThixPolicy.border,
                  width: 0.8,
                ),
                tableColumnWidth: const FlexColumnWidth(),
                tableCellsPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
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
  // EXTRACTION
  // ═══════════════════════════════════════════════════════════

  String _extractContent(ProjectAnalysis a) {
    final rj = a.resultJson;

    if (rj != null && rj.isNotEmpty) {
      if (rj['content'] is String) {
        final parsed =
            _tryParseToMarkdown((rj['content'] as String).trim());
        if (parsed.isNotEmpty) return parsed;
      }
      if (rj['content'] is Map) {
        return _jsonToMarkdown(
            Map<String, dynamic>.from(rj['content'] as Map));
      }
      if (rj.containsKey('business_plan') ||
          rj.containsKey('plan_financier') ||
          rj.containsKey('financial_model') ||
          rj.containsKey('resume_executif')) {
        return _jsonToMarkdown(Map<String, dynamic>.from(rj));
      }
      if (rj['parsed'] is Map) {
        return _jsonToMarkdown(
            Map<String, dynamic>.from(rj['parsed'] as Map));
      }
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
      final cleaned = Map<String, dynamic>.from(rj)
        ..remove('model')
        ..remove('ai_model')
        ..remove('ai_model_used')
        ..remove('tokens')
        ..remove('usage')
        ..remove('search')
        ..remove('provider')
        ..remove('generated_at');
      if (cleaned.isNotEmpty) {
        return _jsonToMarkdown(cleaned);
      }
    }

    if (a.summary != null && a.summary!.trim().isNotEmpty) {
      final parsed = _tryParseToMarkdown(a.summary!.trim());
      if (parsed.isNotEmpty) return parsed;
      return a.summary!.trim();
    }

    return 'Aucun contenu disponible pour ce rapport.';
  }

  String _tryParseToMarkdown(String s) {
    if (s.isEmpty) return '';

    var text = s
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\"', '"')
        .replaceAll('\\"', '"')
        .trim();

    if (text.length > 1 &&
        ((text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith("'") && text.endsWith("'")))) {
      text = text.substring(1, text.length - 1).trim();
    }

    // JSON strict
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
      } catch (_) {}
    }

    // Format Dart : {model: xxx, content: {...}}
    final contentIdx = text.indexOf('content:');
    if (contentIdx >= 0) {
      final after = text.substring(contentIdx + 'content:'.length).trim();
      final extracted = _extractBalancedObject(after);
      if (extracted != null) {
        try {
          final decoded = jsonDecode(extracted);
          if (decoded is Map) {
            return _jsonToMarkdown(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          final bp = RegExp(
            r'"business_plan"\s*:\s*(\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\})',
            dotAll: true,
          ).firstMatch(extracted);
          if (bp != null) {
            try {
              final inner = '{"business_plan": ${bp.group(1)}}';
              final decoded = jsonDecode(inner);
              if (decoded is Map) {
                return _jsonToMarkdown(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          }
        }
      }
    }

    // business_plan quoté dans un blob
    final bpMatch = RegExp(
      r'"business_plan"\s*:\s*(\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\})',
      dotAll: true,
    ).firstMatch(text);
    if (bpMatch != null) {
      try {
        final inner = '{"business_plan": ${bpMatch.group(1)}}';
        final decoded = jsonDecode(inner);
        if (decoded is Map) {
          return _jsonToMarkdown(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    return text;
  }

  String? _extractBalancedObject(String s) {
    final start = s.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    for (var i = start; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // JSON → MARKDOWN (titres, listes, TABLEAUX)
  // ═══════════════════════════════════════════════════════════

  String _jsonToMarkdown(Map map, {int level = 0}) {
    final buffer = StringBuffer();
    final headingLevel = (level + 2).clamp(2, 6);
    final hashes = '#' * headingLevel;

    if (map.length == 1) {
      final onlyKey = map.keys.first.toString().toLowerCase();
      final onlyVal = map.values.first;
      if (const {
        'content',
        'business_plan',
        'plan_financier',
        'financial_model',
        'report',
        'data',
        'result',
        'parsed',
      }.contains(onlyKey)) {
        if (onlyVal is Map) {
          return _jsonToMarkdown(Map<String, dynamic>.from(onlyVal),
              level: level);
        }
        if (onlyVal is String) return _tryParseToMarkdown(onlyVal);
      }
    }

    map.forEach((key, value) {
      final k = key.toString().toLowerCase();
      if (const {
        'model',
        'ai_model',
        'ai_model_used',
        'tokens',
        'usage',
        'prompt_version',
        'provider',
        'generated_at',
      }.contains(k)) {
        return;
      }

      final title = _humanizeKey(key.toString());

      // ── Map ──
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);

        if (_isNumericMap(m)) {
          buffer.writeln('$hashes $title');
          buffer.writeln();
          buffer.writeln('| Indicateur | Valeur |');
          buffer.writeln('|:-----------|-------:|');
          m.forEach((mk, mv) {
            buffer.writeln(
                '| \( {_humanizeKey(mk.toString())} | ** \){_formatCell(mv)}** |');
          });
          buffer.writeln();
        } else if (_isPriceMap(m)) {
          buffer.writeln('$hashes $title');
          buffer.writeln();
          buffer.writeln('| Produit / Offre | Prix |');
          buffer.writeln('|:----------------|-----:|');
          m.forEach((mk, mv) {
            buffer.writeln(
                '| \( {_humanizeKey(mk.toString())} | ** \){_formatCell(mv)}** |');
          });
          buffer.writeln();
        } else {
          buffer.writeln('$hashes $title');
          buffer.writeln();
          buffer.write(_jsonToMarkdown(m, level: level + 1));
          if (level == 0) buffer.writeln('\n---\n');
        }
      }

      // ── List ──
      else if (value is List) {
        buffer.writeln('$hashes $title');
        buffer.writeln();

        if (value.isNotEmpty && value.every((e) => e is Map)) {
          final rows = value.cast<Map>();
          final cols = <String>{};
          for (final row in rows) {
            cols.addAll(row.keys.map((e) => e.toString()));
          }
          final colList = cols
              .where((c) => !const {
                    'id',
                    'model',
                    'provider',
                    'generated_at',
                  }.contains(c.toLowerCase()))
              .toList();

          if (colList.length <= 5 && colList.isNotEmpty && rows.length <= 12) {
            buffer.writeln(
                '| ${colList.map(_humanizeKey).join(' | ')} |');
            buffer.writeln(
                '| ${colList.map((_) => '---').join(' | ')} |');
            for (final row in rows) {
              final cells = colList
                  .map((c) => _formatCell(row[c]))
                  .join(' | ');
              buffer.writeln('| $cells |');
            }
            buffer.writeln();
          } else {
            for (final item in rows) {
              final poste = item['poste'] ??
                  item['role'] ??
                  item['title'] ??
                  item['segment'] ??
                  item['nom'] ??
                  item['name'];
              if (poste != null) {
                buffer.writeln('#### $poste');
                item.forEach((ik, iv) {
                  final iks = ik.toString().toLowerCase();
                  if (iks == 'poste' ||
                      iks == 'role' ||
                      iks == 'title' ||
                      iks == 'segment' ||
                      iks == 'nom' ||
                      iks == 'name') {
                    return;
                  }
                  if (iv == null || iv.toString().trim().isEmpty) return;
                  buffer.writeln(
                      '- **${_humanizeKey(ik.toString())}** : ${_formatCell(iv)}');
                });
                buffer.writeln();
              } else {
                buffer.write(_jsonToMarkdown(
                    Map<String, dynamic>.from(item),
                    level: level + 1));
              }
            }
          }
        } else {
          for (final item in value) {
            if (item == null) continue;
            final t = item.toString().trim();
            if (t.isEmpty) continue;
            buffer.writeln('- $t');
          }
          buffer.writeln();
        }
        if (level == 0) buffer.writeln('\n---\n');
      }

      // ── Simple ──
      else if (value != null && value.toString().trim().isNotEmpty) {
        final text = value.toString().trim();
        if (text.length > 110 || text.contains('\n')) {
          buffer.writeln('$hashes $title');
          buffer.writeln();
          buffer.writeln(text);
          buffer.writeln();
        } else {
          buffer.writeln('- **$title** : $text');
          buffer.writeln();
        }
      }
    });

    return buffer.toString();
  }

  bool _isNumericMap(Map m) {
    if (m.isEmpty || m.length > 10) return false;
    var n = 0;
    m.forEach((_, v) {
      if (v is num) {
        n++;
      } else if (v is String) {
        final cleaned =
            v.replaceAll(RegExp(r'[\s\u00a0]'), '').replaceAll(',', '.');
        if (num.tryParse(cleaned) != null) n++;
      }
    });
    return n >= (m.length / 2).ceil() && n >= 2;
  }

  bool _isPriceMap(Map m) {
    if (m.isEmpty) return false;
    final keys = m.keys.map((e) => e.toString().toLowerCase()).join(' ');
    return keys.contains('prix') ||
        keys.contains('price') ||
        keys.contains('bouteille') ||
        keys.contains('fcfa') ||
        keys.contains('cout') ||
        keys.contains('coût');
  }

  String _formatCell(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      if (v == v.roundToDouble()) {
        return _groupThousands(v.toInt());
      }
      return v.toString();
    }
    final s = v.toString().trim();
    // nombre dans une string
    final asNum =
        num.tryParse(s.replaceAll(RegExp(r'[\s\u00a0]'), '').replaceAll(',', '.'));
    if (asNum != null && asNum == asNum.roundToDouble() && asNum.abs() >= 1000) {
      return _groupThousands(asNum.toInt());
    }
    return s.replaceAll('|', '/');
  }

  String _groupThousands(int n) {
    final neg = n < 0;
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return neg ? '-${buf.toString()}' : buf.toString();
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
      'plan financier sommaire': 'Plan financier (sommaire)',
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
      'partenariats cles': 'Partenariats clés',
      'equipe': 'Équipe',
      'logistique': 'Logistique',
      'infrastructure': 'Infrastructure',
      'id projet': 'ID projet',
      'effectif initial': 'Effectif initial',
      'recrutement': 'Recrutement',
      'strategie commerciale marketing': 'Stratégie commerciale & marketing',
      'strategie prix': 'Stratégie de prix',
      'strategie distribution': 'Stratégie de distribution',
      'strategie communication': 'Stratégie de communication',
      'prix vente': 'Prix de vente',
      'ciblage': 'Ciblage',
      'segments clients': 'Segments clients',
      'analyse swot': 'Analyse SWOT',
      'forces': 'Forces',
      'faiblesses': 'Faiblesses',
      'opportunites': 'Opportunités',
      'menaces': 'Menaces',
      'concurrents directs': 'Concurrent directs',
      'concurrents indirects': 'Concurrent indirects',
      'points faibles': 'Points faibles',
      'annee 1': 'Année 1',
      'annee 2': 'Année 2',
      'annee 3': 'Année 3',
      'taux croissance annuel': 'Taux de croissance annuel (%)',
      'terrain et constructions': 'Terrain & constructions',
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
