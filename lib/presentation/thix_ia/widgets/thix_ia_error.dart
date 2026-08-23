// lib/presentation/thix_ia/widgets/thix_ia_error.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

class ThixIaError extends StatelessWidget {
  const ThixIaError({super.key, required this.message, this.onRetry, this.code, this.showReport = true});

  final String message;
  final VoidCallback? onRetry;
  final String? code;
  final bool showReport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, size: 36, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur THIX IA', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.danger)),
            const SizedBox(height: 8),
            Text(message, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary), textAlign: TextAlign.center),
            if (code != null)...[
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(6), border: Border.all(color: ThixPolicy.border)),
                child: Text('CODE: $code', style: ThixPolicy.microStyle.copyWith(fontFamily: 'monospace', color: ThixPolicy.textMuted)),
              ),
            ],
            const SizedBox(height: 24),
            if (onRetry != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  label: Text('Réessayer'),
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
                ),
              ),
            if (showReport)...[
              const SizedBox(height: 12),
              TextButton.icon(onPressed: () {}, icon: Icon(Icons.bug_report_outlined, size: 16, color: ThixPolicy.textMuted), label: Text('Signaler le bug', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted))),
            ],
          ],
        ),
      ),
    );
  }
}

class ThixIaInlineError extends StatelessWidget {
  const ThixIaInlineError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.06), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.danger.withOpacity(0.2))),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: ThixPolicy.danger),
        SizedBox(width: 8),
        Expanded(child: Text(message, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger))),
        if (onRetry != null) ...[SizedBox(width: 8), GestureDetector(onTap: onRetry, child: Text('Retry', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)))],
      ]),
    );
  }
}
