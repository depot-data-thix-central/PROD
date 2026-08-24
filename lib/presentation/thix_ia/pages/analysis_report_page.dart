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

  Future<void> _validateAndSendToMemory(ProjectAnalysis analysis, String contentToSave) async {
    setState(() => isValidating = true);
    
    try {
      // 1. Appel du provider pour ajouter le fait à la mémoire
      // TODO: Décommente ces lignes quand ton projectMemoryProvider sera prêt
      /*
      await ref.read(projectMemoryProvider.notifier).addFact(
            type: 'validated_analysis',
            content: '【${analysis.type.toUpperCase()}】 ${analysis.title ?? analysis.type}\n\n$contentToSave',
            sourceName: analysis.title,
            confidence: analysis.confidence > 0 ? analysis.confidence : 0.9,
          );
      */

      // 2. (Optionnel) Marquer l'analyse comme validée en base
      // await ref.read(analysesProvider.notifier).markAsValidated(analysis.id);

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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        
        // On retourne à l'écran précédent après validation
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
          widget.analysis.type,
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
                            widget.analysis.title ?? widget.analysis.type,
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
                listBullet: const TextStyle(color: ThixPolicy.primary),
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
          if (widget.analysis.type == 'legal' || widget.analysis.type == 'tax') ...[
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

          // ==========================================
          // ACTION : VALIDER EN MÉMOIRE
          // ==========================================
          Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isValidating ? null : () => _validateAndSendToMemory(widget.analysis, content),
                    icon: isValidating
                        ? const SizedBox(
                            width: 18, 
                            height: 18, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Icon(Icons.verified_rounded, size: 20),
                    label: Text(
                      isValidating ? 'Envoi en cours...' : 'Valider & envoyer en Mémoire',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: ThixPolicy.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cette analyse sera ajoutée à la mémoire du projet et servira à générer les documents officiels.',
                  textAlign: TextAlign.center,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // LOGIQUE ANTI-JSON : Nettoyage et Formatage
  // =========================================================================
  String _extractContent(ProjectAnalysis a) {
    String rawText = a.summary ?? '';

    // 1. Si summary est vide mais qu'on a un resultJson, on tente de l'utiliser
    if (rawText.isEmpty && a.resultJson != null && a.resultJson!.isNotEmpty) {
      if (a.resultJson!['content'] is String) {
        rawText = a.resultJson!['content'];
      } else {
        // C'est un objet (comme finance ou business_plan), on le convertit en Markdown !
        rawText = _jsonToMarkdown(a.resultJson!);
      }
    }

    // 2. ULTIME BOUCLIER : Si la chaîne brute qu'on a récupérée ressemble encore à du JSON "{...}"
    rawText = rawText.trim();
    if (rawText.startsWith('{') && rawText.endsWith('}')) {
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is Map) {
          if (decoded['content'] is String) {
            rawText = decoded['content'];
          } else {
            // Conversion magique du JSON en Markdown structuré
            rawText = _jsonToMarkdown(decoded); 
          }
        }
      } catch (_) {
        // Si jsonDecode échoue, on laisse le texte tel quel (c'est probablement juste du texte avec des accolades)
      }
    }

    // 3. Nettoyage final des caractères d'échappement inutiles
    rawText = rawText.replaceAll('\\n', '\n').replaceAll('\\"', '"');
    if (rawText.startsWith('"') && rawText.endsWith('"') && rawText.length > 1) {
      rawText = rawText.substring(1, rawText.length - 1);
    }

    return rawText.trim();
  }

  // Fonction récursive pour transformer n'importe quel objet JSON en Markdown propre
  String _jsonToMarkdown(dynamic obj, [int depth = 2]) {
    if (obj == null) return '';
    if (obj is String) return obj;
    if (obj is num || obj is bool) return obj.toString();

    if (obj is List) {
      return obj.map((e) {
        if (e is Map || e is List) {
          return _jsonToMarkdown(e, depth + 1);
        }
        return '- $e';
      }).join('\n');
    }

    if (obj is Map) {
      List<String> lines = [];
      obj.forEach((key, value) {
        // Formate la clé : "resume_executif" -> "Resume Executif"
        String formattedKey = key.toString().replaceAll('_', ' ').replaceAllMapped(
            RegExp(r'\b\w'), (match) => match.group(0)!.toUpperCase());

        if (value is Map || (value is List && value.any((e) => e is Map || e is List))) {
          String heading = List.filled(depth > 6 ? 6 : depth, '#').join('');
          lines.add('\n$heading $formattedKey\n');
          lines.add(_jsonToMarkdown(value, depth + 1));
        } else if (value is List) {
           String heading = List.filled(depth > 6 ? 6 : depth, '#').join('');
           lines.add('\n$heading $formattedKey\n');
           for (var item in value) {
              lines.add('- $item');
           }
        } else {
          lines.add('- **$formattedKey** : $value');
        }
      });
      return lines.join('\n');
    }
    return obj.toString();
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
