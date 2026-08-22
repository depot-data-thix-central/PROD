// lib/presentation/thix_media/camera_capture_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/permission_helper.dart';
import 'video_preview_editor_page.dart';

class _CamColors {
  static const navyDeep = Color(0xFF0A1F44);
  static const primary = Color(0xFF2D6CDF);
  static const danger = Color(0xFFE0453C);
}

const int kMaxRecordSeconds = 600; // 10 minutes

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _isReady = false;
  bool _isRecording = false;
  bool _flashOn = false;
  bool _beautyOn = true;
  double _beautyIntensity = 0.5; // 0.0 à 1.0

  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Étape 1 : demande de permission AVEC explication préalable
    // (obligatoire — voir permission_helper.dart)
    final camGranted = await PermissionHelper.requestWithRationale(
      context: context,
      permission: Permission.camera,
      title: 'Accès à la caméra',
      message:
          "THIX ID utilise votre caméra pour enregistrer les vidéos que vous choisissez de publier. Rien n'est enregistré ni envoyé sans votre action explicite.",
      icon: Icons.camera_alt_rounded,
    );
    if (!camGranted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final micGranted = await PermissionHelper.requestWithRationale(
      context: context,
      permission: Permission.microphone,
      title: 'Accès au microphone',
      message:
          "THIX ID utilise le microphone pour capter le son de vos vidéos. Vous pourrez le couper ou le remplacer par une musique avant publication.",
      icon: Icons.mic_rounded,
    );
    if (!micGranted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    await _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    // Préfère la caméra frontale par défaut (usage type "selfie/beauté")
    _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (_cameraIndex == -1) _cameraIndex = 0;

    await _startController(_cameras[_cameraIndex]);
  }

  Future<void> _startController(CameraDescription description) async {
    final previous = _controller;
    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await previous?.dispose();
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      debugPrint('Erreur init caméra: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _isReady = false);
    await _startController(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    _flashOn = !_flashOn;
    await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _elapsedSeconds = 0;
      });
      HapticFeedback.mediumImpact();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _elapsedSeconds++);
        // Limite stricte à 10 minutes, arrêt automatique
        if (_elapsedSeconds >= kMaxRecordSeconds) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Erreur démarrage enregistrement: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;
    _timer?.cancel();
    try {
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      HapticFeedback.heavyImpact();
      if (!mounted) return;

      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPreviewEditorPage(videoPath: file.path),
        ),
      );

      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      setState(() => _isRecording = false);
      debugPrint('Erreur arrêt enregistrement: $e');
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startController(_cameras[_cameraIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isReady || _controller == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              fit: StackFit.expand,
              children: [
                // ── Flux caméra + filtre beauté simulé (blur + éclat) ──
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1,
                        height: _controller!.value.previewSize?.width ?? 1,
                        child: _beautyOn
                            ? _buildBeautyOverlay(CameraPreview(_controller!))
                            : CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),

                // ── Barre du haut ──
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        if (_isRecording)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: _CamColors.danger, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(_formatDuration(_elapsedSeconds),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 4),
                                const Text('/ 10:00', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            _circleButton(
                              icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              onTap: _toggleFlash,
                            ),
                            const SizedBox(width: 10),
                            _circleButton(
                              icon: Icons.cameraswitch_rounded,
                              onTap: _switchCamera,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Barre progression 10 min ──
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _elapsedSeconds / kMaxRecordSeconds,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      color: _elapsedSeconds > kMaxRecordSeconds * 0.85 ? _CamColors.danger : _CamColors.primary,
                    ),
                  ),
                ),

                // ── Contrôles bas ──
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Toggle beauté + intensité
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: _beautyOn ? _CamColors.primary : Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            const Text('Beauté', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: _beautyIntensity,
                                onChanged: _beautyOn
                                    ? (v) => setState(() => _beautyIntensity = v)
                                    : null,
                                activeColor: _CamColors.primary,
                                inactiveColor: Colors.white24,
                              ),
                            ),
                            Switch(
                              value: _beautyOn,
                              activeColor: _CamColors.primary,
                              onChanged: (v) => setState(() => _beautyOn = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Bouton enregistrer (tap pour démarrer/arrêter)
                      GestureDetector(
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _CamColors.danger,
                              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: _isRecording ? BorderRadius.circular(8) : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Filtre "beauté" simulé : léger flou + luminosité/saturation augmentées.
  /// ⚠️ Ce n'est PAS un lissage de peau par IA (pas de détection de
  /// visage). Pour un vrai effet type TikTok, il faut brancher un SDK
  /// AR (Banuba, Deep AR, ou google_mlkit_face_mesh_detection + un
  /// shader custom appliqué uniquement sur la zone du visage).
  Widget _buildBeautyOverlay(Widget child) {
    final sigma = 1.2 * _beautyIntensity;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Opacity(
            opacity: 0.35 * _beautyIntensity,
            child: child,
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.06 * _beautyIntensity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
