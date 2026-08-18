import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/admin_rbac_service.dart';
import 'package:thix_id/services/job_service.dart';
import 'package:thix_id/theme.dart';

class RecruiterPortalPage extends StatefulWidget {
  const RecruiterPortalPage({super.key});

  @override
  State<RecruiterPortalPage> createState() => _RecruiterPortalPageState();
}

class _RecruiterPortalPageState extends State<RecruiterPortalPage> {
  final _service = JobService();
  bool _loading = true;
  String? _error;
  int _tab = 0;
  List<Map<String, dynamic>> _myJobs = const [];
  List<Map<String, dynamic>> _apps = const [];

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
      final uid = context.read<AuthController>().currentUser?.id;
      if (uid == null || uid.trim().isEmpty) throw Exception('Not authenticated');
      final jobs = await _service.listJobs();
      final mine = jobs.where((j) => (j.recruiterUserId ?? '').trim() == uid).map((j) => j.toJson()).toList(growable: false);
      final apps = await _service.listRecruiterApplications(recruiterUserId: uid);
      if (!mounted) return;
      setState(() {
        _myJobs = mine;
        _apps = apps;
      });
    } catch (e) {
      debugPrint('RecruiterPortalPage.load failed err=$e');
      if (mounted) setState(() => _error = 'Erreur de chargement');
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
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go(AppRoutes.home),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: LearningCyberColors.text),
                      ),
                      Expanded(
                        child: Text('Recruiter Portal', style: context.textStyles.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, color: LearningCyberColors.neonCyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FutureBuilder(
                    future: AdminRbacService().fetchMyRole(),
                    builder: (context, snap) {
                      final role = (snap.data ?? '').toString();
                      final canRecruit = AdminRbacService.canAccess(role: role, minLevel: 2) && role.toLowerCase().contains('recruit');
                      if (snap.connectionState != ConnectionState.done) {
                        return const SizedBox(height: 54);
                      }
                      if (!canRecruit) {
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: LearningCyberColors.panel.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded, color: LearningCyberColors.danger),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Accès recruteur requis (role=r ecruiter).',
                                  style: context.textStyles.bodyMedium?.copyWith(color: LearningCyberColors.textDim, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _Tabs(
                        tab: _tab,
                        onChanged: (v) => setState(() => _tab = v),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: LearningCyberColors.neonCyan))
                        : (_error != null)
                            ? Center(child: Text(_error!, style: context.textStyles.bodyLarge?.copyWith(color: LearningCyberColors.textDim)))
                            : (_tab == 0)
                                ? _RecruiterJobsTab(items: _myJobs)
                                : _RecruiterApplicationsTab(items: _apps),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.go('${AppRoutes.admin}/jobs'),
              backgroundColor: LearningCyberColors.electricBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Créer un job'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            )
          : null,
    );
  }
}

class _Tabs extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip({required int value, required String label, required IconData icon}) {
      final selected = value == tab;
      return InkWell(
        onTap: () => onChanged(value),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? LearningCyberColors.neonCyan.withValues(alpha: 0.18) : LearningCyberColors.panel.withValues(alpha: 0.5),
            border: Border.all(color: selected ? LearningCyberColors.neonCyan.withValues(alpha: 0.75) : LearningCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? LearningCyberColors.neonCyan : LearningCyberColors.textDim),
              const SizedBox(width: 8),
              Text(label, style: context.textStyles.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(value: 0, label: 'My jobs', icon: Icons.workspaces_rounded),
        const SizedBox(width: 10),
        chip(value: 1, label: 'Applications', icon: Icons.fact_check_rounded),
      ],
    );
  }
}

class _RecruiterJobsTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _RecruiterJobsTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('Aucun job publié.', style: context.textStyles.bodyLarge?.copyWith(color: LearningCyberColors.textDim)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = items[i];
        final id = (r['id'] ?? '').toString();
        return _GlassRow(
          onTap: () => context.push('/jobs/$id'),
          icon: Icons.work_rounded,
          title: (r['title'] ?? 'Job').toString(),
          subtitle: '${(r['company'] ?? '').toString()} • ${(r['location'] ?? '').toString()}',
          meta: (r['status'] ?? 'pending').toString(),
        );
      },
    );
  }
}

class _RecruiterApplicationsTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _RecruiterApplicationsTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('Aucune candidature reçue.', style: context.textStyles.bodyLarge?.copyWith(color: LearningCyberColors.textDim)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = items[i];
        final jobId = (r['job_id'] ?? '').toString();
        final thixId = (r['applicant_thix_id'] ?? '').toString();
        final st = (r['status'] ?? 'applied').toString();
        return _GlassRow(
          onTap: jobId.trim().isEmpty ? null : () => context.push('/jobs/$jobId'),
          icon: Icons.person_search_rounded,
          title: 'Candidat $thixId',
          subtitle: 'Job #$jobId',
          meta: st,
        );
      },
    );
  }
}

class _GlassRow extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  const _GlassRow({required this.onTap, required this.icon, required this.title, required this.subtitle, required this.meta});

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
          border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.85)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                gradient: LearningCyberGradients.glowBlue(),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: LearningCyberColors.textDim), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: LearningCyberColors.neonCyan.withValues(alpha: 0.45)),
                color: LearningCyberColors.neonCyan.withValues(alpha: 0.10),
              ),
              child: Text(meta, style: context.textStyles.labelMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w800)),
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
          Positioned(top: -80, left: -60, child: _Blob(color: LearningCyberColors.electricBlue, size: 240)),
          Positioned(top: 120, right: -80, child: _Blob(color: LearningCyberColors.neonCyan, size: 280)),
          Positioned(bottom: -120, left: 10, child: _Blob(color: LearningCyberColors.neonViolet, size: 320)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.20)),
      ),
    );
  }
}
