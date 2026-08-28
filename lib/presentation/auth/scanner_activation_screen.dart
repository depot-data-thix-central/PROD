// lib/presentation/auth/scanner_activation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class ScannerActivationScreen extends StatefulWidget {
  const ScannerActivationScreen({super.key});

  @override
  State<ScannerActivationScreen> createState() => _ScannerActivationScreenState();
}

class _ScannerActivationScreenState extends State<ScannerActivationScreen>
    with WidgetsBindingObserver {
  bool _isProcessing = false;
  DateTime? _lastAttemptAt;

  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController.stop();
    } else if (state == AppLifecycleState.resumed && !_isProcessing) {
      _cameraController.start();
    }
  }

  /// Accepte le nonce hex 64 chars, éventuellement préfixé (anciens QR).
  String? _extractToken(String raw) {
    final value = raw.trim();
    const prefix = 'thix_activation_';
    final body = value.startsWith(prefix) ? value.substring(prefix.length) : value;
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(body)) return body.toLowerCase();
    return null;
  }

  String _userFacingError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not_authenticated')) return 'Connectez-vous pour parrainer.';
    if (msg.contains('not_accredited')) return 'Votre compte n’est pas accrédité pour parrainer.';
    if (msg.contains('token_expired')) return 'Ce QR a expiré (15 min). Demandez-en un nouveau.';
    if (msg.contains('token_used')) return 'Ce QR a déjà été utilisé.';
    if (msg.contains('cannot_sponsor_self')) return 'Vous ne pouvez pas parrainer votre propre compte.';
    if (msg.contains('invalid_token')) return 'QR invalide.';
    if (msg.contains('rate') || msg.contains('limite')) {
      return 'Limite de parrainages atteinte.';
    }
    return 'Impossible de valider ce parrainage. Réessayez.';
  }

  Future<void> _processToken(String raw) async {
    if (_isProcessing) return;
    final now = DateTime.now();
    if (_lastAttemptAt != null && now.difference(_lastAttemptAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastAttemptAt = now;

    final token = _extractToken(raw);
    if (token == null) return;

    setState(() => _isProcessing = true);
    await _cameraController.stop();

    try {
      HapticFeedback.heavyImpact();

      if (Supabase.instance.client.auth.currentUser?.id == null) {
        throw Exception('not_authenticated');
      }

      await Supabase.instance.client.rpc(
        'consume_qr_activation_token',
        params: {'p_token': token},
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Parrainage enregistré. Le membre peut maintenant activer son THIX ID.'),
              ),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_userFacingError(e)),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isProcessing = false);
      await _cameraController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Scanner un parrainage',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _cameraController,
              builder: (context, state, _) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded, color: Colors.amber);
                  case TorchState.off:
                    return const Icon(Icons.flash_off_rounded, color: Colors.white);
                  default:
                    return const Icon(Icons.flash_off_rounded, color: Colors.grey);
                }
              },
            ),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw == null) continue;
                if (_extractToken(raw) != null) {
                  _processToken(raw);
                  break;
                }
              }
            },
          ),
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 260,
                    width: 260,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: Colors.white70, size: 40),
                SizedBox(height: 12),
                Text(
                  'Pointez vers le QR du nouveau membre\n(email déjà vérifié)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: ThixPolicy.primary),
                    SizedBox(height: 20),
                    Text(
                      'Enregistrement du parrainage…',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Le compte ne sera activé que par le membre',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight)
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft)
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: alignment == Alignment.topLeft ? const Radius.circular(20) : Radius.zero,
            topRight: alignment == Alignment.topRight ? const Radius.circular(20) : Radius.zero,
            bottomLeft: alignment == Alignment.bottomLeft ? const Radius.circular(20) : Radius.zero,
            bottomRight: alignment == Alignment.bottomRight ? const Radius.circular(20) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
