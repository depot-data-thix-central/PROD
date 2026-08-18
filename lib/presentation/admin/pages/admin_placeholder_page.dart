import 'package:flutter/material.dart';
import 'package:thix_id/theme.dart';

/// Clean placeholder page with premium cyber styling.
class AdminPlaceholderPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const AdminPlaceholderPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            color: AdminCyberColors.panel.withValues(alpha: 0.78),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AdminCyberGradients.glowBlue(),
                  boxShadow: [BoxShadow(color: AdminCyberColors.neonCyan.withValues(alpha: 0.12), blurRadius: 18, spreadRadius: 2)],
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AdminCyberColors.text)),
                    const SizedBox(height: 6),
                    Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.5)),
                    const SizedBox(height: 14),
                    Text(
                      'Next: connect tables + RLS policies, then wire realtime streams (Postgres Changes).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
