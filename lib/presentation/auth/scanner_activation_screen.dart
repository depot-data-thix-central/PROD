// lib/presentation/auth/scanner_activation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Adapte cet import selon le chemin exact de ton design system
import 'package:thix_id/core/theme/thix_design_policy.dart'; 

class ScannerActivationScreen extends StatefulWidget {
  const ScannerActivationScreen({super.key});

  @override
  State<ScannerActivationScreen> createState() => _ScannerActivationScreenState();
}

class _ScannerActivationScreenState extends State<ScannerActivationScreen> with WidgetsBindingObserver {
  bool _isProcessing = false;
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
    // 🌟 CORRECTION 1 : Remplacement de "background" par "paused" (Nouvelle API Flutter)
    if (!_cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController.start();
    }
  }

  Future<void> _processToken(String token) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Vibration pour confirmer la détection visuelle au parrain
      HapticFeedback.heavyImpact();

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('Vous devez être connecté pour parrainer un membre.');
      }
      
      // Appel de la fonction sécurisée Supabase pour valider le nouveau compte
      await Supabase.instance.client.rpc(
        'peer_activate_account',
        params: {
          'p_token': token,
          'p_scanner_id': currentUserId,
        },
      );

      if (mounted) {
        // Double vibration pour le succès
        HapticFeedback.vibrate();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Compte du filleul activé avec succès !')),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Retour à l'accueil
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate(); // Alerte d'erreur
        
        // Nettoyage de l'erreur Supabase pour l'interface
        String errorMsg = e.toString();
        if (errorMsg.contains('Limite de parrainage')) {
          errorMsg = 'Vous avez atteint votre limite de parrainages ce mois-ci.';
        } else if (errorMsg.contains('Code invalide')) {
          errorMsg = 'Ce code QR est invalide ou a expiré.';
        } else if (errorMsg.contains('compte actif')) {
          errorMsg = 'Seuls les comptes vérifiés peuvent parrainer.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg), 
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        setState(() => _isProcessing = false);
        // On relance la caméra après une erreur
        _cameraController.start(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Scanner un Parrainage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            // 🌟 CORRECTION 2 : On écoute le contrôleur entier (Nouvelle API mobile_scanner)
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                // 🌟 CORRECTION 3 : Switch sécurisé avec un "default" pour éviter le retour null
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off_rounded, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded, color: Colors.amber);
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
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                // On s'assure de ne capturer que les codes générés par THIX
                if (rawValue != null && rawValue.startsWith('thix_activation_')) {
                  _cameraController.stop(); // Met en pause pendant le traitement réseau
                  _processToken(rawValue);
                  break;
                }
              }
            },
          ),
          
          // Filtre assombri autour du cadre de scan
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 260,
                    width: 260,
                    decoration: BoxDecoration(
                      color: Colors.red, // Cette couleur est ignorée par le ColorFilter mais crée la transparence
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Décoration visuelle du cadre (Coins blancs)
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
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
                  'Pointez l\'appareil vers le QR Code\ndu nouveau membre',
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
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: ThixPolicy.primary),
                    SizedBox(height: 20),
                    Text(
                      'Validation de l\'identité...', 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sécurisation de la connexion en cours', 
                      style: TextStyle(color: Colors.white70, fontSize: 13)
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Design des coins du scanner
  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight) ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight) ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft) ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight) ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
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
