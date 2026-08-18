import 'package:flutter/material.dart';

import '../../theme.dart';

/// Full-screen message overlay (error / info) used when we want a clear
/// institutional feedback without changing routing.
class FullScreenMessage {
  static Future<void> showError(BuildContext context, {required String title, required String message}) {
    return _show(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: Colors.red.shade300,
      title: title,
      message: message,
    );
  }

  static Future<void> showInfo(BuildContext context, {required String title, required String message}) {
    return _show(
      context,
      icon: Icons.info_outline_rounded,
      iconColor: LightModeColors.accent,
      title: title,
      message: message,
    );
  }

  static Future<void> _show(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) {
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  margin: const EdgeInsets.all(AppSpacing.lg),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: iconColor.withValues(alpha: 0.25)),
                            ),
                            alignment: Alignment.center,
                            child: Icon(icon, color: iconColor, size: 24),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(title, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(message, style: context.textStyles.bodyMedium?.copyWith(height: 1.5, color: LightModeColors.secondaryText)),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.accent,
                            foregroundColor: const Color(0xFF0A2F5C),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Fermer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(curved), child: child));
      },
    );
  }
}
