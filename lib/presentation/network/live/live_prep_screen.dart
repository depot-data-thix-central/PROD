// lib/presentation/network/live/live_prep_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/live_service.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'live_broadcast_screen.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kAgoraTimeout = Duration(seconds: 12);
const Duration _kDbTimeout = Duration(seconds: 10);
const int _kMaxTitleLength = 100;
const int _kMinTitleLength = 3;

class _LivePrepValidators {
  _LivePrepValidators._();

  static String sanitize(String? input, {int maxLength = _kMaxTitleLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? validateTitle(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return null; // Titre optionnel → "Mon Direct" par défaut
    if (clean.length < _kMinTitleLength) return 'Titre trop court (min $_kMinTitleLength caractères)';
    if (clean.length > _kMaxTitleLength) return 'Titre trop long (max $_kMaxTitleLength caractères)';
    if (!RegExp(r'^[\p{L}\p{N}\s\p{P}\p{S}]+$', unicode: true).hasMatch(clean)) {
      return 'Le titre contient des caractères invalides';
    }
    return null;
  }

  static String parseErrorMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission')) return 'Permissions insuffisantes.';
    if (msg.contains('unauthorized')) return 'Session expirée. Reconnectez-vous.';
    return e.toString().replaceFirst('Exception: ', '').split('\n').first;
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class LivePrepScreen extends ConsumerStatefulWidget {
  const LivePrepScreen({super.key});

  @override
  ConsumerState<LivePrepScreen> createState() => _LivePrepScreenState();
}

class _LivePrepScreenState extends ConsumerState<LivePrepScreen> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  bool _isVideoEnabled = true;
  bool _isMicEnabled = true;

  RtcEngine? _engine;
  bool _isEngineReady = false;
  bool _isInitializing = true;
  bool _isStartingLive = false;
  bool _isPreviewFailed = false;
  String? _previewErrorMessage;
  String? _hostName;
  String? _createdSessionId; // Pour rollback

  late final String _previewChannelName;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    _previewChannelName = 'preview_$uid';
    debugPrint('[LivePrep] 🎬 Initializing for uid=$uid');
    _loadHostProfile();
    _checkPermissionsAndInit();
  }

  void _onTitleChanged() {
    if (_titleController.text.length > _kMaxTitleLength) {
      _titleController.text = _titleController.text.substring(0, _kMaxTitleLength);
      _titleController.selection = TextSelection.collapsed(offset: _kMaxTitleLength);
      HapticFeedback.lightImpact();
    }
    setState(() {}); // Refresh compteur
  }

  Future<void> _loadHostProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('display_name, certification_tier, certification_status')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (profile != null && mounted) {
        setState(() {
          _hostName = (profile['display_name']?.toString().trim().isNotEmpty ?? false)
              ? profile['display_name']
              : 'Moi';
        });
      }
    } catch (e) {
      debugPrint('[LivePrep] ⚠️ Load host profile error: $e');
      if (mounted) setState(() => _hostName = 'Moi');
    }
  }

  // ─── PERMISSIONS ───
  Future<void> _checkPermissionsAndInit() async {
    if (kIsWeb) {
      await _initPreviewAgora();
      return;
    }

    final camStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    // Permissions déjà accordées
    if (camStatus.isGranted && micStatus.isGranted) {
      await _initPreviewAgora();
      return;
    }

    // Permissions précédemment refusées définitivement
    if (camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      if (!mounted) return;
      final open = await _showPermanentlyDeniedDialog();
      if (open == true) {
        await openAppSettings();
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    // Première demande : dialog disclosure
    if (!mounted) return;
    final userAgreed = await _showPermissionDisclosureDialog();
    if (userAgreed != true) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final statuses = await [Permission.camera, Permission.microphone].request();
    final camOk = statuses[Permission.camera]?.isGranted ?? false;
    final micOk = statuses[Permission.microphone]?.isGranted ?? false;

    if (camOk && micOk) {
      await _initPreviewAgora();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permissions refusées. Impossible de lancer le direct.'),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<bool?> _showPermissionDisclosureDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        surfaceTintColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: ThixPolicy.textMain, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text("Autorisations", style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            ),
          ],
        ),
        content: Text(
          "Pour démarrer votre direct, THIX ID a besoin d'accéder à votre caméra et votre microphone. "
          "Ces accès ne sont utilisés que pendant la diffusion.",
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Annuler", style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Compris"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPermanentlyDeniedDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.settings_outlined, color: ThixPolicy.warning, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text("Permissions requises", style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
          ],
        ),
        content: Text(
          "Vous avez précédemment refusé les permissions caméra/micro. Activez-les dans les paramètres de l'application.",
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            child: const Text("Paramètres"),
          ),
        ],
      ),
    );
  }

  // ─── INIT AGORA ───
  Future<void> _initPreviewAgora() async {
    setState(() {
      _isInitializing = true;
      _isPreviewFailed = false;
      _previewErrorMessage = null;
    });

    try {
      debugPrint('[LivePrep] 🎥 Fetching Agora credentials...');
      final liveService = ref.read(liveServiceProvider);
      final credentials = await liveService
          .fetchAgoraCredentials(_previewChannelName)
          .timeout(_kAgoraTimeout);

      if (credentials.appId.isEmpty) {
        throw Exception("App ID Agora manquant côté serveur.");
      }

      debugPrint('[LivePrep] ✓ Credentials received (appId=${credentials.appId.substring(0, 8)}...)');

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: credentials.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 15,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainQuality,
        ),
      );

      await _engine!.enableVideo();
      await _engine!.startPreview();

      if (!mounted) {
        await _cleanupEngine();
        return;
      }

      setState(() {
        _isEngineReady = true;
        _isInitializing = false;
      });

      debugPrint('[LivePrep] ✓ Preview engine ready');
    } catch (e) {
      debugPrint('[LivePrep] ❌ Agora init error: $e');
      await _cleanupEngine();
      if (mounted) {
        setState(() {
          _isPreviewFailed = true;
          _isInitializing = false;
          _previewErrorMessage = _LivePrepValidators.parseErrorMessage(e);
        });
      }
    }
  }

  Future<void> _cleanupEngine() async {
    try {
      if (_engine != null) {
        try {
          await _engine!.stopPreview();
        } catch (_) {}
        try {
          await _engine!.release();
        } catch (_) {}
        _engine = null;
      }
    } catch (e) {
      debugPrint('[LivePrep] Cleanup engine error: $e');
    }
    _isEngineReady = false;
  }

  // ─── START LIVE ───
  Future<void> _startLive() async {
    if (_isStartingLive || _isInitializing) return;

    final rawTitle = _titleController.text.trim();
    final titleError = _LivePrepValidators.validateTitle(rawTitle);
    if (titleError != null) {
      _showError(titleError);
      _titleFocus.requestFocus();
      return;
    }

    final title = rawTitle.isEmpty ? "Mon Direct" : _LivePrepValidators.sanitize(rawTitle);
    final hostName = _hostName ?? 'Moi';

    HapticFeedback.heavyImpact();
    setState(() => _isStartingLive = true);
    debugPrint('[LivePrep] 🚀 Starting live: "$title"');

    String? sessionId;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Vous devez être connecté");

      final channelName = 'live_${user.id}_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Insertion DB
      final response = await Supabase.instance.client
          .from('live_sessions')
          .insert({
            'host_id': user.id,
            'title': title,
            'channel_name': channelName,
            'status': 'live',
            'started_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single()
          .timeout(_kDbTimeout);

      sessionId = response['id'].toString();
      _createdSessionId = sessionId;
      debugPrint('[LivePrep] ✓ Session created: $sessionId');

      // 2. Construction LiveSession avec données enrichies
      final liveSession = LiveSession(
        id: sessionId,
        channelName: channelName,
        title: title,
        hostId: user.id,
        hostName: hostName,
        hostAvatarUrl: ref.read(authControllerProvider).valueOrNull?.avatarUrl ?? 
               ref.read(authControllerProvider).valueOrNull?.photoUrl,
certificationTier: ref.read(authControllerProvider).valueOrNull?.certificationTier?.toString(),
certificationStatus: ref.read(authControllerProvider).valueOrNull?.certificationStatus?.toString(),
      );

      // 3. Libérer le moteur de preview
      await _cleanupEngine();

      if (!mounted) {
        await _rollbackSession(sessionId);
        return;
      }

      // 4. Navigation vers broadcast screen
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LiveBroadcastScreen(
            session: liveSession,
            isVideoEnabled: _isVideoEnabled,
            isMicEnabled: _isMicEnabled,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[LivePrep] ❌ Start live error: $e');

      // Rollback session si créée mais navigation échouée
      if (sessionId != null) {
        await _rollbackSession(sessionId);
      }

      if (mounted) {
        _showError(_LivePrepValidators.parseErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isStartingLive = false);
    }
  }

  Future<void> _rollbackSession(String sessionId) async {
    try {
      await Supabase.instance.client
          .from('live_sessions')
          .update({'status': 'cancelled'})
          .eq('id', sessionId)
          .timeout(_kDbTimeout);
      debugPrint('[LivePrep] 🔄 Session rolled back: $sessionId');
    } catch (e) {
      debugPrint('[LivePrep] ⚠️ Rollback error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      ),
    );
    HapticFeedback.heavyImpact();
  }

  Future<void> _confirmClose() async {
    final hasContent = _titleController.text.trim().isNotEmpty;

    if (!hasContent && !_isEngineReady) {
      HapticFeedback.selectionClick();
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ThixPolicy.warning, size: 24),
            const SizedBox(width: 8),
            Text('Annuler le direct ?', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment quitter la préparation du direct ?',
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Rester', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.selectionClick();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    _cleanupEngine();
    debugPrint('[LivePrep] 🎬 Disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleLength = _titleController.text.length;
    final showCounter = titleLength > _kMaxTitleLength * 0.8;
    final titleError = _LivePrepValidators.validateTitle(_titleController.text);
    final canStart = !_isStartingLive && !_isInitializing && titleError == null;

    return PopScope(
      canPop: !_isStartingLive && !_isInitializing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isStartingLive || _isInitializing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opération en cours...')),
          );
          return;
        }
        await _confirmClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            _buildCameraPreview(),
            _buildGradients(),
            _buildCloseButton(),
            _buildControls(canStart, titleLength, showCounter),
            if (_isInitializing || _isStartingLive) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Positioned.fill(
      child: _isEngineReady && _isVideoEnabled && _engine != null
          ? Semantics(
              label: 'Aperçu caméra',
              child: SizedBox.expand(
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(
                      uid: 0,
                      renderMode: RenderModeType.renderModeHidden,
                    ),
                    useFlutterTexture: kIsWeb,
                  ),
                ),
              ),
            )
          : Container(
              color: ThixPolicy.inkDeep,
              child: Center(
                child: _isPreviewFailed
                    ? _buildErrorState()
                    : const Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 80),
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            _previewErrorMessage ?? "Impossible d'initialiser la caméra.",
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
            onPressed: _initPreviewAgora,
          ),
        ],
      ),
    );
  }

  Widget _buildGradients() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.9),
              ],
              stops: const [0.0, 0.2, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 16,
      right: 16,
      child: Semantics(
        button: true,
        label: 'Fermer',
        child: GestureDetector(
          onTap: _confirmClose,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThixPolicy.rFull),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(bool canStart, int titleLength, bool showCounter) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titre
              TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                enabled: !_isStartingLive,
                style: ThixPolicy.h1Style.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 32,
                  letterSpacing: -0.5,
                ),
                maxLines: null,
                maxLength: _kMaxTitleLength,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: "Ajoutez un titre...",
                  hintStyle: ThixPolicy.h1Style.copyWith(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 32,
                    letterSpacing: -0.5,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                ),
              ),
              // Compteur + erreur
              if (showCounter || titleLength > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (titleLength > 0 && titleLength < _kMinTitleLength)
                        Text(
                          'Minimum $_kMinTitleLength caractères',
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.warning),
                        )
                      else
                        const SizedBox.shrink(),
                      Text(
                        '$titleLength/$_kMaxTitleLength',
                        style: ThixPolicy.captionStyle.copyWith(
                          color: titleLength >= _kMaxTitleLength ? ThixPolicy.danger : Colors.white70,
                          fontWeight: ThixPolicy.semiBold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Contrôles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGlassBtn(
                    icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                    isActive: _isMicEnabled,
                    tooltip: _isMicEnabled ? 'Micro activé' : 'Micro coupé',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isMicEnabled = !_isMicEnabled);
                      if (_isEngineReady && _engine != null) {
                        _engine!.muteLocalAudioStream(!_isMicEnabled);
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildGlassBtn(
                    icon: _isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    isActive: _isVideoEnabled,
                    tooltip: _isVideoEnabled ? 'Vidéo activée' : 'Vidéo coupée',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isVideoEnabled = !_isVideoEnabled);
                      if (_isEngineReady && _engine != null) {
                        if (_isVideoEnabled) {
                          _engine!.enableVideo();
                          _engine!.startPreview();
                        } else {
                          _engine!.disableVideo();
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildGlassBtn(
                    icon: Icons.flip_camera_ios_rounded,
                    isActive: true,
                    tooltip: 'Changer de caméra',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (_isEngineReady && _engine != null) _engine!.switchCamera();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Bouton GO LIVE
              Semantics(
                button: true,
                label: 'Lancer le direct',
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canStart ? _startLive : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canStart ? ThixPolicy.danger : ThixPolicy.surfaceStrong,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                    ),
                    child: _isStartingLive
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sensors_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text('LANCER LE DIRECT', style: ThixPolicy.buttonText.copyWith(letterSpacing: 0.5)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              boxShadow: ThixPolicy.shadowCard(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: ThixPolicy.primary),
                const SizedBox(height: 16),
                Text(
                  _isStartingLive ? 'Lancement du direct...' : 'Initialisation caméra...',
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBtn({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Semantics(
      button: true,
      label: tooltip ?? '',
      child: Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: (_isStartingLive || _isInitializing) ? null : onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThixPolicy.rFull),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.15) : ThixPolicy.danger.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
