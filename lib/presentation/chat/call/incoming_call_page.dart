// lib/presentation/chat/call/incoming_call_page.dart
//
// ============================================================================
// INCOMING CALL PAGE — Production Enterprise v2.0
// ============================================================================
//
// Page d'appel entrant avec design moderne, états de chargement visuels 
// et hiérarchie d'actions claire (Accepter, Refuser, Chambre de crise).
//
// Améliorations UX/UI :
//   - Design "Glassmorphism" cohérent avec THIX Chat
//   - États de chargement (spinner) sur les boutons pendant le traitement
//   - Animation de sonnerie améliorée (pulse + glow)
//   - Hiérarchie visuelle : Accepter (vert lumineux) > Refuser (rouge) > Crise (orange distinct)
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
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/presentation/thix_sos/pages/chambre_crise_secours_page.dart';
import 'package:thix_id/presentation/thix_sos/providers/sos_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kAvatarRadius = 64.0;
const double _kButtonSize = 72.0;
const double _kIconSize = 32.0;
const Duration _kAnimationDuration = Duration(milliseconds: 1500);
const Duration _kServiceTimeout = Duration(seconds: 10);

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallValidators {
  _CallValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  static String safeName(String? name, AppLocalizations l10n) {
    if (name == null || name.trim().isEmpty) {
      return l10n.t('call_incoming_unknown');
    }
    return name.trim();
  }
}

// ============================================================================
// INCOMING CALL PAGE
// ============================================================================

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
  String? _processingAction; // 'accept', 'reject', 'crisis'

  @override
  void initState() {
    super.initState();
    debugPrint('[IncomingCall] 📞 Page opened for invite: ${widget.invite.id}');

    // Animation de sonnerie (scale)
    _ringController = AnimationController(
      duration: _kAnimationDuration,
      vsync: this,
    )..repeat(reverse: true);

    _ringAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );

    // Animation de lueur (glow) pour le bouton accepter
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );

    // Vibration haptique pour simuler la sonnerie physique
    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _ringController.dispose();
    debugPrint('[IncomingCall] 👋 Page disposed');
    super.dispose();
  }

  // ── FEEDBACK HELPERS ─────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── ACTIONS ──────────────────────────────────────────────────────────

  Future<void> _rejectCall() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingAction = 'reject';
    });
    HapticFeedback.mediumImpact();
    
    final l10n = AppLocalizations.of(context);
    debugPrint('[IncomingCall] ❌ Rejecting call: ${widget.invite.id}');

    try {
      await ref.read(callProvider.notifier)
          .rejectIncoming(widget.invite.id)
          .timeout(_kServiceTimeout);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('[IncomingCall] ❌ Reject failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showError(l10n.t('call_error_reject_failed'));
      }
    }
  }

  Future<void> _openCrisisRoom() async {
    if (_isProcessing) return;
    
    final callerId = widget.invite.callerId;
    if (!_CallValidators.isValidUuid(callerId)) {
      debugPrint('[IncomingCall] ⚠️ Invalid callerId: $callerId');
      _showError(AppLocalizations.of(context).t('call_error_invalid_caller'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingAction = 'crisis';
    });
    HapticFeedback.mediumImpact();
    
    final l10n = AppLocalizations.of(context);
    debugPrint('[IncomingCall] 🚨 Opening crisis room for: $callerId');

    try {
      final sosService = ref.read(sosServiceProvider);
      final incident = await sosService
          .findActiveByVictim(callerId)
          .timeout(_kServiceTimeout);

      if (!mounted) return;

      if (incident == null) {
        debugPrint('[IncomingCall] ⚠️ No active SOS for caller');
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showInfo(l10n.t('call_no_active_sos'));
        return;
      }

      debugPrint('[IncomingCall] ✓ Navigating to crisis room: ${incident.id}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChambreCriseSecoursPage(
            incidentId: incident.id,
            victimUserId: callerId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[IncomingCall] ❌ Crisis room failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showError(l10n.t('call_error_crisis_room_failed'));
      }
    }
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) return;

    final myId = ref.read(supabaseUserIdProvider);
    if (myId == null || !_CallValidators.isValidUuid(myId)) {
      debugPrint('[IncomingCall] ⚠️ No valid current user');
      _showError(AppLocalizations.of(context).t('call_error_not_authenticated'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingAction = 'accept';
    });
    HapticFeedback.mediumImpact();
    
    final l10n = AppLocalizations.of(context);
    debugPrint('[IncomingCall] ✅ Accepting call: ${widget.invite.id}');

    try {
      await ref.read(callProvider.notifier).acceptIncoming(
            invite: widget.invite,
            myUserId: myId,
            callerName: widget.callerName ?? widget.invite.callerName,
            callerAvatar: widget.callerAvatar,
          ).timeout(_kServiceTimeout);

      if (!mounted) return;
      debugPrint('[IncomingCall] ✓ Call accepted, navigating to CallPage');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CallPage()),
      );
    } catch (e) {
      debugPrint('[IncomingCall] ❌ Accept failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingAction = null;
        });
        _showError(l10n.t('call_error_accept_failed'));
      }
    }
  }

  // ── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _CallValidators.safeName(
      widget.callerName ?? widget.invite.callerName,
      l10n,
    );
    final isVideo = widget.invite.type == CallType.video; // Correction: utilisation de type

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
              // Background subtil avec l'avatar en grand et flouté (si disponible)
              if (widget.callerAvatar != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.network(
                      widget.callerAvatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
              
              // Contenu principal
              Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Badge Type d'appel ──
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
                        Icon(
                          isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVideo ? l10n.t('call_incoming_video') : l10n.t('call_incoming_audio'),
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

                  // ── Avatar avec animation ringing ──
                  AnimatedBuilder(
                    animation: _ringAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _ringAnimation.value,
                        child: child,
                      );
                    },
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
                        backgroundImage: widget.callerAvatar != null
                            ? NetworkImage(widget.callerAvatar!)
                            : null,
                        child: widget.callerAvatar == null
                            ? Icon(
                                Icons.person_rounded,
                                size: _kAvatarRadius * 0.9,
                                color: ThixPolicy.primary,
                              )
                            : null,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // ── Nom de l'appelant ──
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
                    l10n.t('call_incoming_subtitle'), // Assurez-vous que cette clé existe, sinon utilisez "Appel entrant..."
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Actions ──
                  _buildActions(l10n, isVideo),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(AppLocalizations l10n, bool isVideo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Refuser (Gauche)
          _CallActionButton(
            color: ThixPolicy.danger,
            icon: Icons.call_end_rounded,
            label: l10n.t('call_reject'),
            isLoading: _isProcessing && _processingAction == 'reject',
            onTap: _rejectCall,
            enabled: !_isProcessing,
          ),

          // 2. Chambre de crise (Centre, légèrement en retrait ou distinct)
          _CallActionButton(
            color: Colors.orange, // Couleur d'avertissement distincte
            icon: Icons.shield_rounded,
            label: l10n.t('call_crisis_room'),
            isLoading: _isProcessing && _processingAction == 'crisis',
            onTap: _openCrisisRoom,
            enabled: !_isProcessing,
            isOutlined: true, // Style distinct pour ne pas confondre avec accepter/refuser
          ),

          // 3. Accepter (Droite, mis en avant)
          _CallActionButton(
            color: ThixPolicy.success,
            icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            label: l10n.t('call_accept'),
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

// ============================================================================
// CALL ACTION BUTTON
// ============================================================================

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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOutlined ? color : Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        color: isOutlined ? color : Colors.white,
                        size: iconSize,
                      ),
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
