// lib/presentation/thix_ia/widgets/project_header.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/thix_project.dart';
import '../core/extensions/project_extensions.dart';

/// ============================================================================
/// PROJECT HEADER - Détail projet avec actions rapides
/// ============================================================================

class ProjectHeader extends StatelessWidget {
  const ProjectHeader({
    super.key,
    required this.project,
    required this.progress,
    this.nextActions = const [],
    this.onActionTap,
  });

  final ThixProject project;
  final double progress;
  final List<String> nextActions;
  final Function(String)? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s8, ThixPolicy.s16, ThixPolicy.s20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ThixPolicy.surface, ThixPolicy.surface.withOpacity(0.9)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: project.status.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  border: Border.all(color: project.status.statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(project.status.statusIcon, size: 14, color: project.status.statusColor),
                    const SizedBox(width: 6),
                    Text(project.status.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: project.status.statusColor, fontWeight: ThixPolicy.bold)),
                  ],
                ),
              ),
              const Spacer(),
              Text(project.projectCode, style: ThixPolicy.captionStyle.copyWith(fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: ThixPolicy.s16),
          Text(project.name, style: ThixPolicy.h1Style.copyWith(fontSize: 24)),
          const SizedBox(height: ThixPolicy.s6),
          Text('${project.sector} • ${project.country}${project.city!= null? ' • ${project.city}' : ''}', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
          const SizedBox(height: ThixPolicy.s20),
          ClipRRect(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Avancement global', style: ThixPolicy.bodySmallStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                        Text('${(progress * 100).toInt()}%', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.primary)),
                      ],
                    ),
                    const SizedBox(height: ThixPolicy.s10),
                    LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: ThixPolicy.surfaceStrong, valueColor: const AlwaysStoppedAnimation(ThixPolicy.primary), borderRadius: BorderRadius.circular(3)),
                  ],
                ),
              ),
            ),
          ),
          if (nextActions.isNotEmpty)...[
            const SizedBox(height: ThixPolicy.s16),
            Text('Prochaines étapes', style: ThixPolicy.labelStyle),
            const SizedBox(height: ThixPolicy.s8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: nextActions.map((action) {
                return GestureDetector(
                  onTap: () => onActionTap?.call(action),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: ThixPolicy.primary.withOpacity(0.2))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: ThixPolicy.primary),
                        const SizedBox(width: 6),
                        Text(action, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.medium)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
