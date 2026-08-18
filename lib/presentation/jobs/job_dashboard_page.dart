import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/job_service.dart';
import 'package:thix_id/theme.dart';

class JobDashboardPage extends StatefulWidget {
  const JobDashboardPage({super.key});

  @override
  State<JobDashboardPage> createState() => _JobDashboardPageState();
}

class _JobDashboardPageState extends State<JobDashboardPage> {
  final _service = JobService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _apps = const [];
  Set<String> _saved = const {};
  List<Map<String, dynamic>> _aiRecs = const [];

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
      final saved = await _service.getSavedJobIdsRemote();
      final appsRemote = await _service.listMyApplicationsRemote();
      final appsLocal = await _service.listLocalApplications();
      final merged = <Map<String, dynamic>>[
        ...appsRemote,
        ...appsLocal.map((e) => e.toJson()),
      ];
      final jobs = await _service.listJobs();
      final auth = context.read<AuthController>();
      final me = auth.currentUser;
      final profile = {
        'user_id': me?.id,
        'thix_id': me?.thixId,
        'account_type': me?.accountType.name,
        'registration_status': me?.registrationStatus,
        'skills': me?.skills ?? const [],
        'languages': me?.languages ?? const [],
      };
      final ai = await _service.aiRecommendJobs(userProfile: profile, jobs: jobs, limit: 8);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _apps = merged;
        _aiRecs = ai;
      });
    } catch (e) {
      debugPrint('JobDashboardPage.load failed err=$e');
      if (mounted) setState(() => _error = 'Erreur de chargement.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearningCyberColors.bg0,
      body: SafeArea(
        child: Stack(
          children: [
            const _JobsBackground(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go(AppRoutes.jobs),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: LearningCyberColors.text),
                      ),
                      Expanded(
                        child: Text('Dashboard Emploi', style: context.textStyles.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, color: LearningCyberColors.neonCyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: LearningCyberColors.neonCyan)))
                  else if (_error != null)
                    Expanded(
                      child: Center(
                        child: Text(_error!, style: context.textStyles.bodyLarge?.copyWith(color: LearningCyberColors.textDim)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          _GlassPanel(
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, color: LearningCyberColors.success),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Suivi candidatures, sauvegardes et recommandations AI',
                                    style: context.textStyles.bodyMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionHeader(title: 'AI recommendations', icon: Icons.auto_awesome_rounded, action: null),
                          const SizedBox(height: AppSpacing.sm),
                          if (_aiRecs.isEmpty)
                            _EmptyStateCard(label: 'Aucune recommandation (AI non configurée ou profil incomplet).')
                          else
                            ..._aiRecs.map((r) {
                              final id = (r['job_id'] ?? '').toString();
                              final score = (r['score'] ?? '').toString();
                              final reasons = (r['reasons'] is List) ? (r['reasons'] as List).take(2).join(' • ') : '';
                              final risk = (r['fake_job_risk'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _GlassTile(
                                  onTap: id.trim().isEmpty ? null : () => context.push('/jobs/$id'),
                                  leading: const Icon(Icons.work_rounded, color: LearningCyberColors.neonCyan),
                                  title: 'Job #$id',
                                  subtitle: 'Score $score • Risk $risk\n$reasons',
                                  trailing: _saved.contains(id)
                                      ? const Icon(Icons.bookmark_rounded, color: LearningCyberColors.neonCyan)
                                      : const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: LearningCyberColors.textDim),
                                ),
                              );
                            }),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionHeader(title: 'Saved jobs', icon: Icons.bookmark_rounded, action: Text('${_saved.length}', style: context.textStyles.labelLarge?.copyWith(color: LearningCyberColors.textDim))),
                          const SizedBox(height: AppSpacing.sm),
                          _GlassPanel(
                            child: _saved.isEmpty
                                ? Text('Aucun job sauvegardé.', style: context.textStyles.bodyMedium?.copyWith(color: LearningCyberColors.textDim))
                                : Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: _saved.take(24).map((id) => _NeonPill(label: id, onTap: () => context.push('/jobs/$id'))).toList(growable: false),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionHeader(title: 'Applied jobs', icon: Icons.fact_check_rounded, action: Text('${_apps.length}', style: context.textStyles.labelLarge?.copyWith(color: LearningCyberColors.textDim))),
                          const SizedBox(height: AppSpacing.sm),
                          if (_apps.isEmpty)
                            _EmptyStateCard(label: 'Aucune candidature trouvée.')
                          else
                            ..._apps.take(40).map((a) {
                              final jobId = (a['job_id'] ?? '').toString();
                              final st = (a['status'] ?? 'applied').toString();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _GlassTile(
                                  onTap: jobId.trim().isEmpty ? null : () => context.push('/jobs/$jobId'),
                                  leading: const Icon(Icons.assignment_turned_in_rounded, color: LearningCyberColors.success),
                                  title: 'Job #$jobId',
                                  subtitle: 'Status: $st',
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: LearningCyberColors.textDim),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsBackground extends StatelessWidget {
  const _JobsBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LearningCyberGradients.background()),
      child: Stack(
        children: const [
          _GlowBlob(color: LearningCyberColors.electricBlue, top: -80, left: -60, size: 240),
          _GlowBlob(color: LearningCyberColors.neonCyan, top: 120, right: -80, size: 280),
          _GlowBlob(color: LearningCyberColors.neonViolet, bottom: -120, left: 10, size: 320),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  const _GlowBlob({required this.color, required this.size, this.top, this.left, this.right, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.20)),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: LearningCyberColors.panel.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: child,
    );
  }
}

class _GlassTile extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _GlassTile({required this.onTap, required this.leading, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: LearningCyberColors.panelHi.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                gradient: LearningCyberGradients.glowBlue(),
              ),
              alignment: Alignment.center,
              child: leading,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: LearningCyberColors.textDim, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  const _SectionHeader({required this.title, required this.icon, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: LearningCyberColors.neonCyan, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: context.textStyles.titleMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900))),
        if (action != null) action!,
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String label;
  const _EmptyStateCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: LearningCyberColors.textDim),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: context.textStyles.bodyMedium?.copyWith(color: LearningCyberColors.textDim))),
        ],
      ),
    );
  }
}

class _NeonPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NeonPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: LearningCyberColors.neonCyan.withValues(alpha: 0.65)),
          color: LearningCyberColors.neonCyan.withValues(alpha: 0.12),
        ),
        child: Text(label, style: context.textStyles.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
