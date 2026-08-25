// lib/presentation/thix_ia/widgets/fact_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 👈 IMPORT AJOUTÉ ICI
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_memory.dart';
import '../core/extensions/analysis_extensions.dart';
import '../core/utils/text_utils.dart';

/// ============================================================================
/// FACT CARD - Affichage fait sourcé §13 cahier
/// Chaque fait doit afficher source, confiance, date
/// ============================================================================

class FactCard extends StatelessWidget {
  const FactCard({super.key, required this.fact, this.onVerify, this.onQuestion});

  final ProjectFact fact;
  final VoidCallback? onVerify;
  final VoidCallback? onQuestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        color: Colors.white,
        boxShadow: ThixPolicy.shadowCard(opacity: 0.04),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header type + confiance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s8),
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.06),
                border: Border(bottom: BorderSide(color: ThixPolicy.border.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _typeColor, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                    child: Text(fact.type.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, fontSize: 9)),
                  ),
                  const SizedBox(width: 8),
                  Icon(_typeIcon, size: 14, color: _typeColor),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: fact.confidence.color.withOpacity(0.12), borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 10, color: fact.confidence.color),
                        const SizedBox(width: 4),
                        Text('${(fact.confidence * 100).toInt()}% • ${fact.confidence.label}', style: ThixPolicy.microStyle.copyWith(color: fact.confidence.color, fontWeight: ThixPolicy.semiBold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(ThixPolicy.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👇 REMPLACEMENT ICI : MarkdownBody au lieu de Text
                  MarkdownBody(
                    data: fact.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: ThixPolicy.bodyStyle.copyWith(height: 1.4),
                      listBullet: ThixPolicy.bodyStyle,
                      h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (fact.sourceName!= null || fact.sourceUrl!= null)...[
                    const SizedBox(height: ThixPolicy.s10),
                    GestureDetector(
                      onTap: fact.sourceUrl!= null? () => _openUrl(fact.sourceUrl!) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)),
                        child: Row(
                          children: [
                            Icon(Icons.link_rounded, size: 14, color: ThixPolicy.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (fact.sourceName!= null) Text(fact.sourceName!, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (fact.sourceUrl!= null) Text(TextUtils.truncate(fact.sourceUrl!, 50), style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.info)),
                                ],
                              ),
                            ),
                            if (fact.sourceUrl!= null) Icon(Icons.open_in_new_rounded, size: 12, color: ThixPolicy.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: ThixPolicy.s10),
                  Row(
                    children: [
                      if (fact.dateCollected!= null) _Meta(icon: Icons.calendar_today_rounded, text: 'Collecté ${fact.dateCollected!.timeAgo}'),
                      if (fact.dateVerified!= null)...[
                        const SizedBox(width: 12),
                        _Meta(icon: Icons.verified_user_rounded, text: 'Vérifié ${fact.dateVerified!.timeAgo}'),
                      ],
                      const Spacer(),
                      if (onVerify!= null)
                        GestureDetector(
                          onTap: onVerify,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: ThixPolicy.info.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                            child: Text('Vérifier', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.info, fontWeight: ThixPolicy.semiBold)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _typeColor {
    switch (fact.type) {
      case 'fact': return ThixPolicy.info;
      case 'estimation': return ThixPolicy.warning;
      case 'hypothesis': return ThixPolicy.textSecondary;
      case 'recommendation': return ThixPolicy.success;
      default: return ThixPolicy.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (fact.type) {
      case 'fact': return Icons.check_circle_rounded;
      case 'estimation': return Icons.calculate_rounded;
      case 'hypothesis': return Icons.lightbulb_rounded;
      case 'recommendation': return Icons.star_rounded;
      default: return Icons.article_rounded;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri!= null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: ThixPolicy.textMuted),
        const SizedBox(width: 4),
        Text(text, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
      ],
    );
  }
}

extension _TimeAgo on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }
}
