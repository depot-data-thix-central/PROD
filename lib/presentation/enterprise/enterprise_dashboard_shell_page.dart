import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/enterprise/enterprise_activity_service.dart';
import 'package:thix_id/services/enterprise/enterprise_metrics_service.dart';
import 'package:thix_id/services/enterprise/enterprise_rbac_service.dart';
import 'package:thix_id/services/enterprise/enterprise_session_service.dart';
import 'package:thix_id/theme.dart';

/// Ultra-premium Enterprise dashboard (desktop-first shell).
///
/// NOTE: Security is enforced at DB level via Supabase RLS. UI-level guards:
/// - Web-only
/// - Host must be verify.thixid.com (or localhost for dev)
/// - Supabase authenticated
/// - Enterprise account type
/// - Membership role is required for the company
class EnterpriseDashboardShellPage extends StatefulWidget {
  final String companySlug;
  final String section;
  const EnterpriseDashboardShellPage({super.key, required this.companySlug, required this.section});

  @override
  State<EnterpriseDashboardShellPage> createState() => _EnterpriseDashboardShellPageState();
}

class _EnterpriseDashboardShellPageState extends State<EnterpriseDashboardShellPage> {
  late final EnterpriseMetricsService _metrics = EnterpriseMetricsService();
  late final EnterpriseActivityService _activity = EnterpriseActivityService();
  late final EnterpriseRbacService _rbac = EnterpriseRbacService();
  late final EnterpriseSessionService _sessions = EnterpriseSessionService();

  Future<_GateResult> _gate(BuildContext context) async {
    if (!kIsWeb) return _GateResult.denied('Web only');
    final host = Uri.base.host.toLowerCase();
    if (!(host == 'verify.thixid.com' || host == 'localhost' || host == '127.0.0.1')) {
      return _GateResult.denied('Host not allowed');
    }

    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated || auth.currentUser == null) return _GateResult.denied('Login required');
    if (auth.currentUser!.accountType != AccountType.enterprise) return _GateResult.denied('Enterprise account required');

    final role = await _rbac.fetchMyRole(companySlug: widget.companySlug);
    if (role == null) return _GateResult.denied('No enterprise role for this company');

    // Best-effort: create/refresh secure session (device/IP verification) once per view.
    await _sessions.ensureSecureSession(companySlug: widget.companySlug);

    return _GateResult.allowed(role);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _gate(context),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const _EnterpriseLoading();
        }
        final gate = snap.data!;
        if (!gate.allowed) {
          return _EnterpriseDenied(message: gate.message ?? 'Denied');
        }
        return _EnterpriseShell(
          companySlug: widget.companySlug,
          section: widget.section,
          role: gate.role!,
          metrics: _metrics,
          activity: _activity,
        );
      },
    );
  }
}

class _EnterpriseShell extends StatelessWidget {
  final String companySlug;
  final String section;
  final String role;
  final EnterpriseMetricsService metrics;
  final EnterpriseActivityService activity;

  const _EnterpriseShell({
    required this.companySlug,
    required this.section,
    required this.role,
    required this.metrics,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AdminCyberColors.black,
      body: Row(
        children: [
          _SideNav(companySlug: companySlug, active: section, role: role),
          Expanded(
            child: Column(
              children: [
                _TopBar(companySlug: companySlug, role: role),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _SectionBody(
                      key: ValueKey<String>(section),
                      section: section,
                      companySlug: companySlug,
                      metrics: metrics,
                      activity: activity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String companySlug;
  final String role;
  const _TopBar({required this.companySlug, required this.role});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AdminCyberColors.panel.withValues(alpha: 0.74),
        border: Border(bottom: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(companySlug.toUpperCase(), style: t.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text('Role: $role • Secure session', style: t.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
              ],
            ),
          ),
          _Pill(label: 'Trust: 92', icon: Icons.verified_rounded, color: AdminCyberColors.neonCyan),
          const SizedBox(width: 10),
          _Pill(label: 'Alerts: 3', icon: Icons.warning_rounded, color: AdminCyberColors.danger),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Open chat',
            onPressed: () => context.push(AppRoutes.chat),
            icon: const Icon(Icons.chat_rounded, color: AdminCyberColors.neonCyan),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_rounded, color: AdminCyberColors.textDim),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              gradient: AdminCyberGradients.glowViolet(),
            ),
            alignment: Alignment.center,
            child: Text((me?.displayName ?? 'E').trim().isEmpty ? 'E' : (me!.displayName.trim()[0]).toUpperCase(), style: t.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final String companySlug;
  final String active;
  final String role;
  const _SideNav({required this.companySlug, required this.active, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      decoration: BoxDecoration(
        color: AdminCyberColors.panelHi.withValues(alpha: 0.78),
        border: Border(right: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(gradient: AdminCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THIX ENTERPRISE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                        const SizedBox(height: 2),
                        Text(companySlug, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    _NavItem(companySlug: companySlug, id: 'overview', label: 'Overview', icon: Icons.grid_view_rounded, active: active == 'overview'),
                    _NavItem(companySlug: companySlug, id: 'identity', label: 'Identity Monitor', icon: Icons.verified_user_rounded, active: active == 'identity'),
                    _NavItem(companySlug: companySlug, id: 'vault', label: 'Corporate Vault', icon: Icons.lock_rounded, active: active == 'vault'),
                    _NavItem(companySlug: companySlug, id: 'delegation', label: 'Delegated Authority', icon: Icons.rule_rounded, active: active == 'delegation'),
                    _NavItem(companySlug: companySlug, id: 'onboarding', label: 'Onboarding', icon: Icons.person_add_alt_1_rounded, active: active == 'onboarding'),
                    _NavItem(companySlug: companySlug, id: 'attendance', label: 'Attendance', icon: Icons.qr_code_scanner_rounded, active: active == 'attendance'),
                    _NavItem(companySlug: companySlug, id: 'recruitment', label: 'Recruitment', icon: Icons.work_rounded, active: active == 'recruitment'),
                    _NavItem(companySlug: companySlug, id: 'compliance', label: 'Compliance & Audit', icon: Icons.gavel_rounded, active: active == 'compliance'),
                    _NavItem(companySlug: companySlug, id: 'comms', label: 'Secure Comms', icon: Icons.forum_rounded, active: active == 'comms'),
                    _NavItem(companySlug: companySlug, id: 'visitors', label: 'Visitors', icon: Icons.badge_rounded, active: active == 'visitors'),
                    _NavItem(companySlug: companySlug, id: 'cyber', label: 'AI Cybersecurity', icon: Icons.security_rounded, active: active == 'cyber'),
                    _NavItem(companySlug: companySlug, id: 'integrations', label: 'API & Integrations', icon: Icons.hub_rounded, active: active == 'integrations'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminCyberColors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.75)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: AdminCyberColors.neonCyan, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Smart QR verification links', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim))),
                    IconButton(
                      tooltip: 'Copy base link',
                      onPressed: () {
                        final link = 'https://verify.thixid.com/company/$companySlug';
                        // ignore: deprecated_member_use
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied verification portal link'), duration: Duration(milliseconds: 900), behavior: SnackBarBehavior.floating),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: AdminCyberColors.textDim, size: 18),
                    )
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

class _NavItem extends StatelessWidget {
  final String companySlug;
  final String id;
  final String label;
  final IconData icon;
  final bool active;
  const _NavItem({required this.companySlug, required this.id, required this.label, required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => context.go(AppRoutes.enterprisePortalDashboard(companySlug, id)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: active ? AdminCyberColors.electricBlue.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(color: active ? AdminCyberColors.electricBlue.withValues(alpha: 0.55) : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? AdminCyberColors.neonCyan : AdminCyberColors.textDim),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: active ? AdminCyberColors.text : AdminCyberColors.textDim, fontWeight: active ? FontWeight.w800 : FontWeight.w600))),
              if (active) const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AdminCyberColors.neonCyan),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String section;
  final String companySlug;
  final EnterpriseMetricsService metrics;
  final EnterpriseActivityService activity;
  const _SectionBody({super.key, required this.section, required this.companySlug, required this.metrics, required this.activity});

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case 'overview':
        return _OverviewSection(companySlug: companySlug, metrics: metrics, activity: activity);
      default:
        return _ComingSoonSection(title: section);
    }
  }
}

class _OverviewSection extends StatelessWidget {
  final String companySlug;
  final EnterpriseMetricsService metrics;
  final EnterpriseActivityService activity;
  const _OverviewSection({required this.companySlug, required this.metrics, required this.activity});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AdminCyberColors.black, AdminCyberColors.panel.withValues(alpha: 0.4)]),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Main Enterprise Overview', style: t.headlineSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
                ),
                _GlowButton(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  onPressed: () => metrics.invalidate(companySlug: companySlug),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FutureBuilder(
              future: metrics.fetchOverview(companySlug: companySlug),
              builder: (context, snap) {
                final m = snap.data;
                return _MetricGrid(metrics: m);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 1100;
                if (isNarrow) {
                  return Column(
                    children: [
                      _AnalyticsPanel(companySlug: companySlug, metrics: metrics),
                      const SizedBox(height: AppSpacing.lg),
                      _ActivityFeed(companySlug: companySlug, activity: activity),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _AnalyticsPanel(companySlug: companySlug, metrics: metrics)),
                    const SizedBox(width: AppSpacing.lg),
                    SizedBox(width: 420, child: _ActivityFeed(companySlug: companySlug, activity: activity)),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _LinksPanel(companySlug: companySlug),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final EnterpriseOverviewMetrics? metrics;
  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics ?? EnterpriseOverviewMetrics.placeholder();
    return LayoutBuilder(
      builder: (context, c) {
        final crossAxisCount = c.maxWidth < 900 ? 2 : 4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.2,
          children: [
            _MetricCard(title: 'Total employees', value: '${m.totalEmployees}', icon: Icons.people_alt_rounded, accent: AdminCyberColors.neonCyan),
            _MetricCard(title: 'Verified employees', value: '${m.verifiedEmployees}', icon: Icons.verified_rounded, accent: AdminCyberColors.success),
            _MetricCard(title: 'Verification requests', value: '${m.verificationRequests}', icon: Icons.fact_check_rounded, accent: AdminCyberColors.electricBlue),
            _MetricCard(title: 'Security alerts', value: '${m.securityAlerts}', icon: Icons.warning_rounded, accent: AdminCyberColors.danger),
            _MetricCard(title: 'Active users', value: '${m.activeUsers}', icon: Icons.bolt_rounded, accent: AdminCyberColors.neonViolet),
            _MetricCard(title: 'Attendance today', value: '${m.attendanceToday}', icon: Icons.qr_code_scanner_rounded, accent: AdminCyberColors.neonCyan),
            _MetricCard(title: 'Fraud attempts', value: '${m.fraudAttempts}', icon: Icons.shield_moon_rounded, accent: AdminCyberColors.danger),
            _MetricCard(title: 'Compliance status', value: m.complianceStatus, icon: Icons.gavel_rounded, accent: AdminCyberColors.success),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  const _MetricCard({required this.title, required this.value, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withValues(alpha: 0.95), AdminCyberColors.panelHi]),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: t.titleLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(title, style: t.bodySmall?.copyWith(color: AdminCyberColors.textDim), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  final String companySlug;
  final EnterpriseMetricsService metrics;
  const _AnalyticsPanel({required this.companySlug, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Advanced Analytics', style: t.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
              _Pill(label: 'Realtime', icon: Icons.waves_rounded, color: AdminCyberColors.neonCyan),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 260,
            child: _MiniLineChart(seed: companySlug.hashCode),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 190,
            child: Row(
              children: const [
                Expanded(child: _RiskBars()),
                SizedBox(width: 14),
                Expanded(child: _DepartmentActivity()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  final String companySlug;
  final EnterpriseActivityService activity;
  const _ActivityFeed({required this.companySlug, required this.activity});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Real-time Activity', style: t.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
              Icon(Icons.timeline_rounded, color: AdminCyberColors.neonCyan.withValues(alpha: 0.9), size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 420,
            child: StreamBuilder(
              stream: activity.stream(companySlug: companySlug, limit: 30),
              builder: (context, snap) {
                final items = snap.data ?? const <EnterpriseActivityItem>[];
                if (items.isEmpty) {
                  return Center(child: Text('No activity yet.', style: t.bodyMedium?.copyWith(color: AdminCyberColors.textDim)));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ActivityRow(item: items[i]),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final EnterpriseActivityItem item;
  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Color accent;
    IconData icon;
    switch (item.type) {
      case 'security_alert':
        accent = AdminCyberColors.danger;
        icon = Icons.warning_rounded;
        break;
      case 'verification':
        accent = AdminCyberColors.neonCyan;
        icon = Icons.verified_user_rounded;
        break;
      default:
        accent = AdminCyberColors.electricBlue;
        icon = Icons.bolt_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminCyberColors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: t.bodyMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.subtitle, style: t.bodySmall?.copyWith(color: AdminCyberColors.textDim, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(item.timeLabel, style: t.labelSmall?.copyWith(color: AdminCyberColors.textDim)),
        ],
      ),
    );
  }
}

class _LinksPanel extends StatelessWidget {
  final String companySlug;
  const _LinksPanel({required this.companySlug});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final base = 'https://verify.thixid.com/company/$companySlug';
    final items = <Map<String, dynamic>>[
      {'label': 'Enterprise dashboard', 'value': '$base/dashboard/overview', 'icon': Icons.grid_view_rounded},
      {'label': 'Employee onboarding link', 'value': 'https://verify.thixid.com/onboarding?company=$companySlug', 'icon': Icons.person_add_alt_1_rounded},
      {'label': 'Recruiter portal', 'value': 'https://verify.thixid.com/recruiter?company=$companySlug', 'icon': Icons.work_rounded},
      {'label': 'Candidate verification', 'value': 'https://verify.thixid.com/verify?company=$companySlug', 'icon': Icons.verified_user_rounded},
      {'label': 'Smart QR verification', 'value': 'https://verify.thixid.com/qr?company=$companySlug', 'icon': Icons.qr_code_2_rounded},
    ];
    return _GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Auto-generated links', style: t.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.md),
          ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _LinkTile(icon: e['icon'] as IconData, label: e['label'] as String, value: e['value'] as String))),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LinkTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminCyberColors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdminCyberColors.neonCyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelSmall?.copyWith(color: AdminCyberColors.textDim, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(value, style: t.bodySmall?.copyWith(color: AdminCyberColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Copy',
            onPressed: () {
              // ignore: deprecated_member_use
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied link'), duration: Duration(milliseconds: 900), behavior: SnackBarBehavior.floating));
            },
            icon: const Icon(Icons.copy_rounded, color: AdminCyberColors.textDim, size: 18),
          )
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Pill({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminCyberColors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _GlowButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(label, style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminCyberColors.electricBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        boxShadow: [BoxShadow(color: AdminCyberColors.neonCyan.withValues(alpha: 0.06), blurRadius: 20, spreadRadius: 1)],
      ),
      child: child,
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  final int seed;
  const _MiniLineChart({required this.seed});

  @override
  Widget build(BuildContext context) {
    final rng = Random(seed);
    final spots = List.generate(12, (i) => FlSpot(i.toDouble(), 40 + rng.nextInt(55) + (i * 1.8)));
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AdminCyberColors.neonCyan,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AdminCyberColors.neonCyan.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );
  }
}

class _RiskBars extends StatelessWidget {
  const _RiskBars();

  @override
  Widget build(BuildContext context) {
    final groups = <BarChartGroupData>[
      _bg(0, 10, AdminCyberColors.success),
      _bg(1, 24, AdminCyberColors.neonCyan),
      _bg(2, 18, AdminCyberColors.electricBlue),
      _bg(3, 32, AdminCyberColors.danger),
    ];
    return _MiniChartCard(
      title: 'Risk analysis',
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
      ),
    );
  }

  BarChartGroupData _bg(int x, double y, Color c) => BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, width: 10, color: c, borderRadius: BorderRadius.circular(6))]);
}

class _DepartmentActivity extends StatelessWidget {
  const _DepartmentActivity();

  @override
  Widget build(BuildContext context) {
    return _MiniChartCard(
      title: 'Department activity',
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 28,
          sections: [
            PieChartSectionData(value: 36, color: AdminCyberColors.neonCyan, radius: 40, title: ''),
            PieChartSectionData(value: 22, color: AdminCyberColors.electricBlue, radius: 38, title: ''),
            PieChartSectionData(value: 18, color: AdminCyberColors.neonViolet, radius: 36, title: ''),
            PieChartSectionData(value: 24, color: AdminCyberColors.stroke, radius: 34, title: ''),
          ],
        ),
      ),
    );
  }
}

class _MiniChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _MiniChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminCyberColors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.labelLarge?.copyWith(color: AdminCyberColors.textDim, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ComingSoonSection extends StatelessWidget {
  final String title;
  const _ComingSoonSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AdminCyberColors.neonCyan, size: 44),
                const SizedBox(height: AppSpacing.md),
                Text('Module "$title"', style: t.headlineSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('This section is scaffolded and ready for Supabase-backed data and actions.', style: t.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.5), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnterpriseDenied extends StatelessWidget {
  final String message;
  const _EnterpriseDenied({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AdminCyberColors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _GlassCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: AdminCyberColors.danger, size: 44),
                  const SizedBox(height: AppSpacing.md),
                  Text('Access denied', style: t.headlineSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(message, style: t.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.5), textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(AppRoutes.login),
                      icon: const Icon(Icons.login_rounded, color: Colors.white),
                      label: Text('Go to login', style: t.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.electricBlue, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnterpriseLoading extends StatelessWidget {
  const _EnterpriseLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AdminCyberColors.black,
      body: Center(child: CircularProgressIndicator(color: AdminCyberColors.neonCyan)),
    );
  }
}

class _GateResult {
  final bool allowed;
  final String? role;
  final String? message;
  const _GateResult._(this.allowed, this.role, this.message);

  factory _GateResult.allowed(String role) => _GateResult._(true, role, null);
  factory _GateResult.denied(String message) => _GateResult._(false, null, message);
}
