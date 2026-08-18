import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/theme.dart';

/// Compatibility entrypoint.
///
/// The actual Enterprise dashboard is accessible via the Web Verification Portal
/// routes: `/company/:slug/dashboard/...` (host-restricted).
///
/// This page exists because older flows may still navigate to `/enterprise-dashboard`.
class EnterpriseDashboardPage extends StatelessWidget {
  const EnterpriseDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;
    if (!auth.isAuthenticated || me == null) {
      return Scaffold(
        backgroundColor: AdminCyberColors.black,
        body: Center(
          child: Text('Connexion requise', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
        ),
      );
    }

    if (me.accountType == AccountType.personal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(AppRoutes.userDashboard);
      });
      return const SizedBox.shrink();
    }

    final slug = _slugify(me.displayName);
    // If web+allowed host, redirect to portal dashboard.
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host == 'verify.thixid.com' || host == 'localhost' || host == '127.0.0.1' || host.endsWith('.share.dreamflow.app')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.go(AppRoutes.enterprisePortalDashboard(slug, 'overview'));
        });
        return const SizedBox.shrink();
      }
    }

    // Mobile / non-portal host: show info.
    return Scaffold(
      backgroundColor: AdminCyberColors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AdminCyberColors.panel.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: AdminCyberColors.neonCyan, size: 46),
                  const SizedBox(height: AppSpacing.md),
                  Text('Enterprise Dashboard (Web-only)', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(
                    'Pour des raisons de sécurité, ce dashboard est accessible uniquement via le portail web: verify.thixid.com',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SelectableText(
                    'https://verify.thixid.com/company/$slug',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.text),
                    textAlign: TextAlign.center,
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

String _slugify(String input) {
  final s = input.trim().toLowerCase();
  if (s.isEmpty) return 'company';
  final buf = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final ok = (r >= 97 && r <= 122) || (r >= 48 && r <= 57);
    if (ok) {
      buf.write(ch);
      continue;
    }
    if (ch == ' ' || ch == '_' || ch == '-') {
      if (buf.isNotEmpty && !buf.toString().endsWith('-')) buf.write('-');
    }
  }
  final out = buf.toString().replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return out.isEmpty ? 'company' : out;
}
