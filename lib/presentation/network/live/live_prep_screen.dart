// lib/presentation/network/live/live_prep_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/live_service.dart';
import 'live_broadcast_screen.dart';

class LivePrepScreen extends ConsumerStatefulWidget {
  const LivePrepScreen({super.key});

  @override
  ConsumerState<LivePrepScreen> createState() => _LivePrepScreenState();
}

class _LivePrepScreenState extends ConsumerState<LivePrepScreen> {
  final TextEditingController _titleController = TextEditingController();
  bool _isVideoEnabled = true;
  bool _isMicEnabled = true;

  RtcEngine? _engine;
  bool _isEngineReady = false;
  bool _isStartingLive = false;
  bool _isPreviewFailed = false;
  String? _previewErrorMessage;

  // Nom de canal temporaire dédié à la preview locale, propre à l'utilisateur.
  // Aucune vidéo n'est réellement diffusée à ce stade (pas de joinChannel).
  late final String _previewChannelName;

  @override
  void initState() {
    super.initState();
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    _previewChannelName = 'preview_$uid';
    _checkPermissionsAndInit();
  }

  Future<void> _checkPermissionsAndInit() async {
    if (kIsWeb) {
      await _initPreviewAgora();
      return;
    }

    var cameraStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;

    if (cameraStatus.isDenied || micStatus.isDenied) {
      if (!mounted) return;

      bool? userAgreed = await showDialog<bool>(
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
              Text("Autorisations", style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
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
                backgroundColor: ThixPolicy.textMain,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Compris", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (userAgreed != true) {
        if (mounted) Navigator.pop(context);
        return;
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera]!.isGranted && statuses[Permission.microphone]!.isGranted) {
        await _initPreviewAgora();
      } else {
        if (mounted) Navigator.pop(context);
      }
    } else {
      await _initPreviewAgora();
    }
  }

  /// ⚠️ CORRECTIF : plus aucun App ID codé en dur. On récupère les
  /// identifiants Agora via la même fonction Supabase que celle utilisée
  /// par live_controller.dart (`liveServiceProvider.fetchAgoraCredentials`),
  /// pour garantir un App ID toujours identique et à jour entre la preview
  /// et le direct réel. C'est cette fonction côté serveur qui reste
  /// l'unique source de vérité pour les credentials Agora.
  Future<void> _initPreviewAgora() async {
    setState(() {
      _isPreviewFailed = false;
      _previewErrorMessage = null;
    });

    try {
      final liveService = ref.read(liveServiceProvider);
      final credentials = await liveService
          .fetchAgoraCredentials(_previewChannelName)
          .timeout(const Duration(seconds: 12));

      if (credentials.appId.isEmpty) {
        throw Exception("App ID Agora manquant côté serveur.");
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: credentials.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      await _engine!.enableVideo();
      await _engine!.startPreview();

      if (mounted) setState(() => _isEngineReady = true);
    } catch (e) {
      debugPrint('Erreur init Agora (preview): $e');
      if (mounted) {
        setState(() {
          _isPreviewFailed = true;
          _previewErrorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur caméra : ${_previewErrorMessage ?? e}'),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    }
  }

  Future<void> _startLive() async {
    if (_isStartingLive) return;
    HapticFeedback.heavyImpact();

    final title = _titleController.text.trim().isEmpty ? "Mon Direct" : _titleController.text.trim();
    setState(() => _isStartingLive = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Vous devez être connecté");

      final channelName = 'live_${user.id}_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Insertion en base de données
      final response = await Supabase.instance.client
          .from('live_sessions')
          .insert({'host_id': user.id, 'title': title, 'channel_name': channelName, 'status': 'live'})
          .select()
          .single();

      // 2. CRÉATION DE L'OBJET LIVESESSION MANUELLEMENT
      final liveSession = LiveSession(
        id: response['id'].toString(),
        channelName: channelName,
        title: title,
        hostId: user.id,
        hostName: "Moi",
      );

      // ✅ On libère totalement le moteur de preview — live_controller.dart
      // va créer SON PROPRE moteur avec des credentials fraîchement générés
      // pour le canal réel (channelName), via le même service Supabase.
      if (_isEngineReady && _engine != null) {
        await _engine!.stopPreview();
        await _engine!.release();
        _engine = null;
      }

      if (!mounted) return;

      // 3. ENVOI DE L'OBJET SESSION À L'ÉCRAN SUIVANT
      Navigator.pushReplacement(
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
      debugPrint('Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingLive = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    if (_isEngineReady && _engine != null) _engine!.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Toujours noir pour l'arrière-plan vidéo
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ─── 1. VUE CAMÉRA ───
          Positioned.fill(
            child: _isEngineReady && _isVideoEnabled && _engine != null
                ? AgoraVideoView(controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0)))
                : Container(
                    color: ThixPolicy.inkDeep,
                    child: Center(
                      child: _isPreviewFailed
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    _previewErrorMessage ?? "Impossible d'initialiser la caméra.",
                                    textAlign: TextAlign.center,
                                    style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ThixPolicy.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                                    ),
                                    onPressed: _initPreviewAgora,
                                    child: Text('Réessayer', style: ThixPolicy.buttonText),
                                  ),
                                ],
                              ),
                            )
                          : const Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 80),
                    ),
                  ),
          ),

          // ─── 2. GRADIENTS DE LISIBILITÉ ───
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.9)
                  ],
                  stops: const [0.0, 0.2, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ─── 3. BOUTON FERMER (Haut Droite) ───
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),

          // ─── 4. CONTRÔLES (Bas de l'écran) ───
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titre du live
                    TextField(
                      controller: _titleController,
                      style: ThixPolicy.h1Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, fontSize: 32, letterSpacing: -0.5),
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: "Ajoutez un titre...",
                        hintStyle: ThixPolicy.h1Style.copyWith(color: Colors.white.withOpacity(0.4), fontSize: 32, letterSpacing: -0.5),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Boutons Micro / Caméra / Rotation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGlassBtn(
                          icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                          isActive: _isMicEnabled,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isMicEnabled = !_isMicEnabled);
                            if (_isEngineReady && _engine != null) _engine!.muteLocalAudioStream(!_isMicEnabled);
                          },
                        ),
                        const SizedBox(width: 24),
                        _buildGlassBtn(
                          icon: _isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          isActive: _isVideoEnabled,
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
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (_isEngineReady && _engine != null) _engine!.switchCamera();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Bouton GO LIVE
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isStartingLive ? null : _startLive,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isStartingLive ? ThixPolicy.surfaceStrong : ThixPolicy.danger,
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBtn({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
