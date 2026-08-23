// lib/presentation/thix_ia/widgets/active_project_selector.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/active_project_provider.dart';
import '../core/extensions/project_extensions.dart';

/// ============================================================================
/// ACTIVE PROJECT SELECTOR - Glassmorphism + ThixPolicy
/// ============================================================================

class ActiveProjectSelector extends ConsumerWidget {
  const ActiveProjectSelector({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeProjectProvider);
    final intelligenceAsync = ref.watch(projectIntelligenceProvider);

    return activeAsync.when(
      loading: () => const _Skeleton(),
      error: (_, __) => const _Empty(),
      data: (project) {
        if (project == null) return const _Empty();

        final progress = intelligenceAsync.value?.progress?? project.progress;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
              boxShadow: ThixPolicy.shadowCard(opacity: 0.08),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(ThixPolicy.s16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.85),
                        Colors.white.withOpacity(0.65),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icône glass
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: ThixPolicy.brandGradient,
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          boxShadow: ThixPolicy.shadowSoft(),
                        ),
                        child: Center(
                          child: Text(
                            project.name.isNotEmpty? project.name[0].toUpperCase() : 'P',
                            style: ThixPolicy.h2Style.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: ThixPolicy.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    project.name,
                                    style: ThixPolicy.titleStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: ThixPolicy.s8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: project.status.statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                                  ),
                                  child: Text(
                                    project.status.toUpperCase(),
                                    style: ThixPolicy.microStyle.copyWith(color: project.status.statusColor, fontWeight: ThixPolicy.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${project.projectCode.shortProjectCode} • ${project.sector}',
                              style: ThixPolicy.captionStyle,
                            ),
                            const SizedBox(height: ThixPolicy.s8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: ThixPolicy.surfaceStrong,
                                valueColor: AlwaysStoppedAnimation(ThixPolicy.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: ThixPolicy.s8),
                      Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      margin: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(ThixPolicy.s16),
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: ThixPolicy.textMuted),
          const SizedBox(width: ThixPolicy.s12),
          Text('Aucun projet actif', style: ThixPolicy.bodySmallStyle),
        ],
      ),
    );
  }
}
