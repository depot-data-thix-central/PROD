// lib/services/biometric_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service de biométrie pour déverrouillage des conversations 🔒
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  bool? _isAvailable;

  /// Vérifie si la biométrie est disponible sur l'appareil
  Future<bool> isAvailable() async {
    if (_isAvailable != null) return _isAvailable!;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      _isAvailable = canCheck && isDeviceSupported;
      return _isAvailable!;
    } catch (e) {
      debugPrint('[Biometric] isAvailable error: $e');
      _isAvailable = false;
      return false;
    }
  }

  /// Authentifie l'utilisateur via biométrie (empreinte / Face ID)
  /// Retourne true si succès, false si annulé ou échec.
  Future<bool> authenticate({
    String reason = 'Authentifiez-vous pour accéder à cette conversation',
  }) async {
    if (!await isAvailable()) {
      debugPrint('[Biometric] ⚠️ Biométrie non disponible');
      return false;
    }

    try {
      // ✅ API local_auth >= 2.x (sans paramètre options)
      final result = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        useErrorDialogs: true,
        stickyAuth: true,
      );
      debugPrint('[Biometric] ${result ? "✓ Success" : "✗ Cancelled/Failed"}');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[Biometric] PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Biometric] Error: $e');
      return false;
    }
  }

  /// Liste des types biométriques disponibles (info UI)
  Future<List<BiometricType>> getAvailableTypes() async {
    try {
      if (!await isAvailable()) return [];
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[Biometric] getAvailableTypes error: $e');
      return [];
    }
  }
}
