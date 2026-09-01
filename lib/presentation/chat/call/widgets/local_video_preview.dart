// lib/presentation/chat/call/widgets/local_video_preview.dart
//
// ============================================================================
// LOCAL VIDEO PREVIEW — Production Enterprise
// ============================================================================
//
// Préview vidéo locale (PiP) draggable pendant un appel.
//
// Fonctionnalités :
//   - Préview vidéo Agora RTC en Picture-in-Picture
//   - Drag & drop avec contraintes responsive
//   - État caméra off avec fallback visuel
//   - État moteur non-initialisé (loading)
//   - Miroir caméra frontale configurable
//
// Architecture :
//   - CallMediaService injecté via Riverpod (singleton)
//   - RepaintBoundary sur la vidéo (évite redraws pendant drag)
//   - Contraintes drag calculées depuis MediaQuery (responsive)
//
// Sécurité :
//   - Validation stricte du channel name
//   - Null-safety sur engine Agora
//   - Mounted checks sur tous les setState
//
// Accessibilité :
//   - Semantics complets (label, button sur zone drag)
//   - HapticFeedback sur drag start
//   - Texte i18n (FR/EN)
//
// ⚠️ IMPORTANT : Ce widget DOIT être utilisé à l'intérieur d'un Stack.
// Il retourne un Positioned qui sera positionné en haut à droite par défaut.
// ============================================================================

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/services/chat/call_media_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kPreviewWidth = 112.0;
const double _kPreviewHeight = 168.0;
const double _kPreviewTopOffset = 90.0;
const double _kPreviewRightOffset = 16.0;
const double _kBorderRadius = 14.0;
const double _kInnerBorderRadius = 13.0;
const double _kBorderWidthNormal = 1.0;
const double _kBorderWidthDragging = 1.6;
const double _kLabelPaddingH = 6.0;
const double _kLabelPaddingV = 3.0;
const double _kDragIndicatorPadding = 4.0;
const double _kDragScaleFactor = 1.05;
const int _kDragAnimationDurationMs = 150;
const int _kMaxChannelLength = 100;

// ============================================================================
// VALIDATORS
// ============================================================================
class _LocalVideoValidators {
  _LocalVideoValidators._();

  /// Valide un channel name Agora.
  ///
  /// Règles :
  ///   - Non null, non vide après trim
  ///   - Longueur max [_kMaxChannelLength]
  ///   - Caractères alphanumériques + underscore + tiret uniquement
  static bool isValidChannel(String? channel) {
    if (channel == null) return false;
    final trimmed = channel.trim();
    if (trimmed.isEmpty || trimmed.length > _kMaxChannelLength) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  }
}

// ============================================================================
// LOCAL VIDEO PREVIEW WIDGET
// ============================================================================

/// Préview vidéo locale (PiP) draggable.
///
/// **Usage** :
/// ```dart
/// Stack(
///   children: [
///     // ... remote video ...
///     LocalVideoPreview(
///       channel: 'live_abc123',
///       videoOff: state.videoOff,
///       isFrontCamera: state.isFrontCam,
///     ),
///   ],
/// )
/// ```
///
/// ⚠️ **Doit être utilisé à l'intérieur d'un Stack** (retourne un Positioned).
class LocalVideoPreview extends ConsumerStatefulWidget {
  /// Nom du canal Agora (doit être non vide et valide)
  final String channel;

  /// Vrai si la caméra est coupée
  final bool videoOff;

  /// Vrai pour caméra frontale (miroir activé)
  final bool isFrontCamera;

  const LocalVideoPreview({
    super.key,
    required this.channel,
    this.videoOff = false,
    this.isFrontCamera = true,
  });

  @override
  ConsumerState<LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends ConsumerState<LocalVideoPreview> {
  Offset _offset = Offset.zero;
  bool _isDragging = false;
  bool _isDisposed = false;

  // ── LIFECYCLE ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    debugPrint('[LocalVideoPreview] 🚀 Initialized '
        '(channel=${_obfuscateChannel(widget.channel)})');

    if (!_LocalVideoValidators.isValidChannel(widget.channel)) {
      debugPrint('[LocalVideoPreview] ⚠️ Invalid channel name provided');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint('[LocalVideoPreview] 👋 Disposed');
    super.dispose();
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  /// Récupère le moteur Agora via Riverpod (singleton).
  RtcEngine? get _engine {
    try {
      return ref.read(callMediaServiceProvider).engine;
    } catch (e) {
      debugPrint('[LocalVideoPreview] ⚠️ Engine access error: $e');
      return null;
    }
  }

  /// Calcule les contraintes de drag en fonction de la taille de l'écran.
  ///
  /// Garantit que le PiP reste visible sur tous les formats d'écran.
  Offset _clampOffset(Offset raw, Size screenSize) {
    // Marge minimale : le PiP doit rester visible à l'écran
    final maxDx = screenSize.width - _kPreviewWidth - _kPreviewRightOffset + 50;
    final maxDy = screenSize.height - _kPreviewHeight - _kPreviewTopOffset - 100;

    return Offset(
      raw.dx.clamp(-50.0, maxDx > 0 ? maxDx : 50.0),
      raw.dy.clamp(-40.0, maxDy > 0 ? maxDy : 200.0),
    );
  }

  String _obfuscateChannel(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  // ── DRAG HANDLERS ────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    if (_isDisposed) return;

    HapticFeedback.selectionClick();
    debugPrint('[LocalVideoPreview] 🖱️ Drag started');

    if (mounted) {
      setState(() => _isDragging = true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDisposed || !mounted) return;

    setState(() {
      _offset = _clampOffset(
        _offset + details.delta,
        MediaQuery.of(context).size,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDisposed || !mounted) return;

    debugPrint('[LocalVideoPreview] ✓ Drag ended at offset=$_offset');
    setState(() => _isDragging = false);
  }

  // ── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = _engine;
    final isValidChannel = _LocalVideoValidators.isValidChannel(widget.channel);

    // Affiche la vidéo seulement si :
    //   1. Caméra ON
    //   2. Engine Agora disponible
    //   3. Channel name valide
    final showVideo = !widget.videoOff && engine != null && isValidChannel;

    return Positioned(
      top: _kPreviewTopOffset + _offset.dy,
      right: _kPreviewRightOffset - _offset.dx,
      child: Semantics(
        label: l10n.t('call_local_preview_label'),
        button: true,
        enabled: true,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: AnimatedScale(
            scale: _isDragging ? _kDragScaleFactor : 1.0,
            duration: const Duration(milliseconds: _kDragAnimationDurationMs),
            child: _buildContainer(showVideo, engine, l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildContainer(bool showVideo, RtcEngine? engine, AppLocalizations l10n) {
    return Container(
      width: _kPreviewWidth,
      height: _kPreviewHeight,
      decoration: BoxDecoration(
        color: ThixPolicy.primaryDeep,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(
          color: _isDragging ? ThixPolicy.gold : Colors.white24,
          width: _isDragging ? _kBorderWidthDragging : _kBorderWidthNormal,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDragging ? 0.55 : 0.35),
            blurRadius: _isDragging ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kInnerBorderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoLayer(showVideo, engine),
            _buildYouLabel(l10n),
            if (_isDragging) _buildDragIndicator(),
          ],
        ),
      ),
    );
  }

  /// Couche vidéo : flux Agora ou fallback (cam off / loading).
  Widget _buildVideoLayer(bool showVideo, RtcEngine? engine) {
    if (showVideo) {
      return RepaintBoundary(
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: engine!,
            canvas: VideoCanvas(
              uid: 0, // 0 = convention SDK pour la vue locale
              renderMode: RenderModeType.renderModeHidden,
              mirrorMode: widget.isFrontCamera
                  ? VideoMirrorModeType.videoMirrorModeEnabled
                  : VideoMirrorModeType.videoMirrorModeDisabled,
            ),
          ),
        ),
      );
    }

    // Fallback : caméra OFF ou moteur non-initialisé
    return Container(
      color: ThixPolicy.primaryDeep.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              engine == null
                  ? Icons.hourglass_empty_rounded
                  : Icons.videocam_off_rounded,
              color: Colors.white38,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              engine == null
                  ? AppLocalizations.of(context).t('call_status_connecting')
                  : AppLocalizations.of(context).t('call_camera_off'),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Badge "Vous" en bas à gauche.
  Widget _buildYouLabel(AppLocalizations l10n) {
    return Positioned(
      left: 6,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kLabelPaddingH,
          vertical: _kLabelPaddingV,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.60),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_rounded, size: 9, color: Colors.white70),
            const SizedBox(width: 3),
            Text(
              l10n.t('call_you_label'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Indicateur de drag (icône move en haut à droite).
  Widget _buildDragIndicator() {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(_kDragIndicatorPadding),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.open_with_rounded,
          size: 10,
          color: Colors.white70,
        ),
      ),
    );
  }
}
