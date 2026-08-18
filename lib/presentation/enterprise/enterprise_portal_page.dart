import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/theme.dart';

/// THIX ID Web Verification Portal (Enterprise entrypoint).
///
/// This is the ONLY entrypoint to the Enterprise dashboard in web context.
/// Example: https://verify.thixid.com/company/company-name
class EnterprisePortalPage extends StatefulWidget {
  final String companySlug;
  const EnterprisePortalPage({super.key, required this.companySlug});

  @override
  State<EnterprisePortalPage> createState() => _EnterprisePortalPageState();
}

class _EnterprisePortalPageState extends State<EnterprisePortalPage> {
  bool _autoNavDone = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;

    final hostAllowed = _EnterpriseWebGate.isAllowedHost();
    if (!hostAllowed) {
      return const _EnterpriseBlockedHost();
    }

    // If already logged in with enterprise account, jump straight to dashboard.
    if (!_autoNavDone && auth.isAuthenticated && me != null && me.accountType.name == 'enterprise') {
      _autoNavDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(AppRoutes.enterprisePortalDashboard(widget.companySlug, 'overview'));
      });
    }

    return Scaffold(
      backgroundColor: AdminCyberColors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AdminCyberColors.black,
              AdminCyberColors.panel.withValues(alpha: 0.95),
              const Color(0xFF02050B),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 820;
                  return isNarrow
                      ? _PortalStack(companySlug: widget.companySlug)
                      : Row(
                          children: [
                            const Expanded(child: _PortalLeft()),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(child: _PortalRight(companySlug: widget.companySlug)),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalStack extends StatelessWidget {
  final String companySlug;
  const _PortalStack({required this.companySlug});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PortalLeft(compact: true),
        const SizedBox(height: AppSpacing.lg),
        _PortalRight(companySlug: companySlug),
      ],
    );
  }
}

class _PortalLeft extends StatelessWidget {
  final bool compact;
  const _PortalLeft({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _CyberGlassPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(gradient: AdminCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(AppRadius.lg)),
                alignment: Alignment.center,
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIX ID • Verification Portal', style: t.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Enterprise Digital Trust Infrastructure', style: t.bodySmall?.copyWith(color: AdminCyberColors.textDim, height: 1.3)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Secure access to:', style: t.labelLarge?.copyWith(color: AdminCyberColors.textDim, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
          const SizedBox(height: AppSpacing.sm),
          const _PortalBullet(icon: Icons.verified_user_rounded, text: 'Identity verification & trust scoring'),
          const _PortalBullet(icon: Icons.security_rounded, text: 'AI cybersecurity & fraud monitoring'),
          const _PortalBullet(icon: Icons.people_alt_rounded, text: 'HR + onboarding + attendance'),
          const _PortalBullet(icon: Icons.work_rounded, text: 'Recruitment + verified CV'),
          const _PortalBullet(icon: Icons.gavel_rounded, text: 'Compliance & audit exports'),
          const _PortalBullet(icon: Icons.folder_shared_rounded, text: 'Enterprise corporate document vault'),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AdminCyberColors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.75)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: AdminCyberColors.neonCyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This portal enforces device/IP verification and session security (edge function).',
                      style: t.bodySmall?.copyWith(color: AdminCyberColors.textDim, height: 1.35),
                    ),
                  )
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _PortalRight extends StatelessWidget {
  final String companySlug;
  const _PortalRight({required this.companySlug});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _CyberGlassPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enterprise Sign-In', style: t.titleLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Company: $companySlug', style: t.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                // We reuse the existing Login page (Supabase email/password).
                // After login, the router already sends enterprise accounts to EnterpriseDashboard.
                // The portal page also auto-navigates to /company/:slug/dashboard.
                context.go(AppRoutes.login);
              },
              icon: const Icon(Icons.login_rounded, color: Colors.white),
              label: Text('Login (Verified enterprise account)', style: t.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.electricBlue, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.enterpriseReg),
            icon: const Icon(Icons.apartment_rounded, color: AdminCyberColors.neonCyan),
            label: Text('Register / KYB onboarding', style: t.labelLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PortalLinks(companySlug: companySlug),
        ],
      ),
    );
  }
}

class _PortalLinks extends StatelessWidget {
  final String companySlug;
  const _PortalLinks({required this.companySlug});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final base = 'https://verify.thixid.com/company/$companySlug';
    final links = <String, String>{
      'Verification portal': base,
      'Enterprise dashboard': '$base/dashboard/overview',
      'Recruiter portal': 'https://verify.thixid.com/recruiter?company=$companySlug',
      'Employee onboarding': 'https://verify.thixid.com/onboarding?company=$companySlug',
      'Candidate verification': 'https://verify.thixid.com/verify?company=$companySlug',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Auto-generated links', style: t.labelLarge?.copyWith(color: AdminCyberColors.textDim, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.sm),
        ...links.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LinkRow(label: e.key, value: e.value),
          ),
        )
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String value;
  const _LinkRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminCyberColors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelSmall?.copyWith(color: AdminCyberColors.textDim, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(value, style: t.bodySmall?.copyWith(color: AdminCyberColors.text, height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $label', style: t.bodySmall?.copyWith(color: Colors.white)),
                  backgroundColor: AdminCyberColors.panelHi,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(milliseconds: 1200),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: AdminCyberColors.neonCyan, size: 18),
          )
        ],
      ),
    );
  }
}

class _PortalBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PortalBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdminCyberColors.neonCyan),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: t.bodySmall?.copyWith(color: AdminCyberColors.text, height: 1.35))),
        ],
      ),
    );
  }
}

class _CyberGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _CyberGlassPanel({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        boxShadow: [BoxShadow(color: AdminCyberColors.neonCyan.withValues(alpha: 0.08), blurRadius: 22, spreadRadius: 1)],
      ),
      child: child,
    );
  }
}

class _EnterpriseBlockedHost extends StatelessWidget {
  const _EnterpriseBlockedHost();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AdminCyberColors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _CyberGlassPanel(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AdminCyberColors.danger, size: 44),
                  const SizedBox(height: AppSpacing.md),
                  Text('Access restricted', style: t.headlineSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    'The Enterprise Dashboard is only accessible through the THIX ID Web Verification Portal (verify.thixid.com).',
                    style: t.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.5),
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

class _EnterpriseWebGate {
  static bool isAllowedHost() {
    if (!kIsWeb) return false;
    final host = Uri.base.host.toLowerCase();
    if (host == 'verify.thixid.com') return true;
    // allow local dev / preview
    if (host == 'localhost' || host == '127.0.0.1') return true;
    if (host.endsWith('.localhost')) return true;
    // allow Dreamflow share preview domains
    if (host.endsWith('.share.dreamflow.app')) return true;
    return false;
  }
}
