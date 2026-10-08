// lib/presentation/chat/call/incoming_call_page.dart
//
// ============================================================================
// INCOMING CALL PAGE — v2.2
// ============================================================================
// Nouveau : affiche le NOM et la PHOTO de l'appelant (chargés depuis `profiles`)
//           dès la sonnerie, et les transmet à l'appel une fois décroché.
// Aussi : délai de service porté à 25 s, textes de secours si une clé de
//         traduction manque (plus de « call_incoming_audio » brut).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/call/call_page.dart';
import 'package:thix_id/presentation/chat/call/call_peer_profile.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/presentation/thix_sos/pages/chambre_crise_secours_page.dart';
import 'package:thix_id/presentation/thix_sos/providers/sos_providers.dart';

const double _kAvatarRadius = 64.0;
const double _kButtonSize = 72.0;
const double _kIconSize = 32.0;
const Duration _kAnimationDuration = Duration(milliseconds: 1500);
const Duration _kServiceTimeout = Duration(seconds: 25);

// ── Textes de secours [EN, FR] si la clé l10n manque ──
const Map<String, List<String>> _kFb = {
  'call_incoming_unknown': ['Unknown caller', 'Appelant inconnu'],
  'call_incoming_video': ['Incoming video call', 'Appel vidéo entrant'],
  'call_incoming_audio': ['Incoming audio call', 'Appel audio entrant'],
  'call_incoming_subtitle': ['THIX Chat is calling you…', 'THIX Chat vous appelle…'],
  'call_reject': ['Decline', 'Refuser'],
  'call_accept': ['Accept', 'Répondre'],
  'call_crisis_room': ['Crisis room', 'Chambre de crise'],
  'call_error_reject_failed': ['Could not decline the call.', 'Impossible de refuser l’appel.'],
  'call_error_invalid_caller': ['Invalid caller.', 'Appelant invalide.'],
  'call_no_active_sos': ['No active SOS for this caller.', 'Aucun SOS actif pour cet appelant.'],
  'call_error_crisis_room_failed': ['Could not open the crisis room.', 'Impossible d’ouvrir la chambre de crise.'],
  'call_error_not_authenticated': ['You are not signed in.', 'Vous n’êtes pas connecté.'],
  'call_error_accept_failed': ['Could not accept the call.', 'Impossible de décrocher.'],
};

String _t(BuildContext ctx, String key) {
  final s = AppLocalizations.of(ctx).t(key);
  if (s.isNotEmpty && s != key) return s;
  final fb = _kFb[key];
  if (fb == null) return key;
  return Localizations.localeOf(ctx).languageCode == 'fr' ? fb[1] : fb[0];
}

class _CallValidators {
  _CallValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  static String clean(String? s) =>
      (s ?? '').replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();

  static String? safeUrl(String? url) {
    final t = (url ?? '').trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    if (t.isEmpty || t.length > 2048) return null;
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority || (u.scheme != 'http' && u.scheme != 'https')) return null;
    return t;
  }
}

class IncomingCallPage extends ConsumerStatefulWidget {
  final CallInvite invite;
  final String? callerName;
  final String? callerAvatar;

  const IncomingCallPage({
    super.key,
    required this.invite,
    this.callerName,
    this.callerAvatar,
  });

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;
  late Animation<double> _glowAnimation;

  bool _isProcessing = false;
  String? _processingAction;

  // ── Nom / photo : paramètres → invitation → profil chargé ──
  CallPeer? get _peer => _CallValidators.isValidUuid(widget.invite.callerId)
      ? ref.read(callPeerProvider(widget.invite.callerId)).valueOrNull
      : null;

  String get _resolvedName {
    for (final c in [widget.callerName, widget.invite.callerName, _peer?.name]) {
      final s = _CallValidators.clean(c);
      if (s.isNotEmpty) return s.length > 100 ? s.substring(0, 100) : s;
    }
    return '';
  }

  String? get _resolvedAvatar {
    for (final c in [widget.callerAvatar, widget.invite.callerAvatar, _peer?.avatarUrl]) {
      final u = _CallValidators.safeUrl(c);
      if (u != null) return u;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(duration: _kAnimationDuration, vsync: this)
      ..repeat(reverse: true);

    _ringAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );

    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  void _snack(String message, Color bg, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
        ]),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    _snack(message, ThixPolicy.danger, Icons.error_outline_rounded);
  }

  void _showInfo(String message) => _snack(message, ThixPolicy.primary, Icons.info_outline_rounded);

  Future<void> _rejectCall() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingAction = 'reject';
    });
    HapticFeedback.mediumImpact();

    try {
      await ref.read(callProvider.notifier).rejectIncoming(widget.invite.id).timeout(_kServiceTimeout);
      if (!mounted) return;
      Navigator.maybePop(context);
    } catch (e) {
      debugPrint('[IncomingCall] ❌ Reject failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showError(_t(context, 'call_error_reject_failed'));
      }
    }
  }

  Future<void> _openCrisisRoom() async {
    if (_isProcessing) return;

    final callerId = widget.invite.callerId;
    if (!_CallValidators.isValidUuid(callerId)) {
      _showError(_t(context, 'call_error_invalid_caller'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingAction = 'crisis';
    });
    HapticFeedback.mediumImpact();

    try {
      final sosService = ref.read(sosServiceProvider);
      final incident = await sosService.findActiveByVictim(callerId).timeout(_kServiceTimeout);

      if (!mounted) return;

      if (incident == null) {
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showInfo(_t(context, 'call_no_active_sos'));
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChambreCriseSecoursPage(incidentId: incident.id, victimUserId: callerId),
        ),
      );
    } catch (e) {
      debugPrint('[IncomingCall] ❌ Crisis room failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showError(_t(context, 'call_error_crisis_room_failed'));
      }
    }
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) return;

    final myId = ref.read(supabaseUserIdProvider);
    if (myId == null || !_CallValidators.isValidUuid(myId)) {
      _showError(_t(context, 'call_error_not_authenticated'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingAction = 'accept';
    });
    HapticFeedback.mediumImpact();

    try {
      await ref
          .read(callProvider.notifier)
          .acceptIncoming(
            invite: widget.invite,
            myUserId: myId,
            callerName: _resolvedName, // nom + photo transmis à l'appel
            callerAvatar: _resolvedAvatar,
          )
          .timeout(_kServiceTimeout);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CallPage()));
    } catch (e) {
      debugPrint('[IncomingCall] ❌ Accept failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showError(_t(context, 'call_error_accept_failed'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // On observe le profil : l'écran se met à jour dès que nom/photo arrivent
    if (_CallValidators.isValidUuid(widget.invite.callerId)) {
      ref.watch(callPeerProvider(widget.invite.callerId));
    }

    final resolved = _resolvedName;
    final name = resolved.isEmpty ? _t(context, 'call_incoming_unknown') : resolved;
    final avatar = _resolvedAvatar;
    final isVideo = widget.invite.callType == CallType.video;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThixPolicy.primaryDeep,
              ThixPolicy.primary.withOpacity(0.8),
              ThixPolicy.surface,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (avatar != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
              Column(
                children: [
                  const Spacer(flex: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isVideo ? _t(context, 'call_incoming_video') : _t(context, 'call_incoming_audio'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _ringAnimation,
                    builder: (context, child) => Transform.scale(scale: _ringAnimation.value, child: child),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(_glowAnimation.value),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: _kAvatarRadius,
                        backgroundColor: Colors.white,
                        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                        onBackgroundImageError: avatar != null ? (_, __) {} : null,
                        child: avatar == null
                            ? Icon(Icons.person_rounded, size: _kAvatarRadius * 0.9, color: ThixPolicy.primary)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(context, 'call_incoming_subtitle'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(flex: 3),
                  _buildActions(isVideo),
                  const SizedBox(height: 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(bool isVideo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CallActionButton(
            color: ThixPolicy.danger,
            icon: Icons.call_end_rounded,
            label: _t(context, 'call_reject'),
            isLoading: _isProcessing && _processingAction == 'reject',
            onTap: _rejectCall,
            enabled: !_isProcessing,
          ),
          _CallActionButton(
            color: Colors.orange,
            icon: Icons.shield_rounded,
            label: _t(context, 'call_crisis_room'),
            isLoading: _isProcessing && _processingAction == 'crisis',
            onTap: _openCrisisRoom,
            enabled: !_isProcessing,
            isOutlined: true,
          ),
          _CallActionButton(
            color: ThixPolicy.success,
            icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            label: _t(context, 'call_accept'),
            isLoading: _isProcessing && _processingAction == 'accept',
            onTap: _acceptCall,
            enabled: !_isProcessing,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isLoading;
  final bool isOutlined;
  final bool isPrimary;

  const _CallActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onTap,
    this.enabled = true,
    this.isOutlined = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && !isLoading;
    final size = isPrimary ? _kButtonSize + 8.0 : _kButtonSize;
    final iconSize = isPrimary ? _kIconSize + 4.0 : _kIconSize;

    return Semantics(
      button: true,
      label: label,
      enabled: effectiveEnabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: effectiveEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(size / 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isOutlined
                    ? Colors.transparent
                    : (effectiveEnabled ? color : color.withOpacity(0.5)),
                shape: BoxShape.circle,
                border: isOutlined
                    ? Border.all(color: effectiveEnabled ? color : color.withOpacity(0.5), width: 2)
                    : null,
                boxShadow: effectiveEnabled && !isOutlined
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: isPrimary ? 20 : 12,
                          offset: Offset(0, isPrimary ? 8 : 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: iconSize * 0.8,
                        height: iconSize * 0.8,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(isOutlined ? color : Colors.white),
                        ),
                      )
                    : Icon(icon, color: isOutlined ? color : Colors.white, size: iconSize),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: effectiveEnabled ? Colors.white : Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
