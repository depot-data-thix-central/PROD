import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/permission_helper.dart';
import 'video_preview_editor_page.dart';

// ============================================================================
// PALETTE — Charte Premium THIX / TDIA
// ============================================================================
class _CamColors {
  _CamColors._();
  
  static const navyDeep = Color(0xFF0A1F44);
  static const primary = Color(0xFF2D6CDF);
  static const danger = Color(0xFFE0453C);
  static const success = Color(0xFF10B981);
  static const textMuted = Color(0xFFAEB9D4);
}

// ============================================================================
// CONSTANTES PRODUCTION
// ============================================================================
class _CameraLimits {
  _CameraLimits._();
  
  static const int maxRecordSeconds = 600; // 10 minutes
  static const int warningThresholdPercent = 85; // Avertissement à 85%
  static const Duration initTimeout = Duration(seconds: 15);
  static const Duration camerasListTimeout = Duration(seconds: 10);
  
  /// Résolution adaptative selon les capacités
  static ResolutionPreset get defaultResolution => 
      kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high;
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
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
  bool _disposed = false; // ✅ Protection async post-dispose
  bool _hasError = false;
  String _errorMessage = '';
  
  double _beautyIntensity = 0.5;

  Timer? _recordingTimer;
  int _elapsedSeconds = 0;

  // ============================================================================
  // LIFECYCLE
  // ============================================================================
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _controller == null || !_controller!.value.isInitialized) return;
    
    if (state == AppLifecycleState.inactive) {
      _handleAppInactive();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  /// ✅ Arrête l'enregistrement et dispose la caméra si app inactive
  Future<void> _handleAppInactive() async {
    if (_isRecording) {
      try {
        await _controller?.stopVideoRecording();
      } catch (e) {
        debugPrint('[Camera] Error stopping recording on inactive: $e');
      }
      _recordingTimer?.cancel();
      if (!_disposed) {
        setState(() => _isRecording = false);
      }
    }
    try {
      await _controller?.dispose();
    } catch (e) {
      debugPrint('[Camera] Error disposing on inactive: $e');
    }
  }

  /// ✅ Ré-initialise la caméra au retour
  Future<void> _handleAppResumed() async {
    if (_disposed || _cameras.isEmpty) return;
    try {
      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      debugPrint('[Camera] Error resuming: $e');
    }
  }

  // ============================================================================
  // BOOTSTRAP (Permissions + Init)
  // ============================================================================
  
  Future<void> _bootstrap() async {
    try {
      // 1. Permission caméra
      final camGranted = await PermissionHelper.requestWithRationale(
        context: context,
        permission: Permission.camera,
        title: 'Accès à la caméra',
        message:
            "THIX ID utilise votre caméra pour enregistrer les vidéos que vous choisissez de publier. Rien n'est enregistré ni envoyé sans votre action explicite.",
        icon: Icons.camera_alt_rounded,
      );
      if (_disposed || !mounted) return;
      if (!camGranted) {
        Navigator.pop(context);
        return;
      }

      // 2. Permission microphone
      final micGranted = await PermissionHelper.requestWithRationale(
        context: context,
        permission: Permission.microphone,
        title: 'Accès au microphone',
        message:
            "THIX ID utilise le microphone pour capter le son de vos vidéos. Vous pourrez le couper ou le remplacer par une musique avant publication.",
        icon: Icons.mic_rounded,
      );
      if (_disposed || !mounted) return;
      if (!micGranted) {
        Navigator.pop(context);
        return;
      }

      // 3. Init caméra avec timeout
      await _initCamera();
    } catch (e) {
      debugPrint('[Camera] Bootstrap error: $e');
      if (!_disposed && mounted) {
        _setError('Erreur d\'initialisation : $e');
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      // ✅ Timeout sur la liste des caméras
      _cameras = await availableCameras().timeout(
        _CameraLimits.camerasListTimeout,
        onTimeout: () {
          throw TimeoutException('Détection des caméras trop lente');
        },
      );

      if (_disposed) return;
      if (_cameras.isEmpty) {
        _setError('Aucune caméra disponible sur cet appareil');
        return;
      }

      // Préférence : caméra frontale par défaut (selfie/beauté)
      _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (_cameraIndex == -1) _cameraIndex = 0;

      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      debugPrint('[Camera] Init error: $e');
      if (!_disposed && mounted) {
        _setError('Impossible d\'accéder à la caméra : ${e.toString()}');
      }
    }
  }

  Future<void> _startController(CameraDescription description) async {
    if (_disposed) return;
    
    final previous = _controller;
    _controller = CameraController(
      description,
      _CameraLimits.defaultResolution,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await previous?.dispose();
      
      // ✅ Timeout sur l'initialisation du controller
      await _controller!.initialize().timeout(
        _CameraLimits.initTimeout,
        onTimeout: () {
          throw TimeoutException('Initialisation caméra trop lente');
        },
      );

      if (_disposed || !mounted) return;
      
      setState(() {
        _isReady = true;
        _hasError = false;
        _errorMessage = '';
      });
    } catch (e) {
      debugPrint('[Camera] Controller init error: $e');
      if (!_disposed && mounted) {
        _setError('Erreur d\'initialisation du flux vidéo : ${e.toString()}');
      }
    }
  }

  void _setError(String message) {
    if (_disposed || !mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isReady = false;
    });
  }

  // ============================================================================
  // ACTIONS CAMÉRA
  // ============================================================================

  Future<void> _switchCamera() async {
    if (_disposed || _cameras.length < 2 || _isRecording) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    
    if (mounted) setState(() => _isReady = false);
    await _startController(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_disposed || _controller == null || !_controller!.value.isInitialized) return;
    
    try {
      _flashOn = !_flashOn;
      await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Camera] Flash toggle error: $e');
      // Rollback
      _flashOn = !_flashOn;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flash non disponible'), backgroundColor: _CamColors.danger),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_disposed) return;
    if (_controller == null || !_controller!.value.isInitialized) {
      _showError('La caméra n\'est pas prête');
      return;
    }
    if (_isRecording) return;

    try {
      await _controller!.startVideoRecording();
      
      if (_disposed || !mounted) return;
      
      setState(() {
        _isRecording = true;
        _elapsedSeconds = 0;
      });
      
      HapticFeedback.mediumImpact();
      
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_disposed) {
          t.cancel();
          return;
        }
        if (!mounted) {
          t.cancel();
          return;
        }
        
        setState(() => _elapsedSeconds++);
        
        // ✅ Limite stricte à 10 minutes, arrêt automatique
        if (_elapsedSeconds >= _CameraLimits.maxRecordSeconds) {
          t.cancel();
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('[Camera] Start recording error: $e');
      if (!_disposed && mounted) {
        _showError('Impossible de démarrer l\'enregistrement');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_disposed) return;
    if (_controller == null || !_isRecording) return;
    
    _recordingTimer?.cancel();
    _recordingTimer = null;
    
    try {
      final file = await _controller!.stopVideoRecording();
      
      if (_disposed || !mounted) return;
      
      setState(() => _isRecording = false);
      HapticFeedback.heavyImpact();

      // ✅ Vérification que le fichier existe
      if (!File(file.path).existsSync()) {
        _showError('Erreur : fichier vidéo introuvable');
        return;
      }

      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => VideoPreviewEditorPage(videoPath: file.path)),
      );

      if (_disposed || !mounted) return;
      
      if (result != null) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      debugPrint('[Camera] Stop recording error: $e');
      if (!_disposed && mounted) {
        setState(() => _isRecording = false);
        _showError('Erreur lors de l\'arrêt de l\'enregistrement');
      }
    }
  }

  void _showError(String message) {
    if (_disposed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _CamColors.danger),
    );
  }

  /// ✅ Confirmation avant fermeture si enregistrement en cours
  Future<bool> _confirmClose() async {
    if (!_isRecording) return true;
    
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _CamColors.navyDeep,
        title: const Text(
          'Arrêter l\'enregistrement ?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Vous êtes en train d\'enregistrer. La vidéo en cours sera perdue.',
          style: TextStyle(color: _CamColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: _CamColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _CamColors.danger),
            child: const Text('Arrêter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return shouldClose ?? false;
  }

  Future<void> _handleClose() async {
    final confirmed = await _confirmClose();
    if (confirmed && mounted) {
      if (_isRecording) {
        await _stopRecording().catchError((_) {});
      }
      if (mounted) Navigator.pop(context);
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================
  
  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _hasError
            ? _buildErrorState()
            : !_isReady || _controller == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCameraPreview(),
                      _buildTopBar(),
                      _buildProgressBar(),
                      _buildBottomControls(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _CamColors.danger, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _CamColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retour', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(color: Colors.black);
    }

    return ClipRect(
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
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleButton(icon: Icons.close_rounded, onTap: _handleClose),
            if (_isRecording) _buildRecordingIndicator(),
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
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: _CamColors.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_elapsedSeconds),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          const Text(
            '/ 10:00',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _elapsedSeconds / _CameraLimits.maxRecordSeconds;
    final isNearLimit = _elapsedSeconds > _CameraLimits.maxRecordSeconds * _CameraLimits.warningThresholdPercent / 100;
    
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: Colors.white24,
          color: isNearLimit ? _CamColors.danger : _CamColors.primary,
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Column(
        children: [
          _buildBeautyPanel(),
          const SizedBox(height: 10),
          _buildRecordButton(),
        ],
      ),
    );
  }

  Widget _buildBeautyPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: _beautyOn ? _CamColors.primary : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'Beauté',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Expanded(
            child: Slider(
              value: _beautyIntensity,
              onChanged: _beautyOn ? (v) => setState(() => _beautyIntensity = v) : null,
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
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
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
    );
  }

  /// Filtre "beauté" simulé : léger flou + luminosité/saturation augmentées.
  /// ⚠️ Ce n'est PAS un lissage de peau par IA (pas de détection de visage).
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
