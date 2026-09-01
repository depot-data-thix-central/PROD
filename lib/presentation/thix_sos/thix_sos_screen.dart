/// THIX SOS — Homepage production (Design System Intégré)
/// ✅ AUDITÉ : Sécurité, Performance, Accessibilité, UX
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'models/sos_models.dart';
import 'pages/sos_actif_page.dart';
import 'pages/mes_secours_page.dart';
import 'pages/mes_incidents_page.dart';
import 'pages/chambre_crise_page.dart';
import 'pages/chambre_crise_secours_page.dart';
import 'pages/ajouter_secours_page.dart';
import 'providers/sos_providers.dart';
import 'providers/sos_rescue_alert_provider.dart';
import 'widgets/sos_button.dart';
import 'widgets/nearby_alerts_card.dart';

// ============================================================================
// HELPERS DE VALIDATION
// ============================================================================
class _ImageValidator {
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}

// ============================================================================
// COMPOSANT RÉUTILISABLE : BOÎTE EN VERRE (GLASSMORPHISM)
// ============================================================================
class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = ThixPolicy.rLg,
    this.padding = ThixPolicy.cardPadding,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ThixSosScreen extends ConsumerStatefulWidget {
  const ThixSosScreen({super.key});

  @override
  ConsumerState<ThixSosScreen> createState() => _ThixSosScreenState();
}

class _ThixSosScreenState extends ConsumerState<ThixSosScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    
    // ✅ FIX P0 : Déplacer ref.listen dans initState pour éviter rebuilds infinis
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      ref.listenManual(activeSosProvider, (prev, next) {
        next.whenData((incident) {
          if (incident != null && incident.isActive && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => SosActifPage(incidentId: incident.id),
              ),
            );
          }
        });
      });

      ref.listenManual(sosRescueAlertProvider, (prev, next) {
        if (next == null || !mounted) return;
        if (prev != null && prev.incidentId == next.incidentId) return;
        
        HapticFeedback.heavyImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChambreCriseSecoursPage(
              incidentId: next.incidentId,
              victimUserId: next.victimId,
            ),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contactsAsync = ref.watch(sosContactsProvider);
    final activeAsync = ref.watch(activeSosProvider);
    final triggerState = ref.watch(triggerSosProvider);
    final isTriggering = triggerState.isLoading;

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Stack(
        children: [
          // ─── BACKGROUND GLOW ───
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.danger.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                      color: ThixPolicy.danger.withOpacity(0.2),
                      blurRadius: 120,
                      spreadRadius: 100)
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const _HeaderOfficiel(),
                Expanded(
                  child: RefreshIndicator(
                    color: ThixPolicy.danger,
                    backgroundColor: ThixPolicy.inkDeep,
                    onRefresh: () async {
                      ref.invalidate(sosContactsProvider);
                      ref.invalidate(activeSosProvider);
                      ref.invalidate(sosHistoryProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(
                        ThixPolicy.s16,
                        ThixPolicy.s24,
                        ThixPolicy.s16,
                        140,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- BOUTON SOS CENTRAL ---
                          Semantics(
                            button: true,
                            label: l10n.t('sos_trigger_button'),
                            child: SosButton(
                              enabled: !_isProcessing && !isTriggering,
                              isLoading: _isProcessing || isTriggering,
                              onTriggered: () => _handleSosTrigger(context, ref),
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          Text(
                            l10n.t('sos_hold_instruction'),
                            textAlign: TextAlign.center,
                            style: ThixPolicy.labelStyle.copyWith(
                              color: Colors.white54,
                              fontWeight: ThixPolicy.medium,
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s40),

                          // --- MES SECOURS ---
                          _SectionLabel(
                            l10n.t('sos_my_rescuers'),
                            actionText: l10n.t('common_manage'),
                            onAction: () => _navigateToMesSecours(context),
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          contactsAsync.when(
                            data: (contacts) {
                              return _UnifiedSecoursCard(
                                contacts: contacts,
                                onCircleTap: (circle) =>
                                    _handleCircleTap(context, ref, circle),
                              );
                            },
                            loading: () => const Center(
                                child:
                                    CircularProgressIndicator(color: ThixPolicy.danger)),
                            error: (e, _) => _ErrorRetryWidget(
                              message: l10n.t('sos_load_error'),
                              onRetry: () => ref.invalidate(sosContactsProvider),
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s32),

                          // --- ALERTES À PROXIMITÉ ---
                          const NearbyAlertsCard(),
                          const SizedBox(height: ThixPolicy.s32),

                          // --- ACTIONS RAPIDES ---
                          _SectionLabel(l10n.t('sos_quick_actions')),
                          const SizedBox(height: ThixPolicy.s12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _QuickActionChip(
                                    icon: Icons.location_on_rounded,
                                    label: l10n.t('sos_share_location'),
                                    onTap: () => _soon(context, l10n.t('sos_share_location'))),
                                const SizedBox(width: ThixPolicy.s12),
                                _QuickActionChip(
                                    icon: Icons.timer_rounded,
                                    label: l10n.t('sos_safe_check'),
                                    onTap: () => _soon(context, l10n.t('sos_safe_check'))),
                                const SizedBox(width: ThixPolicy.s12),
                                _QuickActionChip(
                                    icon: Icons.route_rounded,
                                    label: l10n.t('sos_my_routes'),
                                    onTap: () => _soon(context, l10n.t('sos_my_routes'))),
                                const SizedBox(width: ThixPolicy.s12),
                                _QuickActionChip(
                                    icon: Icons.campaign_rounded,
                                    label: l10n.t('sos_report'),
                                    onTap: () => _soon(context, l10n.t('sos_report'))),
                              ],
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s32),

                          // --- MODULES ---
                          _CrisisRoomCard(activeAsync: activeAsync),
                          const SizedBox(height: ThixPolicy.s12),
                          Row(
                            children: [
                              Expanded(
                                child: _NavCardCompact(
                                  icon: Icons.search_rounded,
                                  title: l10n.t('sos_thix_search'),
                                  subtitle: l10n.t('sos_search_subtitle'),
                                  onTap: () => _soon(context, l10n.t('sos_thix_search')),
                                ),
                              ),
                              const SizedBox(width: ThixPolicy.s12),
                              Expanded(
                                child: _NavCardCompact(
                                  icon: Icons.folder_special_rounded,
                                  title: l10n.t('sos_my_incidents'),
                                  subtitle: l10n.t('sos_incidents_subtitle'),
                                  onTap: () => _navigateToMesIncidents(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 BOTTOM NAV FLOTTANTE
          const Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _BottomNavGlass(currentIndex: 2)),
        ],
      ),
    );
  }

  // ✅ FIX P1 : Protection double-tap avec _isProcessing
  Future<void> _handleSosTrigger(BuildContext context, WidgetRef ref) async {
    if (_isProcessing || !mounted) return;
    
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();
    
    try {
      final incident = await ref.read(triggerSosProvider.notifier).trigger();
      
      if (incident != null && mounted) {
        ref.read(sosHeartbeatControllerProvider.notifier).start(incident.id);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SosActifPage(incidentId: incident.id),
          ),
        );
      } else if (mounted) {
        final err = ref.read(triggerSosProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err?.toString() ?? AppLocalizations.of(context).t('sos_trigger_error'),
              style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
            ),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ✅ FIX P0 : Mounted check avant navigation
  void _handleCircleTap(BuildContext context, WidgetRef ref, int circle) {
    if (!mounted) return;
    
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AjouterSecoursPage(initialCircle: circle)),
    ).then((ok) {
      if (ok == true && mounted) ref.invalidate(sosContactsProvider);
    });
  }

  void _navigateToMesSecours(BuildContext context) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MesSecoursPage()),
    );
  }

  void _navigateToMesIncidents(BuildContext context) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MesIncidentsPage()),
    );
  }

  static void _soon(BuildContext context, String label) {
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — bientôt disponible',
            style: ThixPolicy.bodyStyle
                .copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
        backgroundColor: ThixPolicy.inkDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ✅ CARTE CHAMBRE DE CRISE DYNAMIQUE (Optimisée)
// ─────────────────────────────────────────────────────────────
class _CrisisRoomCard extends ConsumerStatefulWidget {
  final AsyncValue<SosIncident?> activeAsync;
  const _CrisisRoomCard({required this.activeAsync});

  @override
  ConsumerState<_CrisisRoomCard> createState() => _CrisisRoomCardState();
}

class _CrisisRoomCardState extends ConsumerState<_CrisisRoomCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _updateAnimationState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isVisible = state == AppLifecycleState.resumed;
    });
    _updateAnimationState();
  }

  void _updateAnimationState() {
    final alert = ref.read(sosRescueAlertProvider);
    if (alert != null && _isVisible && mounted) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void didUpdateWidget(_CrisisRoomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimationState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alert = ref.watch(sosRescueAlertProvider);

    // ── SOS EN COURS (je suis secours cercle 1) → carte rouge pulsante ──
    if (alert != null) {
      return Semantics(
        button: true,
        label: '${l10n.t('sos_open_crisis_room')} ${alert.publicId}',
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glow = 0.35 + 0.35 * _pulse.value;
            return GestureDetector(
              onTap: () => _openRescueRoom(context, alert),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: ThixPolicy.cardPaddingLarge,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7F1D1D),
                      Color.fromRGBO(
                          220, 38, 38, 0.75 + 0.25 * _pulse.value),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.red.withOpacity(glow + 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(glow * 0.55),
                      blurRadius: 18 + 10 * _pulse.value,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 28),
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: const Color(0xFF7F1D1D), width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('sos_active_crisis'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${alert.publicId}'
                            '${alert.victimName != null ? ' • ${alert.victimName}' : ''}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.t('sos_rescue_instructions'),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        l10n.t('common_open'),
                        style: const TextStyle(
                          color: Color(0xFF7F1D1D),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // ── Pas de SOS secours actif → carte classique ──
    return Semantics(
      button: true,
      label: l10n.t('sos_crisis_room'),
      child: GestureDetector(
        onTap: () => _handleCrisisRoomTap(context),
        child: GlassBox(
          color: ThixPolicy.danger.withOpacity(0.15),
          border: Border.all(color: ThixPolicy.danger.withOpacity(0.3), width: 1),
          padding: ThixPolicy.cardPaddingLarge,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: ThixPolicy.danger.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.shield_rounded,
                    color: ThixPolicy.danger, size: 28),
              ),
              const SizedBox(width: ThixPolicy.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('sos_crisis_room'),
                        style: ThixPolicy.titleStyle.copyWith(
                            color: Colors.white, fontWeight: ThixPolicy.bold)),
                    const SizedBox(height: 4),
                    Text(l10n.t('sos_crisis_room_subtitle'),
                        style: ThixPolicy.bodySmallStyle
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCrisisRoomTap(BuildContext context) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    
    final incident = widget.activeAsync.valueOrNull;
    if (incident != null && incident.isActive) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChambreCrisePage(incidentId: incident.id)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MesIncidentsPage()),
      );
    }
  }

  void _openRescueRoom(BuildContext context, RescueAlert alert) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChambreCriseSecoursPage(
          incidentId: alert.incidentId,
          victimUserId: alert.victimId,
        ),
      ),
    );
  }
}

// ───────────────────────── Header Officiel ─────────────────────────
class _HeaderOfficiel extends StatelessWidget {
  const _HeaderOfficiel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            button: true,
            label: AppLocalizations.of(context).t('common_menu'),
            child: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
          ),
          Column(
            children: [
              Text(
                'X THIX',
                style: ThixPolicy.h1Style.copyWith(
                  fontWeight: ThixPolicy.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              Text(
                'CONNECTER • PROTÉGER • AGIR',
                style: ThixPolicy.microStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  letterSpacing: 1.5,
                  color: ThixPolicy.danger,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Semantics(
                button: true,
                label: AppLocalizations.of(context).t('common_notifications'),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 28),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: ThixPolicy.danger,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: ThixPolicy.inkDeep, width: 1.5)),
                        child: Text('3',
                            style: ThixPolicy.microStyle.copyWith(
                                color: Colors.white,
                                fontWeight: ThixPolicy.bold,
                                fontSize: 8)),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: ThixPolicy.s16),
              Semantics(
                button: true,
                label: AppLocalizations.of(context).t('common_profile'),
                child: Container(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 2)),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: ThixPolicy.primaryDeep,
                    // ✅ FIX P0 : Image par défaut sans NetworkImage
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Section Label ─────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.actionText, this.onAction});
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        ),
        if (actionText != null)
          Semantics(
            button: true,
            label: actionText,
            child: GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: ThixPolicy.labelStyle.copyWith(
                    color: Colors.white, fontWeight: ThixPolicy.bold),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Carte "Mes Secours" (Optimisée) ─────────────────────────
class _UnifiedSecoursCard extends HookConsumerWidget {
  final List<dynamic> contacts;
  final Function(int) onCircleTap;

  const _UnifiedSecoursCard({
    required this.contacts,
    required this.onCircleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ FIX P2 : Mémoïser le filtrage par cercle
    final contactsByCircle = useMemoized(() {
      return {
        1: contacts.where((c) => c.circle == 1).toList(),
        2: contacts.where((c) => c.circle == 2).toList(),
        3: contacts.where((c) => c.circle == 3).toList(),
      };
    }, [contacts]);

    final l10n = AppLocalizations.of(context);

    return GlassBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildRow(context, 1, l10n.t('sos_circle_1'), contactsByCircle[1]!),
          const Divider(height: 1, indent: 64, color: Colors.white12),
          _buildRow(context, 2, l10n.t('sos_circle_2'), contactsByCircle[2]!),
          const Divider(height: 1, indent: 64, color: Colors.white12),
          _buildRow(context, 3, l10n.t('sos_circle_3'), contactsByCircle[3]!),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int level, String title, List<dynamic> circleContacts) {
    final count = circleContacts.length;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: '$title, $count ${l10n.t('sos_rescuers')}',
        child: InkWell(
          onTap: () => onCircleTap(level),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: level == 1
                        ? ThixPolicy.danger
                        : Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      level.toString(),
                      style: ThixPolicy.titleStyle.copyWith(
                        color: Colors.white,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ThixPolicy.bodyStyle.copyWith(
                            fontWeight: ThixPolicy.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        count == 0 ? l10n.t('sos_no_rescuers') : '$count ${l10n.t('sos_rescuers')}',
                        style: ThixPolicy.captionStyle.copyWith(
                          color: count == 0
                              ? ThixPolicy.danger
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 0) _buildAvatars(circleContacts),
                if (count > 0) const SizedBox(width: ThixPolicy.s12),
                const Icon(Icons.chevron_right_rounded, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatars(List<dynamic> circleContacts) {
    final displayContacts = circleContacts.take(3).toList();
    const double avatarSize = 28.0;
    const double overlap = 14.0;

    return SizedBox(
      width: avatarSize + (displayContacts.length - 1) * overlap,
      height: avatarSize,
      child: Stack(
        children: List.generate(displayContacts.length, (index) {
          final contact = displayContacts[index];

          String? imageUrl;
          try {
            imageUrl = contact.avatarUrl ?? contact.photoUrl;
          } catch (_) {}

          // ✅ FIX P0 : Validation URL avant utilisation
          final isValidImage = _ImageValidator.isValidUrl(imageUrl);

          return Positioned(
            right: index * overlap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.inkDeep, width: 2.5),
              ),
              child: CircleAvatar(
                radius: (avatarSize / 2) - 2.5,
                backgroundColor: ThixPolicy.border,
                backgroundImage:
                    isValidImage ? NetworkImage(imageUrl!) : null,
                child: !isValidImage
                    ? const Icon(Icons.person, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          );
        }).reversed.toList(),
      ),
    );
  }
}

// ───────────────────────── Action Rapide (Glassmorphism) ─────────────────────────
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: GlassBox(
          borderRadius: ThixPolicy.rFull,
          padding: const EdgeInsets.symmetric(
              horizontal: ThixPolicy.s20, vertical: ThixPolicy.s12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: ThixPolicy.s8),
              Text(label,
                  style: ThixPolicy.labelStyle.copyWith(
                      color: Colors.white, fontWeight: ThixPolicy.semiBold)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Nav Card Compact (Glass) ─────────────────────────
class _NavCardCompact extends StatelessWidget {
  const _NavCardCompact({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: GlassBox(
          padding: ThixPolicy.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: ThixPolicy.s16),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.labelStyle.copyWith(
                      color: Colors.white, fontWeight: ThixPolicy.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      ThixPolicy.captionStyle.copyWith(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Bottom Nav Flottante (Glass) ─────────────────────────
class _BottomNavGlass extends StatelessWidget {
  const _BottomNavGlass({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.home_rounded, AppLocalizations.of(context).t('common_home'), 0),
          _navItem(context, Icons.chat_bubble_rounded, AppLocalizations.of(context).t('common_chat'), 1),
          Semantics(
            button: true,
            label: AppLocalizations.of(context).t('sos_button'),
            child: GestureDetector(
              onTap: () {},
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: ThixPolicy.danger.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(
                  children: [
                    const Icon(Icons.sos_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).t('sos_button'),
                        style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          _navItem(context, Icons.map_rounded, AppLocalizations.of(context).t('common_map'), 3),
          _navItem(context, Icons.person_rounded, AppLocalizations.of(context).t('common_profile'), 4),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int idx) {
    final sel = currentIndex == idx;
    return Semantics(
      button: true,
      label: label,
      selected: sel,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (idx == 0) Navigator.of(context).popUntil((r) => r.isFirst);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: sel ? Colors.white : Colors.white54, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: ThixPolicy.microStyle.copyWith(
                    fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold,
                    color: sel ? Colors.white : Colors.white54,
                    fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Widget Erreur avec Retry ─────────────────────────
class _ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetryWidget({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return GlassBox(
      color: ThixPolicy.danger.withOpacity(0.1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: ThixPolicy.danger, size: 32),
          const SizedBox(height: 8),
          Text(message,
              style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: l10n.t('common_retry'),
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
            ),
          ),
        ],
      ),
    );
  }
}
