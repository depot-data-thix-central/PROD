import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/job_service.dart';
import 'package:thix_id/theme.dart';

class JobDetailsPage extends StatefulWidget {
  final String jobId;
  final bool applied;
  const JobDetailsPage({super.key, required this.jobId, this.applied = false});

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  final _service = JobService();
  Set<String> _saved = const {};

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final s = await _service.getSavedJobIdsRemote();
    if (!mounted) return;
    setState(() => _saved = s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? InstitutionalColors.civicBlueSoft : InstitutionalColors.civicBlue;
    final divider = isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider;

    return Scaffold(
      backgroundColor: isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            _ThixInfoBackground(isDark: isDark),
            FutureBuilder(
              future: _service.fetchJob(widget.jobId),
              builder: (context, snap) {
                final job = snap.data;
                if (snap.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator(color: accent));
                if (job == null) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        _TopBar(title: 'Détails', accent: accent),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Offre introuvable.', style: context.textStyles.titleMedium?.copyWith(color: cs.onSurface)),
                        const SizedBox(height: AppSpacing.md),
                        Text('Retournez à la liste et réessayez.', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.70))),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => context.go(AppRoutes.jobs),
                            style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                            child: const Text('Retour'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final isSaved = _saved.contains(job.id);

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TopBar(title: 'Détails', accent: accent),
                            if (widget.applied) ...[
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  color: DarkModeColors.success.withValues(alpha: 0.14),
                                  border: Border.all(color: DarkModeColors.success.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: DarkModeColors.success),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Candidature envoyée. Vous recevrez une réponse si votre profil est retenu.',
                                        style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            if ((job.companyLogoUrl ?? '').trim().startsWith('http')) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                                child: AspectRatio(
                                  aspectRatio: 16 / 7,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(job.companyLogoUrl!, fit: BoxFit.cover),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.92),
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                                border: Border.all(color: divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [accent.withValues(alpha: 0.95), cs.primary.withValues(alpha: 0.92)],
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(job.isVerifiedEmployer ? Icons.verified_rounded : Icons.business_rounded, color: Colors.white),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(job.title, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface)),
                                            const SizedBox(height: 2),
                                            Text(job.company, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.70), fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(AppRadius.full),
                                          border: Border.all(color: divider),
                                          color: cs.surface.withValues(alpha: isDark ? 0.60 : 0.92),
                                        ),
                                        child: Text(job.type, style: context.textStyles.labelMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      _InfoPill(icon: Icons.location_on_rounded, label: job.location, divider: divider, accent: accent),
                                      _InfoPill(icon: Icons.payments_rounded, label: job.salary, divider: divider, accent: accent),
                                      if ((job.workMode ?? '').trim().isNotEmpty) _InfoPill(icon: Icons.route_rounded, label: (job.workMode ?? '').replaceAll('_', ' '), divider: divider, accent: accent),
                                      _InfoPill(icon: Icons.verified_user_rounded, label: job.isVerifiedEmployer ? 'Verified employer' : 'Employer unverified', divider: divider, accent: accent),
                                      if (job.applicantsCount != null) _InfoPill(icon: Icons.people_alt_rounded, label: '${job.applicantsCount} applicants', divider: divider, accent: accent),
                                      if (job.deadline != null) _InfoPill(icon: Icons.event_rounded, label: 'Deadline: ${job.deadline!.toLocal().toIso8601String().substring(0, 10)}', divider: divider, accent: accent),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text('Description', style: context.textStyles.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(job.description, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.74), height: 1.55)),
                                  if (job.responsibilities.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    Text('Responsibilities', style: context.textStyles.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: AppSpacing.sm),
                                    ...job.responsibilities.map((r) => _BulletRow(text: r)),
                                  ],
                                  if (job.skills.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    Text('Skills', style: context.textStyles.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: AppSpacing.sm),
                                      Wrap(spacing: 10, runSpacing: 10, children: job.skills.map((s) => _SkillChip(label: s, accent: accent, divider: divider)).toList(growable: false)),
                                  ] else if (job.requirements.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    Text('Requirements', style: context.textStyles.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: AppSpacing.sm),
                                    ...job.requirements.map((r) => _BulletRow(text: r)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: FilledButton.icon(
                                      onPressed: () => context.push('/jobs/${job.id}/apply'),
                                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                                      icon: const Icon(Icons.bolt_rounded),
                                      label: const Text('Postuler'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 54,
                                  width: 54,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await _service.toggleSavedRemote(jobId: job.id, save: !isSaved);
                                      await _loadSaved();
                                    },
                                    style: OutlinedButton.styleFrom(side: BorderSide(color: divider), foregroundColor: cs.onSurface),
                                    child: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: accent),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 54,
                                  width: 54,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final url = 'thixid://jobs/${job.id}';
                                      await Share.share('${job.title} • ${job.company}\n$url');
                                    },
                                    style: OutlinedButton.styleFrom(side: BorderSide(color: divider), foregroundColor: cs.onSurface),
                                    child: Icon(Icons.share_rounded, color: accent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: () => context.go(AppRoutes.jobs),
                                style: OutlinedButton.styleFrom(side: BorderSide(color: divider), foregroundColor: cs.onSurface),
                                icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface.withValues(alpha: 0.75)),
                                label: const Text('Retour'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final Color accent;
  const _TopBar({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.go(AppRoutes.jobs),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent),
        ),
        Expanded(
          child: Text(title, style: context.textStyles.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color divider;
  final Color accent;
  const _InfoPill({required this.icon, required this.label, required this.divider, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: divider),
        color: cs.surface.withValues(alpha: isDark ? 0.45 : 0.90),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: context.textStyles.labelMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle_rounded, size: 18, color: DarkModeColors.success),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.74), height: 1.45))),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  final Color accent;
  final Color divider;
  const _SkillChip({required this.label, required this.accent, required this.divider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        color: accent.withValues(alpha: isDark ? 0.12 : 0.10),
      ),
      child: Text(label, style: context.textStyles.labelLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900)),
    );
  }
}

class _ThixInfoBackground extends StatelessWidget {
  final bool isDark;
  const _ThixInfoBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final navy = isDark ? DarkModeColors.primary : InstitutionalColors.navy;
    final navy2 = isDark ? DarkModeColors.cyberDarkBlue : InstitutionalColors.navy2;
    final accent = isDark ? InstitutionalColors.civicBlueSoft : InstitutionalColors.civicBlue;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy.withValues(alpha: 0.98), navy2.withValues(alpha: 0.94), accent.withValues(alpha: 0.10)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

extension _ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
}
