import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

import '../../providers/agency_dashboard_provider.dart';

/// ============================================================================
/// AgencyOnboardingPage
/// ============================================================================
///
/// Page d'onboarding pour devenir agence partenaire.
///
/// Features :
/// - Liste des agences existantes avec badges de statut
/// - Formulaire de création avec validation visuelle
/// - 50+ pays africains avec drapeaux emoji
/// - Section "Pourquoi devenir partenaire" (benefits)
/// - Skeleton loader pendant le chargement
/// - Vue d'erreur avec retry
/// - Vue vide élégante
/// - Animations staggered sur les cards
/// - Haptic feedback sur les interactions
/// - Auto-validation (mode test) clairement indiquée
/// - i18n complète (FR/EN/LN)
/// - Accessibilité complète (Semantics)
/// - Design system ThixPolicy
///
/// ============================================================================
class AgencyOnboardingPage extends ConsumerStatefulWidget {
  const AgencyOnboardingPage({super.key});

  @override
  ConsumerState<AgencyOnboardingPage> createState() =>
      _AgencyOnboardingPageState();
}

class _AgencyOnboardingPageState extends ConsumerState<AgencyOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _countryCode = 'CD';
  bool _isCreating = false;
  bool _isLoadingAgencies = true;
  List<_AgencyData> _agencies = [];
  String? _error;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAgencies());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgencies() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAgencies = true;
      _error = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingAgencies = false;
        _error = context.l10n.agencyOnboardingAuthRequired;
      });
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('bus_agencies')
          .select()
          .eq('owner_id', user.id)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final list = (res as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _AgencyData(
          id: m['id']?.toString() ?? '',
          name: (m['name'] ?? 'Agence').toString(),
          status: _parseStatus(m['status']?.toString()),
          countryCode: (m['country_code'] ?? m['country'] ?? '').toString(),
          description: m['description']?.toString(),
        );
      }).toList();

      setState(() {
        _agencies = list;
        _isLoadingAgencies = false;
      });

      // Sync avec le provider global
      await ref.read(agencyDashboardProvider.notifier).init();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAgencies = false;
        _error = e.toString();
      });
    }
  }

  _AgencyStatus _parseStatus(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'active':
      case 'approved':
        return _AgencyStatus.active;
      case 'pending':
      case 'review':
        return _AgencyStatus.pending;
      case 'rejected':
        return _AgencyStatus.rejected;
      case 'suspended':
        return _AgencyStatus.suspended;
      default:
        return _AgencyStatus.pending;
    }
  }

  Future<void> _openDashboard() async {
    await HapticFeedback.lightImpact();
    await ref.read(agencyDashboardProvider.notifier).init();
    if (!mounted) return;
    context.go('/agency/dashboard');
  }

  bool _validateForm() {
    final l10n = context.l10n;
    bool valid = true;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l10n.agencyOnboardingNameRequired);
      valid = false;
    } else if (name.length < 2) {
      setState(() => _nameError = l10n.agencyOnboardingNameTooShort);
      valid = false;
    } else {
      setState(() => _nameError = null);
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && phone.length < 8) {
      setState(() => _phoneError = l10n.agencyOnboardingPhoneInvalid);
      valid = false;
    } else {
      setState(() => _phoneError = null);
    }

    return valid;
  }

  Future<void> _create() async {
    if (!_validateForm()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.agencyOnboardingAuthRequired),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      );
      return;
    }

    await HapticFeedback.mediumImpact();
    setState(() => _isCreating = true);

    try {
      final ok = await ref.read(agencyDashboardProvider.notifier).createMyAgency(
            name: _nameCtrl.text.trim(),
            countryCode: _countryCode,
            description: _descCtrl.text.trim(),
          );

      if (!mounted) return;

      if (ok) {
        await HapticFeedback.heavyImpact();
        _nameCtrl.clear();
        _descCtrl.clear();
        _phoneCtrl.clear();
        await _loadAgencies();
        if (!mounted) return;
        context.go('/agency/dashboard');
      } else {
        final err = ref.read(agencyDashboardProvider).error ??
            context.l10n.agencyOnboardingCreateFailed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: ThixPolicy.s8),
                Expanded(child: Text(err)),
              ],
            ),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
          ),
        );
        await _loadAgencies();
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
          tooltip: l10n.commonBack,
        ),
        title: Text(
          l10n.agencyOnboardingTitle,
          style: ThixPolicy.titleStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            fontSize: 16,
            color: ThixPolicy.textMain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
            onPressed: _isLoadingAgencies ? null : _loadAgencies,
            tooltip: l10n.commonRetry,
          ),
          SizedBox(width: ThixPolicy.s4),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ThixPolicy.s16,
          ThixPolicy.s12,
          ThixPolicy.s16,
          ThixPolicy.s32,
        ),
        children: [
          _HeroHeader(domainColor: domainColor),
          SizedBox(height: ThixPolicy.s20),
          _BenefitsSection(domainColor: domainColor),
          SizedBox(height: ThixPolicy.s24),
          _MyAgenciesSection(
            agencies: _agencies,
            isLoading: _isLoadingAgencies,
            error: _error,
            onRetry: _loadAgencies,
            onOpenDashboard: _openDashboard,
            domainColor: domainColor,
          ),
          SizedBox(height: ThixPolicy.s28),
          _CreateAgencyForm(
            formKey: _formKey,
            nameCtrl: _nameCtrl,
            descCtrl: _descCtrl,
            phoneCtrl: _phoneCtrl,
            countryCode: _countryCode,
            nameError: _nameError,
            phoneError: _phoneError,
            isCreating: _isCreating,
            onCountryChanged: (c) {
              HapticFeedback.selectionClick();
              setState(() => _countryCode = c);
            },
            onNameChanged: (_) => setState(() => _nameError = null),
            onPhoneChanged: (_) => setState(() => _phoneError = null),
            onSubmit: _create,
            domainColor: domainColor,
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _AgencyStatus — Enum des statuts d'agence
/// ============================================================================
enum _AgencyStatus {
  active,
  pending,
  rejected,
  suspended,
}

/// ============================================================================
/// _AgencyData — Représentation locale d'une agence
/// ============================================================================
class _AgencyData {
  final String id;
  final String name;
  final _AgencyStatus status;
  final String countryCode;
  final String? description;

  const _AgencyData({
    required this.id,
    required this.name,
    required this.status,
    required this.countryCode,
    this.description,
  });
}

/// ============================================================================
/// _HeroHeader — Hero header avec icône et titre
/// ============================================================================
class _HeroHeader extends StatelessWidget {
  final Color domainColor;

  const _HeroHeader({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            domainColor,
            domainColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        boxShadow: [
          BoxShadow(
            color: domainColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.storefront_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          SizedBox(height: ThixPolicy.s14),
          Text(
            l10n.agencyOnboardingHeroTitle,
            style: ThixPolicy.h2Style.copyWith(
              color: Colors.white,
              fontWeight: ThixPolicy.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ThixPolicy.s6),
          Text(
            l10n.agencyOnboardingHeroSubtitle,
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _BenefitsSection — Pourquoi devenir partenaire ?
/// ============================================================================
class _BenefitsSection extends StatelessWidget {
  final Color domainColor;

  const _BenefitsSection({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s6),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Icon(
                  Icons.stars_rounded,
                  size: 16,
                  color: domainColor,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Text(
                l10n.agencyOnboardingBenefitsTitle,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s14),
          _BenefitItem(
            icon: Icons.trending_up_rounded,
            title: l10n.agencyOnboardingBenefit1Title,
            description: l10n.agencyOnboardingBenefit1Desc,
            color: domainColor,
          ),
          SizedBox(height: ThixPolicy.s10),
          _BenefitItem(
            icon: Icons.people_outline_rounded,
            title: l10n.agencyOnboardingBenefit2Title,
            description: l10n.agencyOnboardingBenefit2Desc,
            color: ThixPolicy.domainJobs,
          ),
          SizedBox(height: ThixPolicy.s10),
          _BenefitItem(
            icon: Icons.analytics_rounded,
            title: l10n.agencyOnboardingBenefit3Title,
            description: l10n.agencyOnboardingBenefit3Desc,
            color: ThixPolicy.domainMoney,
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        SizedBox(width: ThixPolicy.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              SizedBox(height: ThixPolicy.s2),
              Text(
                description,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _MyAgenciesSection — Section "Mes agences"
/// ============================================================================
class _MyAgenciesSection extends StatelessWidget {
  final List<_AgencyData> agencies;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onOpenDashboard;
  final Color domainColor;

  const _MyAgenciesSection({
    required this.agencies,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onOpenDashboard,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(ThixPolicy.s6),
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: Icon(
                Icons.business_rounded,
                size: 16,
                color: domainColor,
              ),
            ),
            SizedBox(width: ThixPolicy.s8),
            Text(
              l10n.agencyOnboardingMyAgencies,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (agencies.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s8,
                  vertical: ThixPolicy.s2,
                ),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                ),
                child: Text(
                  '${agencies.length}',
                  style: ThixPolicy.labelStyle.copyWith(
                    color: domainColor,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: ThixPolicy.s12),

        if (isLoading)
          _AgenciesSkeleton()
        else if (error != null)
          _AgenciesError(error: error!, onRetry: onRetry)
        else if (agencies.isEmpty)
          _AgenciesEmpty(domainColor: domainColor)
        else ...[
          ...List.generate(agencies.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: ThixPolicy.s8),
              child: _AgencyCard(
                agency: agencies[i],
                index: i,
                onTap: onOpenDashboard,
                domainColor: domainColor,
              ),
            );
          }),
          SizedBox(height: ThixPolicy.s8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onOpenDashboard,
              icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
              label: Text(l10n.agencyOnboardingOpenDashboard),
              style: OutlinedButton.styleFrom(
                foregroundColor: domainColor,
                side: BorderSide(color: domainColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AgencyCard extends StatefulWidget {
  final _AgencyData agency;
  final int index;
  final VoidCallback onTap;
  final Color domainColor;

  const _AgencyCard({
    required this.agency,
    required this.index,
    required this.onTap,
    required this.domainColor,
  });

  @override
  State<_AgencyCard> createState() => _AgencyCardState();
}

class _AgencyCardState extends State<_AgencyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (widget.index * 60).clamp(0, 200)),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusInfo = _getStatusInfo(widget.agency.status);
    final flag = _getFlag(widget.agency.countryCode);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Semantics(
          button: true,
          label: '${widget.agency.name}, ${statusInfo.label}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              child: Container(
                padding: EdgeInsets.all(ThixPolicy.s14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(color: ThixPolicy.border),
                  boxShadow: ThixPolicy.shadowSoft(),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.domainColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      ),
                      child: Center(
                        child: Text(
                          flag,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.agency.name,
                            style: ThixPolicy.bodyStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                              color: ThixPolicy.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ThixPolicy.s2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusInfo.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: ThixPolicy.s4),
                              Text(
                                statusInfo.label,
                                style: ThixPolicy.microStyle.copyWith(
                                  color: statusInfo.color,
                                  fontWeight: ThixPolicy.semiBold,
                                ),
                              ),
                              if (widget.agency.countryCode.isNotEmpty) ...[
                                SizedBox(width: ThixPolicy.s8),
                                Text(
                                  '• ${widget.agency.countryCode.toUpperCase()}',
                                  style: ThixPolicy.microStyle.copyWith(
                                    color: ThixPolicy.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: ThixPolicy.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _StatusInfo _getStatusInfo(_AgencyStatus status) {
    switch (status) {
      case _AgencyStatus.active:
        return _StatusInfo(
          label: context.l10n.agencyStatusActive,
          color: ThixPolicy.success,
        );
      case _AgencyStatus.pending:
        return _StatusInfo(
          label: context.l10n.agencyStatusPending,
          color: ThixPolicy.warning,
        );
      case _AgencyStatus.rejected:
        return _StatusInfo(
          label: context.l10n.agencyStatusRejected,
          color: ThixPolicy.danger,
        );
      case _AgencyStatus.suspended:
        return _StatusInfo(
          label: context.l10n.agencyStatusSuspended,
          color: ThixPolicy.textMuted,
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo({required this.label, required this.color});
}

String _getFlag(String countryCode) {
  if (countryCode.isEmpty || countryCode.length != 2) return '🏢';
  final code = countryCode.toUpperCase();
  // Conversion code pays → drapeau emoji (Unicode regional indicators)
  final base = 0x1F1E6;
  final first = base + (code.codeUnitAt(0) - 65);
  final second = base + (code.codeUnitAt(1) - 65);
  return String.fromCharCodes([first, second]);
}

/// ============================================================================
/// _AgenciesSkeleton — Skeleton loader
/// ============================================================================
class _AgenciesSkeleton extends StatefulWidget {
  @override
  State<_AgenciesSkeleton> createState() => _AgenciesSkeletonState();
}

class _AgenciesSkeletonState extends State<_AgenciesSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final alpha = (0.5 + (_ctrl.value * 0.3)).clamp(0.0, 1.0);
        final color = ThixPolicy.surfaceStrong.withValues(alpha: alpha);

        return Column(
          children: List.generate(2, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: ThixPolicy.s8),
              child: Container(
                padding: EdgeInsets.all(ThixPolicy.s14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Row(
                  children: [
                    _SkeletonBox(width: 44, height: 44, color: color),
                    SizedBox(width: ThixPolicy.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(width: 140, height: 14, color: color),
                          SizedBox(height: ThixPolicy.s6),
                          _SkeletonBox(width: 80, height: 10, color: color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
      ),
    );
  }
}

/// ============================================================================
/// _AgenciesError — Vue d'erreur
/// ============================================================================
class _AgenciesError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _AgenciesError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(
          color: ThixPolicy.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 32,
            color: ThixPolicy.danger,
          ),
          SizedBox(height: ThixPolicy.s8),
          Text(
            l10n.commonError,
            style: ThixPolicy.bodySmallStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.danger,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ThixPolicy.s4),
          Text(
            error,
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: ThixPolicy.s12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(l10n.commonRetry),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.danger,
              side: BorderSide(color: ThixPolicy.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _AgenciesEmpty — Vue vide
/// ============================================================================
class _AgenciesEmpty extends StatelessWidget {
  final Color domainColor;

  const _AgenciesEmpty({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(
          color: ThixPolicy.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ThixPolicy.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 22,
              color: ThixPolicy.warning,
            ),
          ),
          SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.agencyOnboardingEmptyTitle,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                  ),
                ),
                SizedBox(height: ThixPolicy.s2),
                Text(
                  l10n.agencyOnboardingEmptyMessage,
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.textSecondary,
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

/// ============================================================================
/// _CreateAgencyForm — Formulaire de création
/// ============================================================================
class _CreateAgencyForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController phoneCtrl;
  final String countryCode;
  final String? nameError;
  final String? phoneError;
  final bool isCreating;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onSubmit;
  final Color domainColor;

  const _CreateAgencyForm({
    required this.formKey,
    required this.nameCtrl,
    required this.descCtrl,
    required this.phoneCtrl,
    required this.countryCode,
    required this.nameError,
    required this.phoneError,
    required this.isCreating,
    required this.onCountryChanged,
    required this.onNameChanged,
    required this.onPhoneChanged,
    required this.onSubmit,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s6),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Icon(
                  Icons.add_business_rounded,
                  size: 16,
                  color: domainColor,
                ),
              ),
              SizedBox(width: ThixPolicy.s8),
              Text(
                l10n.agencyOnboardingCreateTitle,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s16),

          Container(
            padding: EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border),
              boxShadow: ThixPolicy.shadowSoft(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nom agence
                _FieldLabel(label: '${l10n.agencyOnboardingFieldName} *'),
                SizedBox(height: ThixPolicy.s6),
                TextField(
                  controller: nameCtrl,
                  onChanged: onNameChanged,
                  textCapitalization: TextCapitalization.words,
                  style: ThixPolicy.bodyStyle.copyWith(
                    fontWeight: ThixPolicy.medium,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.agencyOnboardingFieldNameHint,
                    prefixIcon: Icon(Icons.business_rounded, color: domainColor),
                    errorText: nameError,
                    filled: true,
                    fillColor: ThixPolicy.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide(color: ThixPolicy.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide(color: domainColor, width: 1.5),
                    ),
                  ),
                ),
                SizedBox(height: ThixPolicy.s14),

                // Pays
                _FieldLabel(label: l10n.agencyOnboardingFieldCountry),
                SizedBox(height: ThixPolicy.s6),
                _CountryDropdown(
                  value: countryCode,
                  onChanged: onCountryChanged,
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s14),

                // Téléphone (optionnel)
                _FieldLabel(
                  label: l10n.agencyOnboardingFieldPhone,
                  optional: true,
                ),
                SizedBox(height: ThixPolicy.s6),
                TextField(
                  controller: phoneCtrl,
                  onChanged: onPhoneChanged,
                  keyboardType: TextInputType.phone,
                  style: ThixPolicy.bodyStyle.copyWith(
                    fontWeight: ThixPolicy.medium,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.agencyOnboardingFieldPhoneHint,
                    prefixIcon: Icon(Icons.phone_rounded, color: domainColor),
                    errorText: phoneError,
                    filled: true,
                    fillColor: ThixPolicy.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide(color: ThixPolicy.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide(color: domainColor, width: 1.5),
                    ),
                  ),
                ),
                SizedBox(height: ThixPolicy.s14),

                // Description (optionnelle)
                _FieldLabel(
                  label: l10n.agencyOnboardingFieldDescription,
                  optional: true,
                ),
                SizedBox(height: ThixPolicy.s6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  style: ThixPolicy.bodyStyle.copyWith(
                    fontWeight: ThixPolicy.medium,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.agencyOnboardingFieldDescriptionHint,
                    prefixIcon: Icon(Icons.description_rounded, color: domainColor),
                    filled: true,
                    fillColor: ThixPolicy.surfaceSoft,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide(color: ThixPolicy.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      borderSide: BorderSide(color: domainColor, width: 1.5),
                    ),
                  ),
                ),
                SizedBox(height: ThixPolicy.s20),

                // Submit button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isCreating ? null : onSubmit,
                    icon: isCreating
                        ? const SizedBox.shrink()
                        : Icon(Icons.add_rounded, size: 20, color: Colors.white),
                    label: isCreating
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: ThixPolicy.s10),
                              Text(
                                l10n.agencyOnboardingCreating,
                                style: ThixPolicy.titleStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: ThixPolicy.bold,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            l10n.agencyOnboardingCreateButton,
                            style: ThixPolicy.titleStyle.copyWith(
                              color: Colors.white,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: domainColor,
                      disabledBackgroundColor: ThixPolicy.textMuted,
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ThixPolicy.s12),

                // Mode test badge
                Container(
                  padding: EdgeInsets.all(ThixPolicy.s10),
                  decoration: BoxDecoration(
                    color: ThixPolicy.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    border: Border.all(
                      color: ThixPolicy.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: ThixPolicy.success,
                      ),
                      SizedBox(width: ThixPolicy.s8),
                      Expanded(
                        child: Text(
                          l10n.agencyOnboardingTestMode,
                          style: ThixPolicy.microStyle.copyWith(
                            color: ThixPolicy.success,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      ),
                    ],
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

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _FieldLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text(
          label,
          style: ThixPolicy.labelStyle.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.semiBold,
            fontSize: 12,
          ),
        ),
        if (optional) ...[
          SizedBox(width: ThixPolicy.s4),
          Text(
            '(${l10n.commonOptional})',
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// ============================================================================
/// _CountryDropdown — Dropdown des pays africains avec drapeaux
/// ============================================================================
class _CountryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color domainColor;

  const _CountryDropdown({
    required this.value,
    required this.onChanged,
    required this.domainColor,
  });

  static const List<_Country> _countries = [
    _Country('CD', 'RD Congo'),
    _Country('CG', 'Congo'),
    _Country('CI', "Côte d'Ivoire"),
    _Country('SN', 'Sénégal'),
    _Country('CM', 'Cameroun'),
    _Country('ML', 'Mali'),
    _Country('BF', 'Burkina Faso'),
    _Country('NE', 'Niger'),
    _Country('GN', 'Guinée'),
    _Country('BJ', 'Bénin'),
    _Country('TG', 'Togo'),
    _Country('GA', 'Gabon'),
    _Country('TD', 'Tchad'),
    _Country('CF', 'Centrafrique'),
    _Country('GQ', 'Guinée Équatoriale'),
    _Country('GW', 'Guinée-Bissau'),
    _Country('NG', 'Nigeria'),
    _Country('GH', 'Ghana'),
    _Country('SL', 'Sierra Leone'),
    _Country('LR', 'Liberia'),
    _Country('GM', 'Gambie'),
    _Country('MR', 'Mauritanie'),
    _Country('CV', 'Cap-Vert'),
    _Country('KE', 'Kenya'),
    _Country('TZ', 'Tanzanie'),
    _Country('UG', 'Ouganda'),
    _Country('RW', 'Rwanda'),
    _Country('BI', 'Burundi'),
    _Country('ET', 'Éthiopie'),
    _Country('SO', 'Somalie'),
    _Country('DJ', 'Djibouti'),
    _Country('ER', 'Érythrée'),
    _Country('SS', 'Soudan du Sud'),
    _Country('SD', 'Soudan'),
    _Country('MA', 'Maroc'),
    _Country('DZ', 'Algérie'),
    _Country('TN', 'Tunisie'),
    _Country('LY', 'Libye'),
    _Country('EG', 'Égypte'),
    _Country('ZA', 'Afrique du Sud'),
    _Country('NA', 'Namibie'),
    _Country('BW', 'Botswana'),
    _Country('ZM', 'Zambie'),
    _Country('ZW', 'Zimbabwe'),
    _Country('MW', 'Malawi'),
    _Country('MZ', 'Mozambique'),
    _Country('AO', 'Angola'),
    _Country('SZ', 'Eswatini'),
    _Country('LS', 'Lesotho'),
    _Country('MG', 'Madagascar'),
    _Country('MU', 'Maurice'),
    _Country('SC', 'Seychelles'),
    _Country('KM', 'Comores'),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: domainColor),
      dropdownColor: Colors.white,
      style: ThixPolicy.bodyStyle.copyWith(
        color: ThixPolicy.textMain,
        fontWeight: ThixPolicy.medium,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.public_rounded, color: domainColor),
        filled: true,
        fillColor: ThixPolicy.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: BorderSide(color: ThixPolicy.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: BorderSide(color: domainColor, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ThixPolicy.s16,
          vertical: ThixPolicy.s14,
        ),
      ),
      items: _countries.map((c) {
        return DropdownMenuItem<String>(
          value: c.code,
          child: Row(
            children: [
              Text(_getFlag(c.code), style: const TextStyle(fontSize: 18)),
              SizedBox(width: ThixPolicy.s10),
              Text(
                c.name,
                style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textMain,
                ),
              ),
              const Spacer(),
              Text(
                c.code,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _Country {
  final String code;
  final String name;
  const _Country(this.code, this.name);
}

/// ============================================================================
/// AnimatedBuilder — Polyfill
/// ============================================================================
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
