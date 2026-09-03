/// Upload Progress Indicator (Production Enterprise)
/// 
/// Widget réutilisable pour afficher la progression d'un upload.
/// 
/// **Usage** :
/// ```dart
/// UploadProgress(
///   progress: 0.5,
///   status: 'Upload en cours...',
///   fileName: 'video.mp4', // optionnel
///   secondaryStatus: '2.3 MB / 4.6 MB', // optionnel
/// )
/// ```
/// 
/// **Compatibilité legacy** :
/// ```dart
/// UploadProgress.simple(progress: 0.5, status: '...')
/// ```
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// WIDGET
// ============================================================================

class UploadProgress extends StatelessWidget {
  /// Progression de 0.0 à 1.0
  final double progress;
  
  /// Nom du fichier (optionnel)
  final String fileName;
  
  /// Statut principal (traduit par le caller)
  final String status;
  
  /// Statut secondaire optionnel (ex: "2.3 MB / 4.6 MB")
  final String? secondaryStatus;

  const UploadProgress({
    super.key,
    this.progress = 0,
    this.fileName = '',
    required this.status,
    this.secondaryStatus,
  });

  /// Factory pour compatibilité avec ancien appel simple
  factory UploadProgress.simple({
    required double progress,
    required String status,
  }) {
    return UploadProgress(progress: progress, fileName: '', status: status);
  }

  @override
  Widget build(BuildContext context) {
    // Validation robuste
    final safeProgress = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final pct = (safeProgress * 100).toInt();
    final isDone = safeProgress >= 0.99;

    return RepaintBoundary(
      child: Semantics(
        label: '$status, $pct%',
        value: '$pct%',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone
                  ? ThixPolicy.success.withValues(alpha: 0.3)
                  : ThixPolicy.border,
            ),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.inkDeep.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icône d'état
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDone
                          ? ThixPolicy.success.withValues(alpha: 0.15)
                          : ThixPolicy.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone ? Icons.check_rounded : Icons.cloud_upload_rounded,
                      size: 16,
                      color: isDone ? ThixPolicy.success : ThixPolicy.primary,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Texte (fichier + statut)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fileName.isNotEmpty)
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ThixPolicy.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: fileName.isNotEmpty ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: fileName.isNotEmpty
                                ? ThixPolicy.textMuted
                                : ThixPolicy.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Pourcentage animé
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: safeProgress),
                    duration: const Duration(milliseconds: 400),
                    builder: (c, v, _) => Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDone ? ThixPolicy.success : ThixPolicy.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Barre de progression animée
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: safeProgress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (c, v, _) => LinearProgressIndicator(
                    value: v == 0 ? null : v,
                    backgroundColor: ThixPolicy.border,
                    valueColor: AlwaysStoppedAnimation(
                      isDone ? ThixPolicy.success : ThixPolicy.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),

              // Statut secondaire
              if (secondaryStatus != null) ...[
                const SizedBox(height: 6),
                Text(
                  secondaryStatus!,
                  style: TextStyle(
                    fontSize: 10,
                    color: ThixPolicy.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
