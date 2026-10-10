import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

import '../../providers/agency_dashboard_provider.dart';

/// ============================================================================
/// AgencyEntryButton
/// ============================================================================
///
/// Bouton d'entrée vers l'espace agence, adaptatif selon l'état de l'utilisateur.
///
/// 3 états visuels :
/// - Aucune agence : CTA orange "Devenir Agence Partenaire" (attire l'attention)
/// - Agence en attente : CTA warning "Agence en attente de validation"
/// - Agence active : Bouton primaryDeep "Gérer mon Agence (Nom)"
///
/// Features :
/// - 3 états visuels (none / pending / active)
/// - Animation scale au tap (120ms)
/// - Haptic feedback sur le tap
/// - Tooltip pour l'accessibilité
/// - Semantics complets
/// - Gestion du nom long (ellipsis + maxLines)
/// - Badge "pending" si agence en attente
/// - i18n complète (FR/EN/LN)
/// - Design system ThixPolicy
/// - Responsive
///
/// ============================================================================
class AgencyEntryButton extends ConsumerStatefulWidget {
  final bool compact;
  final VoidCallback? onBeforeNavigate;

  const AgencyEntryButton({
    super.key,
    this.compact = false,
    this.onBeforeNavigate,
  });

  @override
  ConsumerState<AgencyEntryButton> createState() => _AgencyEntryButtonState();
}

class _AgencyEntryButtonState extends ConsumerState<AgencyEntryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleCtrl.forward();
  void _onTapUp(TapUpDetails _) => _scaleCtrl.reverse();
  void _onTapCancel() => _scaleCtrl.reverse();

  void _handleTap() async {
    final state = ref.read(agencyDashboardProvider);
    await HapticFeedback.lightImpact();

    widget.onBeforeNavigate?.call();

    if (!mounted) return;

    if (!state.hasAgency) {
      context.push('/agency/onboarding');
    } else if (state.isPending) {
      context.push('/agency/onboarding');
    } else {
      context.push('/agency/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(agencyDashboardProvider);

    final mode = _computeMode(state);
    final label = _buildLabel(l10n, state, mode);
    final tooltip = _buildTooltip(l10n, mode);

    Widget button = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? ThixPolicy.s12 : ThixPolicy.s14,
        vertical: widget.compact ? ThixPolicy.s10 : ThixPolicy.s12,
      ),
      decoration: BoxDecoration(
        color: mode.backgroundColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: mode.borderColor, width: 1),
        boxShadow: mode.hasShadow ? ThixPolicy.shadowSoft() : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(mode.icon, color: mode.foregroundColor, size: 18),
          SizedBox(width: ThixPolicy.s8),
          Expanded(
            child: Text(
              label,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: mode.foregroundColor,
                fontWeight: ThixPolicy.bold,
                fontSize: widget.compact ? 12 : 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: ThixPolicy.s6),
          if (mode == _AgencyMode.pending)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ThixPolicy.s6,
                vertical: ThixPolicy.s2,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: Text(
                l10n.t('agencyEntryPendingBadge'),
                style: ThixPolicy.microStyle.copyWith(
                  color: mode.foregroundColor,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 9,
                ),
              ),
            )
          else
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: mode.foregroundColor.withValues(alpha: 0.75),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ThixPolicy.s16,
            vertical: ThixPolicy.s8,
          ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onTap: _handleTap,
              child: AnimatedBuilder(
                animation: _scaleAnim,
                builder: (ctx, child) => Transform.scale(
                  scale: _scaleAnim.value,
                  child: child,
                ),
                child: button,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _AgencyMode _computeMode(AgencyDashboardState state) {
    if (!state.hasAgency) return _AgencyMode.none;
    if (state.isPending) return _AgencyMode.pending;
    return _AgencyMode.active;
  }

  String _buildLabel(
    dynamic l10n,
    AgencyDashboardState state,
    _AgencyMode mode,
  ) {
    try {
      switch (mode) {
        case _AgencyMode.none:
          return l10n.t('agencyEntryBecomePartner');
        case _AgencyMode.pending:
          return l10n.t('agencyEntryPending');
        case _AgencyMode.active:
          final name = state.myAgency?.name ?? '';
          return name.isNotEmpty
              ? l10n.t('agencyEntryManageWithName', args: [name])
              : l10n.t('agencyEntryManage');
      }
    } catch (_) {
      return 'Agency';
    }
  }

  String _buildTooltip(dynamic l10n, _AgencyMode mode) {
    try {
      switch (mode) {
        case _AgencyMode.none:
          return l10n.t('agencyEntryTooltipNone');
        case _AgencyMode.pending:
          return l10n.t('agencyEntryTooltipPending');
        case _AgencyMode.active:
          return l10n.t('agencyEntryTooltipActive');
      }
    } catch (_) {
      return 'Agency';
    }
  }
}

/// ============================================================================
/// _AgencyMode — Enum des modes d'affichage
/// ============================================================================
enum _AgencyMode {
  none,
  pending,
  active,
}

/// ============================================================================
/// Extension pour récupérer les couleurs/icônes selon le mode
/// ============================================================================
extension _AgencyModeStyle on _AgencyMode {
  Color get backgroundColor {
    switch (this) {
      case _AgencyMode.none:
        return ThixPolicy.warning.withValues(alpha: 0.08);
      case _AgencyMode.pending:
        return ThixPolicy.warning;
      case _AgencyMode.active:
        return ThixPolicy.primaryDeep;
    }
  }

  Color get borderColor {
    switch (this) {
      case _AgencyMode.none:
        return ThixPolicy.warning.withValues(alpha: 0.3);
      case _AgencyMode.pending:
        return ThixPolicy.warning;
      case _AgencyMode.active:
        return ThixPolicy.primaryDeep;
    }
  }

  Color get foregroundColor {
    switch (this) {
      case _AgencyMode.none:
        return ThixPolicy.warning;
      case _AgencyMode.pending:
        return Colors.white;
      case _AgencyMode.active:
        return Colors.white;
    }
  }

  IconData get icon {
    switch (this) {
      case _AgencyMode.none:
        return Icons.add_business_rounded;
      case _AgencyMode.pending:
        return Icons.hourglass_top_rounded;
      case _AgencyMode.active:
        return Icons.dashboard_customize_rounded;
    }
  }

  bool get hasShadow {
    return this == _AgencyMode.active || this == _AgencyMode.pending;
  }
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
