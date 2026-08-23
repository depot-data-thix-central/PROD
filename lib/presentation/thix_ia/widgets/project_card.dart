// lib/presentation/thix_ia/widgets/project_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/thix_project.dart';
import '../core/extensions/project_extensions.dart';
import '../core/utils/text_utils.dart';

/// ============================================================================
/// PROJECT CARD - Glass + Hover + Progress réelle
/// ============================================================================

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.onLongPress,
    this.isActive = false,
  });

  final ThixProject project;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: isActive? ThixPolicy.primary : ThixPolicy.border, width: isActive? 1.5 : 1),
          boxShadow: isActive? ThixPolicy.shadowCard(opacity: 0.15) : ThixPolicy.shadowCard(opacity: 0.06),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              decoration: BoxDecoration(
                color: isActive? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.75),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: project.status.statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                        ),
                        child: Icon(project.status.statusIcon, size: 20, color: project.status.statusColor),
                      ),
                      const SizedBox(width: ThixPolicy.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                            const SizedBox(height: 2),
                            Text('${project.projectCode.shortProjectCode} • ${project.country}${project.city!= null? ' • ${project.city}' : ''}', style: ThixPolicy.captionStyle),
                          ],
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                          child: Text('ACTIF', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                        ),
                    ],
                  ),
                  if (project.summary!= null && project.summary!.isNotEmpty)...[
                    const SizedBox(height: ThixPolicy.s10),
                    Text(TextUtils.truncate(project.summary!, 90), style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary), maxLines: 2),
                  ],
                  const SizedBox(height: ThixPolicy.s12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Progression', style: ThixPolicy.microStyle),
                                Text('${(project.progress * 100).toInt()}%', style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: project.progress,
                                minHeight: 4,
                                backgroundColor: ThixPolicy.surfaceStrong,
                                valueColor: AlwaysStoppedAnimation(project.status.statusColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: ThixPolicy.s16),
                      _StatChip(icon: Icons.analytics_rounded, count: project.analysesCount),
                      const SizedBox(width: ThixPolicy.s8),
                      _StatChip(icon: Icons.folder_rounded, count: project.documentsCount),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ThixPolicy.textMuted),
          const SizedBox(width: 4),
          Text('$count', style: ThixPolicy.microStyle),
        ],
      ),
    );
  }
}
