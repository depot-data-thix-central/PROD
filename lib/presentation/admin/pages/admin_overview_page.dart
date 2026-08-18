import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:thix_id/services/admin_metrics_service.dart';
import 'package:thix_id/theme.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  final _metrics = AdminMetricsService();
  AdminGlobalMetrics? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _metrics.fetchGlobalMetrics();
      if (!mounted) return;
      setState(() => _data = m);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cols = size.width >= 1200 ? 4 : (size.width >= 900 ? 3 : (size.width >= 620 ? 2 : 1));

    if (_loading) return const _AdminLoadingState();
    if (_error != null) return _AdminErrorState(error: _error!, onRetry: _load);
    final data = _data ?? AdminGlobalMetrics.empty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onRefresh: _load),
          const SizedBox(height: AppSpacing.md),
          _StatGrid(cols: cols, children: [
            AdminStatCard(title: 'Total users', value: '${data.totalUsers}', icon: Icons.people_alt_rounded, gradient: AdminCyberGradients.glowBlue()),
            AdminStatCard(title: 'Active (7d)', value: '${data.activeUsers}', icon: Icons.bolt_rounded, gradient: AdminCyberGradients.glowViolet()),
            AdminStatCard(title: 'Verification requests', value: '${data.verificationRequests}', icon: Icons.verified_user_rounded, gradient: AdminCyberGradients.glowBlue()),
            AdminStatCard(title: 'Verified documents', value: '${data.verifiedDocuments}', icon: Icons.fact_check_rounded, gradient: AdminCyberGradients.glowViolet()),
            AdminStatCard(title: 'Emergency alerts', value: '${data.emergencyAlerts}', icon: Icons.sos_rounded, gradient: const LinearGradient(colors: [AdminCyberColors.danger, AdminCyberColors.neonViolet])),
            AdminStatCard(title: 'Jobs posted', value: '${data.jobsPosted}', icon: Icons.work_rounded, gradient: const LinearGradient(colors: [AdminCyberColors.success, AdminCyberColors.neonCyan])),
            AdminStatCard(title: 'Chats', value: '${data.chats}', icon: Icons.forum_rounded, gradient: AdminCyberGradients.glowBlue()),
            AdminStatCard(title: 'Messages', value: '${data.messages}', icon: Icons.chat_bubble_rounded, gradient: AdminCyberGradients.glowViolet()),
          ]),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: _Panel(
                      title: 'User growth (demo series)',
                      subtitle: 'Connect to your analytics table to replace this series.',
                      child: SizedBox(height: 260, child: _LineChart()),
                    ),
                  ),
                  SizedBox(width: isWide ? AppSpacing.md : 0, height: isWide ? 0 : AppSpacing.md),
                  Expanded(
                    flex: 5,
                    child: _Panel(
                      title: 'Security alerts (demo)',
                      subtitle: 'Realtime detections feed will appear here.',
                      child: const SizedBox(height: 260, child: _AlertsList()),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Global Overview', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 4),
              Text('Realtime platform signals • Identity, cybersecurity, institutions, SOS', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            foregroundColor: AdminCyberColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final int cols;
  final List<Widget> children;
  const _StatGrid({required this.cols, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final chunk = children.sublist(i, (i + cols).clamp(0, children.length));
      rows.add(Row(
        children: [
          for (final w in chunk) Expanded(child: Padding(padding: const EdgeInsets.all(6), child: w)),
          for (var j = 0; j < cols - chunk.length; j++) const Expanded(child: SizedBox()),
        ],
      ));
    }
    return Column(children: rows);
  }
}

class AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const AdminStatCard({super.key, required this.title, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        color: AdminCyberColors.panel.withValues(alpha: 0.78),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: gradient,
              boxShadow: [BoxShadow(color: AdminCyberColors.neonCyan.withValues(alpha: 0.12), blurRadius: 18, spreadRadius: 2)],
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AdminCyberColors.text, height: 1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Panel({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        color: AdminCyberColors.panel.withValues(alpha: 0.78),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      const FlSpot(0, 4),
      const FlSpot(1, 6),
      const FlSpot(2, 7),
      const FlSpot(3, 8),
      const FlSpot(4, 12),
      const FlSpot(5, 13),
      const FlSpot(6, 17),
    ];
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 4, getDrawingHorizontalLine: (v) => FlLine(color: AdminCyberColors.stroke.withValues(alpha: 0.35), strokeWidth: 1)),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AdminCyberColors.neonCyan,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(colors: [AdminCyberColors.neonCyan.withValues(alpha: 0.25), AdminCyberColors.neonCyan.withValues(alpha: 0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }
}

class _AlertsList extends StatelessWidget {
  const _AlertsList();

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Login anomaly', 'New device + impossible travel detected', Icons.warning_amber_rounded, AdminCyberColors.danger),
      ('RLS policy', 'Blocked write on protected table', Icons.policy_rounded, AdminCyberColors.neonViolet),
      ('DDoS spikes', 'Traffic burst mitigated by edge rules', Icons.router_rounded, AdminCyberColors.neonCyan),
      ('KYC risk', 'Document mismatch scoring high', Icons.verified_rounded, AdminCyberColors.electricBlue),
    ];
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final (title, desc, icon, color) = items[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.8)),
            color: AdminCyberColors.panelHi.withValues(alpha: 0.65),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withValues(alpha: 0.18), border: Border.all(color: color.withValues(alpha: 0.45))),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminCyberColors.text)),
                    const SizedBox(height: 2),
                    Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('LIVE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.neonCyan)),
            ],
          ),
        );
      },
    );
  }
}

class _AdminLoadingState extends StatelessWidget {
  const _AdminLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
          color: AdminCyberColors.panel.withValues(alpha: 0.78),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AdminCyberColors.neonCyan)),
            const SizedBox(width: 12),
            Text('Loading admin signals…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)),
          ],
        ),
      ),
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _AdminErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            color: AdminCyberColors.panel.withValues(alpha: 0.78),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AdminCyberColors.danger, size: 26),
              const SizedBox(height: 10),
              Text('Admin data unavailable', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 6),
              Text(error, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                  foregroundColor: AdminCyberColors.text,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
