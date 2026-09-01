// lib/presentation/chat/call/widgets/call_avatar.dart
//
// ============================================================================
// CALL AVATAR — Production Enterprise
// ============================================================================
//
// Avatar animé avec pulse pour l'écran d'appel.
//
// Fonctionnalités :
//   - Animation pulse + fade pendant la sonnerie
//   - Support image réseau (CachedNetworkImage) avec fallback initiales
//   - Badge vidéo/audio selon le type d'appel
//   - Accessibilité VoiceOver complète
//
// Performance :
//   - RepaintBoundary sur l'image (évite redraws 60fps)
//   - CachedNetworkImage pour cache disque
//   - Listenable.merge mémorisé
//
// Sécurité :
//   - Validation robuste du nom (protection contre RangeError)
//   - Placeholder + error fallback visibles
// ============================================================================

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kDefaultSize = 110.0;
const double _kGlowExtraSize = 22.0;
const double _kBorderWidth = 2.2;
const double _kVideoBadgeBorderWidth = 2.4;
const int _kPulseDurationMs = 1400;
const int _kFadeDurationMs = 900;
const double _kPulseScaleMin = 1.0;
const double _kPulseScaleMax = 1.18;
const double _kFadeOpacityMin = 0.55;
const double _kFadeOpacityMax = 1.0;
const int _kCacheMaxWidth = 400;
const int _kCacheMaxHeight = 400;

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallAvatarValidators {
  _CallAvatarValidators._();

  /// Extrait les initiales de manière safe (protection contre RangeError).
  ///
  /// Règles :
  ///   - Nom vide → `?`
  ///   - 1 mot non vide → première lettre
  ///   - 2+ mots → 2 premières lettres (mots non vides)
  ///   - Caractères non-latins conservés
  ///
  /// Exemples :
  ///   "Jean Dupont"  → "JD"
  ///   "Jean"         → "J"
  ///   " Jean"        → "J"
  ///   ""             → "?"
  ///   "  "           → "?"
  ///   "Élise"        → "É"
  static String safeInitials(String? name) {
    if (name == null) return '?';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].runes.isEmpty ? '?' : String.fromCharCode(parts[0].runes.first).toUpperCase();
    }

    final first = parts[0].runes.isEmpty ? '' : String.fromCharCode(parts[0].runes.first);
    final second = parts[1].runes.isEmpty ? '' : String.fromCharCode(parts[1].runes.first);
    final initials = (first + second).toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  /// Valide une URL d'image.
  static bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}

// ============================================================================
// CALL AVATAR WIDGET
// ============================================================================

/// Avatar animé avec effet pulse pendant la sonnerie.
///
/// Usage :
/// ```dart
/// CallAvatar(
///   name: 'Jean Dupont',
///   imageUrl: 'https://...',
///   isVideo: true,
///   isRinging: true,
/// )
/// ```
class CallAvatar extends StatefulWidget {
  /// Nom du contact (pour les initiales en fallback)
  final String name;

  /// URL de l'image du contact (nullable)
  final String? imageUrl;

  /// Taille de l'avatar en pixels
  final double size;

  /// Vrai pour un appel vidéo (affiche badge videocam)
  final bool isVideo;

  /// Vrai pendant la sonnerie (active l'animation pulse)
  final bool isRinging;

  const CallAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = _kDefaultSize,
    this.isVideo = false,
    this.isRinging = true,
  });

  @override
  State<CallAvatar> createState() => _CallAvatarState();
}

class _CallAvatarState extends State<CallAvatar> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  /// Listenable combiné mémorisé (évite allocation à chaque build)
  late final Listenable _combinedAnimation;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kPulseDurationMs),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kFadeDurationMs),
    );

    _pulseAnim = Tween<double>(
      begin: _kPulseScaleMin,
      end: _kPulseScaleMax,
    ).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutQuad),
    );

    _fadeAnim = Tween<double>(
      begin: _kFadeOpacityMin,
      end: _kFadeOpacityMax,
    ).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut),
    );

    // ✅ Mémorise le Listenable.merge (évite recréation à chaque build)
    _combinedAnimation = Listenable.merge([_pulseAnim, _fadeAnim]);

    if (widget.isRinging) {
      _pulseCtrl.repeat(reverse: true);
      _fadeCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CallAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRinging && !oldWidget.isRinging) {
      _pulseCtrl.repeat(reverse: true);
      _fadeCtrl.repeat(reverse: true);
    } else if (!widget.isRinging && oldWidget.isRinging) {
      _pulseCtrl.stop();
      _fadeCtrl.stop();
      // Reset aux valeurs finales pour éviter un "saut" visuel
      _pulseCtrl.value = 0;
      _fadeCtrl.value = 1;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── BUILD HELPERS ────────────────────────────────────────────────────

  String get _initials => _CallAvatarValidators.safeInitials(widget.name);
  bool get _hasValidImage => _CallAvatarValidators.isValidImageUrl(widget.imageUrl);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.isVideo ? "Appel vidéo" : "Appel audio"} avec ${widget.name}',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _combinedAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isRinging ? _pulseAnim.value : _kPulseScaleMin,
              child: FadeTransition(
                opacity: widget.isRinging ? _fadeAnim : const AlwaysStoppedAnimation(_kFadeOpacityMax),
                child: child,
              ),
            );
          },
          child: _buildAvatarStack(),
        ),
      ),
    );
  }

  Widget _buildAvatarStack() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _buildGlow(),
        _buildMainAvatar(),
        _buildTypeBadge(),
      ],
    );
  }

  /// Halo lumineux externe (glow bleu + or).
  Widget _buildGlow() {
    return Container(
      width: widget.size + _kGlowExtraSize,
      height: widget.size + _kGlowExtraSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.primary.withOpacity(0.32),
            blurRadius: 28,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: ThixPolicy.gold.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  /// Avatar principal : image réseau OU initiales colorées.
  Widget _buildMainAvatar() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ThixPolicy.primaryDeep,
        border: Border.all(
          color: ThixPolicy.gold,
          width: _kBorderWidth,
        ),
      ),
      child: ClipOval(
        child: _hasValidImage
            ? RepaintBoundary(
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl!.trim(),
                  fit: BoxFit.cover,
                  memCacheWidth: _kCacheMaxWidth,
                  memCacheHeight: _kCacheMaxHeight,
                  maxWidthDiskCache: _kCacheMaxWidth,
                  maxHeightDiskCache: _kCacheMaxHeight,
                  placeholder: (context, url) => _buildInitialsFallback(),
                  errorWidget: (context, url, error) => _buildInitialsFallback(),
                  fadeInDuration: const Duration(milliseconds: 200),
                  fadeOutDuration: const Duration(milliseconds: 150),
                ),
              )
            : _buildInitialsFallback(),
      ),
    );
  }

  /// Fallback : initiales centrées sur fond navy.
  Widget _buildInitialsFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: ThixPolicy.primaryDeep,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.size * 0.38,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Badge type d'appel (vidéo ou audio) en bas à droite.
  Widget _buildTypeBadge() {
    if (widget.isVideo) {
      return Positioned(
        right: -2,
        bottom: -2,
        child: Semantics(
          label: 'Appel vidéo',
          child: Container(
            width: widget.size * 0.30,
            height: widget.size * 0.30,
            decoration: BoxDecoration(
              color: ThixPolicy.success,
              shape: BoxShape.circle,
              border: Border.all(
                color: ThixPolicy.primaryDeep,
                width: _kVideoBadgeBorderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.videocam_rounded,
              size: widget.size * 0.16,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Positioned(
      right: -1,
      bottom: -1,
      child: Semantics(
        label: 'Appel audio',
        child: Container(
          width: widget.size * 0.28,
          height: widget.size * 0.28,
          decoration: BoxDecoration(
            color: ThixPolicy.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: ThixPolicy.primaryDeep,
              width: _kBorderWidth,
            ),
          ),
          child: Icon(
            Icons.call_rounded,
            size: widget.size * 0.14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
