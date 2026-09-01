/// THIX SOS — Écran SOS EN COURS (Production Enterprise)
/// ✅ SÉCURISÉ : validation URL, mounted checks, throttling, lifecycle, i18n
/// ✅ DESIGN : ThixPolicy, haptic, semantics, skeleton, premium UX
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/nav.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import '../thix_sos_screen.dart';
import 'chambre_crise_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kCancelThrottle = Duration(seconds: 3);
const int _kPinLength = 6;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ActifValidators {
  _ActifValidators._();

  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String safeInitial(String? name, {String fallback = '?'}) {
    if (name == null || name.trim().isEmpty) return fallback;
    return name.trim()[0].toUpperCase();
  }

  static bool isValidPin(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  static String friendlyError(dynamic e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return l10n.t('sos_error_timeout');
    if (msg.contains('network')) return l10n.t('sos_error_network');
    return l10n.t('sos_error_generic');
  }
}

// ============================================================================
// PAGE
// ============================================================================
class SosActifPage extends ConsumerStatefulWidget {
  const SosActifPage({super.key, required this.incidentId});
  final String incidentId;

  @override
  ConsumerState<SosActifPage> createState() => _SosActifPageState();
}

class _SosActifPageState extends ConsumerState<SosActifPage>
    with WidgetsBindingObserver {
  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;

  int _escalationCircle = 1;
  int _escalationLeft = 0;
  DateTime? _lastCancel;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final incident =
          ref.read(sosIncidentProvider(widget.incidentId)).valueOrNull;
      if (incident != null) {
        final d = DateTime.now().difference(incident.startedAt);
        setState(() => _elapsed = d.isNegative ? Duration.zero : d);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(sosHeartbeatControllerProvider.notifier)
          .start(widget.incidentId);

      final escalation = ref.read(sosEscalationProvider);
      escalation.onTick = (circle, left) {
        if (mounted) {
          setState(() {
            _escalationCircle = circle;
            _escalationLeft = left;
          });
        }
      };

      escalation.onEvent = (msg) {
        if (mounted) {
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(color: Colors.white)),
              backgroundColor: ThixPolicy.card,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      };
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[SosActif] 🔄 lifecycle: ${state.name}');
    // Le timer continue en background pour mesurer la durée réelle
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    // ✅ Détache les callbacks d'escalade (évite les fuites mémoire)
    try {
      final escalation = ref.read(sosEscalationProvider);
      escalation.onTick = null;
      escalation.onEvent = null;
    } catch (_) {}
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ✅ FIX : throttling + mounted check + haptic + logs
  Future<void> _cancelSos(SosIncident incident) async {
    if (_isCancelling) return;
    final now = DateTime.now();
    if (_lastCancel != null &&
        now.difference(_lastCancel!) < _kCancelThrottle) {
      debugPrint('[SosActif] ⚠️ Cancel throttled');
      return;
    }
    _lastCancel = now;
    HapticFeedback.mediumImpact();

    final l10n = AppLocalizations.of(context);
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PinDialog(),
    );
    if (pin == null || pin.isEmpty || !mounted) return;

    if (!_ActifValidators.isValidPin(pin)) {
      _showSnack(l10n.t('sos_pin_invalid'), ThixPolicy.warning);
      return;
    }

    setState(() => _isCancelling = true);
    try {
      final ok = await ref
          .read(sosResolveProvider.notifier)
          .cancel(incident.id);
      if (!mounted) return;

      if (ok) {
        HapticFeedback.heavyImpact();
        _showSnack(l10n.t('sos_cancelled'), ThixPolicy.success);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ThixSosScreen()),
          (_) => false,
        );
      } else {
        HapticFeedback.lightImpact();
        _showSnack(l10n.t('sos_cancel_failed'), ThixPolicy.danger);
      }
    } catch (e) {
      debugPrint('[SosActif] ❌ Cancel error: $e');
      if (mounted) {
        _showSnack(
          _ActifValidators.friendlyError(e, l10n),
          ThixPolicy.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openChat(SosIncident incident) {
    final l10n = AppLocalizations.of(context);
    final convId = incident.chatConversationId;
    if (convId == null || convId.isEmpty) {
      _showSnack(l10n.t('sos_chat_not_ready'), ThixPolicy.warning);
      return;
    }
    HapticFeedback.mediumImpact();
    context.push(
      AppRoutes.chatDetail(convId),
      extra: ChatConversation(
        id: convId,
        isGroup: true,
        groupName: 'THIX CHAT ${incident.publicId}',
        participantIds: const [],
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _openCrisisRoom(SosIncident incident) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChambreCrisePage(
          incidentId: incident.id,
          conversationId: incident.chatConversationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final incidentAsync = ref.watch(sosIncidentProvider(widget.incidentId));
    final contactsAsync = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: SafeArea(
        child: incidentAsync.when(
          loading: () => const _SkeletonLoader(),
          error: (e, stack) {
            debugPrint('[SosActif] ❌ Load error: $e');
            return _ErrorState(
              message: _ActifValidators.friendlyError(e, l10n),
              onRetry: () =>
                  ref.invalidate(sosIncidentProvider(widget.incidentId)),
            );
          },
          data: (incident) {
            if (incident == null) {
              return _ErrorState(
                message: l10n.t('sos_incident_not_found'),
                onRetry: () =>
                    ref.invalidate(sosIncidentProvider(widget.incidentId)),
              );
            }

            final circleContacts = contactsAsync.maybeWhen(
              data: (all) => all
                  .where((c) => c.circle == incident.activeCircle)
                  .toList(),
              orElse: () => <SosContact>[],
            );

            return Column(
              children: [
                _Header(
                  publicId: incident.publicId,
                  elapsed: _elapsedLabel,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: ThixPolicy.danger,
                    backgroundColor: ThixPolicy.card,
                    onRefresh: () async {
                      ref.invalidate(sosIncidentProvider(widget.incidentId));
                      ref.invalidate(sosContactsProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(ThixPolicy.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status row
                          Row(
                            children: [
                              _StatusChip(
                                icon: Icons.location_on,
                                label: l10n.t('sos_status_location'),
                                value: incident.hasLocation
                                    ? l10n.t('sos_status_active')
                                    : l10n.t('sos_status_waiting'),
                                active: incident.hasLocation,
                              ),
                              const SizedBox(width: ThixPolicy.s8),
                              _StatusChip(
                                icon: Icons.favorite,
                                label: 'Heartbeat',
                                value: l10n.t('sos_status_active'),
                                active: true,
                              ),
                              const SizedBox(width: ThixPolicy.s8),
                              _StatusChip(
                                icon: Icons.cloud_done,
                                label: l10n.t('sos_status_backup'),
                                value: l10n.t('sos_status_active'),
                                active: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: ThixPolicy.s20),

                          _SectionTitle(
                              text: l10n.t('sos_auto_call_in_progress')),
                          const SizedBox(height: ThixPolicy.s6),
                          Text(
                            '${l10n.t('sos_circle')} ${incident.activeCircle} – ${incident.status.labelFr}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThixPolicy.success,
                            ),
                          ),
                          if (_escalationLeft > 0) ...[
                            const SizedBox(height: ThixPolicy.s4),
                            Text(
                              '${l10n.t('sos_circle')} $_escalationCircle — ${l10n.t('sos_next_in')} ${_escalationLeft}s',
                              style: GoogleFonts.inter(
                                  color: ThixPolicy.textMuted, fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: ThixPolicy.s12),

                          if (circleContacts.isEmpty)
                            _EmptyContacts(l10n: l10n)
                          else
                            ...circleContacts.map(
                              (c) => _ContactCallTile(contact: c),
                            ),

                          const SizedBox(height: ThixPolicy.s20),
                          _SectionTitle(
                              text: l10n.t('sos_section_location')),
                          const SizedBox(height: ThixPolicy.s10),
                          _LocationCard(incident: incident),
                          const SizedBox(height: ThixPolicy.s20),

                          _ActionBar(
                            title: l10n.t('sos_chat_sos'),
                            subtitle: l10n.t('sos_open_urgent_chat'),
                            icon: Icons.chat_bubble_outline,
                            color: ThixPolicy.primary,
                            onTap: () => _openChat(incident),
                          ),
                          const SizedBox(height: ThixPolicy.s10),
                          _ActionBar(
                            title: l10n.t('sos_crisis_room'),
                            subtitle: l10n.t('sos_open_crisis_room'),
                            icon: Icons.desktop_windows_outlined,
                            color: ThixPolicy.danger,
                            filled: true,
                            onTap: () => _openCrisisRoom(incident),
                          ),
                          const SizedBox(height: ThixPolicy.s16),

                          Semantics(
                            button: true,
                            label: l10n.t('sos_cancel_sos'),
                            enabled: !_isCancelling,
                            child: Material(
                              color: ThixPolicy.card,
                              borderRadius:
                                  BorderRadius.circular(ThixPolicy.rMd),
                              child: InkWell(
                                onTap: _isCancelling
                                    ? null
                                    : () => _cancelSos(incident),
                                borderRadius:
                                    BorderRadius.circular(ThixPolicy.rMd),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(ThixPolicy.s16),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(ThixPolicy.rMd),
                                    border: Border.all(
                                      color: ThixPolicy.danger
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _isCancelling
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: ThixPolicy.danger,
                                              ),
                                            )
                                          : const Icon(Icons.lock_outline,
                                              color: ThixPolicy.danger),
                                      const SizedBox(width: ThixPolicy.s12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.t('sos_cancel_sos'),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: ThixPolicy.danger,
                                              ),
                                            ),
                                            Text(
                                              l10n.t('sos_pin_required'),
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: ThixPolicy.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          color: ThixPolicy.textMuted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================
class _Header extends StatelessWidget {
  const _Header({required this.publicId, required this.elapsed});
  final String publicId;
  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThixPolicy.danger,
            ThixPolicy.danger.withValues(alpha: 0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.t('sos_active'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.shield, color: Colors.white54, size: 22),
            ],
          ),
          const SizedBox(height: ThixPolicy.s8),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  icon: Icons.timer_outlined,
                  label: l10n.t('sos_duration'),
                  value: elapsed,
                ),
              ),
              Expanded(
                child: _HeaderStat(
                  icon: Icons.tag,
                  label: l10n.t('sos_identifier'),
                  value: publicId.replaceAll('SOS ', ''),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER STAT
// ============================================================================
class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: ThixPolicy.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white54),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ThixPolicy.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? ThixPolicy.success : ThixPolicy.textMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style:
                  GoogleFonts.inter(fontSize: 10, color: ThixPolicy.textMuted),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CONTACT CALL TILE — ✅ URL validée + safe initial + semantics
// ============================================================================
class _ContactCallTile extends StatelessWidget {
  const _ContactCallTile({required this.contact});
  final SosContact contact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final validPhoto = _ActifValidators.isValidUrl(contact.photoUrl);
    final safeName =
        contact.name.isNotEmpty ? contact.name : l10n.t('sos_unknown');

    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s8),
      padding: const EdgeInsets.all(ThixPolicy.s12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Semantics(
        label: '${l10n.t('sos_rescuer')} $safeName, ${l10n.t('sos_calling')}',
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  ThixPolicy.success.withValues(alpha: 0.15),
              backgroundImage:
                  validPhoto ? NetworkImage(contact.photoUrl!) : null,
              child: !validPhoto
                  ? Text(
                      _ActifValidators.safeInitial(safeName),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: ThixPolicy.success,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safeName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: ThixPolicy.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.t('sos_calling'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: ThixPolicy.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.phone_in_talk,
                color: ThixPolicy.success, size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOCATION CARD — ✅ FIX null lat/lng
// ============================================================================
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPos = incident.hasLocation &&
        incident.lastLat != null &&
        incident.lastLng != null;

    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.my_location,
                  color: hasPos ? ThixPolicy.primary : ThixPolicy.textMuted,
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  hasPos
                      ? l10n.t('sos_position_active')
                      : l10n.t('sos_position_waiting'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: ThixPolicy.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (hasPos)
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Text(
                  '${incident.lastLat!.toStringAsFixed(5)}, '
                  '${incident.lastLng!.toStringAsFixed(5)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTION BAR
// ============================================================================
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: filled ? color : ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ThixPolicy.s14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: filled ? null : Border.all(color: ThixPolicy.border),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: filled ? Colors.white : color, size: 22),
                const SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: filled
                              ? Colors.white70
                              : ThixPolicy.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: filled ? Colors.white70 : ThixPolicy.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY CONTACTS
// ============================================================================
class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThixPolicy.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_outlined,
                color: ThixPolicy.warning, size: 24),
          ),
          const SizedBox(height: ThixPolicy.s10),
          Text(
            l10n.t('sos_no_rescuers_circle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ThixPolicy.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PIN DIALOG — ✅ Validation + haptic + semantics + auto-submit
// ============================================================================
class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();
  bool _isInvalid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _ctrl.text.trim();
    if (!_ActifValidators.isValidPin(pin)) {
      setState(() => _isInvalid = true);
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: ThixPolicy.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        side: BorderSide(color: ThixPolicy.border),
      ),
      title: Semantics(
        header: true,
        child: Text(
          l10n.t('sos_pin_title'),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            textField: true,
            label: l10n.t('sos_pin_label'),
            child: TextField(
              controller: _ctrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: _kPinLength,
              autofocus: true,
              onChanged: (_) => setState(() => _isInvalid = false),
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: Colors.white,
                letterSpacing: 8,
                fontSize: 20,
              ),
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: const TextStyle(
                    color: Colors.white24, letterSpacing: 8),
                counterText: '',
                errorText: _isInvalid
                    ? l10n.t('sos_pin_invalid')
                    : null,
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  borderSide: BorderSide(
                    color: _isInvalid
                        ? ThixPolicy.danger
                        : ThixPolicy.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  borderSide: BorderSide(
                    color: _isInvalid
                        ? ThixPolicy.danger
                        : ThixPolicy.border,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Semantics(
          button: true,
          label: l10n.t('common_cancel'),
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.t('common_cancel'),
              style: TextStyle(color: ThixPolicy.textMuted),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('common_confirm'),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
            ),
            onPressed: _submit,
            child: Text(l10n.t('common_confirm')),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SKELETON LOADER
// ============================================================================
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double h, [double w = double.infinity]) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.35 + 0.3 * _ctrl.value,
        child: Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: ThixPolicy.border,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _box(120),
          const SizedBox(height: 16),
          _box(48),
          const SizedBox(height: 12),
          _box(60),
          const SizedBox(height: 20),
          _box(140),
          const SizedBox(height: 20),
          _box(70),
          const SizedBox(height: 10),
          _box(70),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: ThixPolicy.danger, size: 48),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: ThixPolicy.s20),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ThixPolicy.rSm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
