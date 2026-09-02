// lib/services/chat/encryption_service.dart
//
// ============================================================================
// ENCRYPTION SERVICE — Production Enterprise
// ============================================================================
//
// Service d'encryption AES-256-GCM (authenticated encryption) pour
// protéger les données sensibles au repos ou en transit.
//
// Architecture :
//   - AES-256-GCM (chiffrement + authentification en une seule passe)
//   - HKDF-SHA256 pour dériver la clé depuis le password
//   - IV aléatoire 12 bytes généré par SecureRandom
//   - Salt aléatoire 16 bytes par dérivation
//   - Format ciphertext versionné pour rotation future
//
// Format du ciphertext (version 1) :
//   [version:1] [salt:16] [iv:12] [ciphertext+tag:N]
//   → encodé en base64url pour transport
//
// Sécurité :
//   - Authenticated encryption (AES-GCM) — intégrité + confidentialité
//   - KDF HKDF-SHA256 — protection contre password faible
//   - IV unique par encryption (SecureRandom)
//   - Salt unique par dérivation (empêche rainbow tables)
//   - Validation stricte des inputs
//   - Exceptions typées pour debugging
//
// ⚠️ IMPORTANT : Ce service protège la CONFIDENTIALITÉ mais pas la
//    NON-RÉPUDIATION. Pour la signature, utiliser un service dédié
//    (Ed25519 ou ECDSA).
// ============================================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kVersionByte = 1;
const int _kSaltLength = 16;
const int _kIvLength = 12; // Standard AES-GCM
const int _kKeyLength = 32; // AES-256
const int _kMinPasswordLength = 8;
const int _kMaxPasswordLength = 256;
const int _kMaxPlaintextLength = 10 * 1024 * 1024; // 10MB
const String _kHkdfInfo = 'thix-id-encryption-v1';

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Exception levée en cas d'échec d'encryption.
class EncryptionException implements Exception {
  final String message;
  final Object? cause;
  const EncryptionException(this.message, [this.cause]);
  @override
  String toString() => 'EncryptionException: $message';
}

/// Exception levée en cas d'échec de decryption (wrong password, corrupted data).
class DecryptionException implements Exception {
  final String message;
  final Object? cause;
  const DecryptionException(this.message, [this.cause]);
  @override
  String toString() => 'DecryptionException: $message';
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _EncryptionValidators {
  _EncryptionValidators._();

  /// Valide un password (non vide, longueur raisonnable).
  static void validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      throw const EncryptionException('Password cannot be empty');
    }
    if (password.length < _kMinPasswordLength) {
      throw const EncryptionException(
        'Password too short (minimum 8 characters)',
      );
    }
    if (password.length > _kMaxPasswordLength) {
      throw const EncryptionException(
        'Password too long (maximum 256 characters)',
      );
    }
  }

  /// Valide un plaintext (non null, longueur raisonnable).
  static void validatePlaintext(String? text) {
    if (text == null) {
      throw const EncryptionException('Plaintext cannot be null');
    }
    if (text.length > _kMaxPlaintextLength) {
      throw const EncryptionException(
        'Plaintext too large (maximum 10MB)',
      );
    }
  }

  /// Valide un ciphertext base64 (non null, non vide).
  static void validateCiphertext(String? ciphertext) {
    if (ciphertext == null || ciphertext.isEmpty) {
      throw const DecryptionException('Ciphertext cannot be empty');
    }
    if (ciphertext.length < 4) {
      throw const DecryptionException('Ciphertext too short to be valid');
    }
  }
}

// ============================================================================
// ENCRYPTION SERVICE
// ============================================================================

/// Service d'encryption AES-256-GCM avec dérivation de clé HKDF.
///
/// **Usage** :
/// ```dart
/// final service = EncryptionService();
/// final encrypted = service.encrypt('Hello World', 'my-secure-password');
/// final decrypted = service.decrypt(encrypted, 'my-secure-password');
/// assert(decrypted == 'Hello World');
/// ```
///
/// **Sécurité** :
/// - Password minimum 8 caractères
/// - Salt aléatoire par dérivation (16 bytes)
/// - IV aléatoire par encryption (12 bytes)
/// - AES-256-GCM (authenticated encryption)
/// - Versioning pour rotation future
class EncryptionService {
  final Random _secureRandom;

  EncryptionService({Random? secureRandom})
      : _secureRandom = secureRandom ?? Random.secure() {
    debugPrint('[EncryptionService] 🚀 Initialized');
  }

  // ============================================================
  // KEY DERIVATION (HKDF-SHA256)
  // ============================================================

  /// Dérive une clé AES-256 depuis un password + salt via HKDF-SHA256.
  ///
  /// HKDF (RFC 5869) est conçu pour dériver des clés cryptographiques
  /// à partir de matériel à faible entropie (comme un password).
  Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);

    // Extract : HMAC-SHA256(salt, password)
    final hmacExtract = crypto.Hmac(crypto.sha256, salt);
    final prk = hmacExtract.convert(passwordBytes).bytes;

    // Expand : HMAC-SHA256(PRK, info || 0x01)
    final info = utf8.encode(_kHkdfInfo);
    final expandInput = Uint8List(info.length + 1);
    expandInput.setRange(0, info.length, info);
    expandInput[info.length] = 0x01;

    final hmacExpand = crypto.Hmac(crypto.sha256, prk);
    final output = hmacExpand.convert(expandInput).bytes;

    return Uint8List.fromList(output.sublist(0, _kKeyLength));
  }

  /// Génère des bytes aléatoires cryptographiques.
  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  // ============================================================
  // ENCRYPT
  // ============================================================

  /// Chiffre un texte avec AES-256-GCM.
  ///
  /// **Format retourné** (base64url) :
  ///   `[version:1] [salt:16] [iv:12] [ciphertext+tag:N]`
  ///
  /// **Throws** :
  ///   - [EncryptionException] si le password ou le texte est invalide
  String encrypt(String plaintext, String password) {
    _EncryptionValidators.validatePassword(password);
    _EncryptionValidators.validatePlaintext(plaintext);

    try {
      // 1. Générer salt + IV aléatoires
      final salt = _generateRandomBytes(_kSaltLength);
      final iv = _generateRandomBytes(_kIvLength);

      // 2. Dériver la clé AES-256
      final keyBytes = _deriveKey(password, salt);
      final key = encrypt.Key(keyBytes);

      // 3. Chiffrer avec AES-GCM (authenticated encryption)
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      final encrypted = encrypter.encryptBytes(
        utf8.encode(plaintext),
        iv: encrypt.IV(iv),
      );

      // 4. Assembler : version + salt + iv + ciphertext (avec tag GCM)
      final ciphertextBytes = encrypted.bytes;
      final result = Uint8List(
        1 + _kSaltLength + _kIvLength + ciphertextBytes.length,
      );
      var offset = 0;

      result[offset++] = _kVersionByte;
      result.setRange(offset, offset + _kSaltLength, salt);
      offset += _kSaltLength;
      result.setRange(offset, offset + _kIvLength, iv);
      offset += _kIvLength;
      result.setRange(offset, offset + ciphertextBytes.length, ciphertextBytes);

      debugPrint('[EncryptionService] ✓ Encrypted ${plaintext.length} chars');

      // 5. Encoder en base64url (URL-safe)
      return base64Url.encode(result);
    } on EncryptionException {
      rethrow;
    } catch (e) {
      debugPrint(
        '[EncryptionService] ❌ Encryption failed: '
        '${kDebugMode ? e : "error"}',
      );
      throw EncryptionException('Encryption failed', e);
    }
  }

  // ============================================================
  // DECRYPT
  // ============================================================

  /// Déchiffre un ciphertext produit par [encrypt].
  ///
  /// **Throws** :
  ///   - [DecryptionException] si password invalide / data corrompue
  String decrypt(String ciphertextBase64, String password) {
    _EncryptionValidators.validatePassword(password);
    _EncryptionValidators.validateCiphertext(ciphertextBase64);

    try {
      // 1. Décoder le base64url
      Uint8List data;
      try {
        data = base64Url.decode(ciphertextBase64);
      } catch (_) {
        // Fallback : base64 standard (compatibilité)
        try {
          data = base64.decode(ciphertextBase64);
        } catch (e) {
          throw const DecryptionException('Invalid base64 encoding');
        }
      }

      // 2. Vérifier longueur minimale
      final minLength = 1 + _kSaltLength + _kIvLength + 16; // 16 = tag GCM
      if (data.length < minLength) {
        throw const DecryptionException('Ciphertext too short');
      }

      // 3. Parser les composants
      var offset = 0;
      final version = data[offset++];

      if (version != _kVersionByte) {
        throw DecryptionException(
          'Unsupported version: $version (expected $_kVersionByte)',
        );
      }

      final salt = Uint8List.sublistView(data, offset, offset + _kSaltLength);
      offset += _kSaltLength;

      final iv = Uint8List.sublistView(data, offset, offset + _kIvLength);
      offset += _kIvLength;

      final ciphertextBytes = Uint8List.sublistView(data, offset);

      // 4. Dériver la clé avec le même salt
      final keyBytes = _deriveKey(password, salt);
      final key = encrypt.Key(keyBytes);

      // 5. Déchiffrer avec AES-GCM (vérifie automatiquement le tag)
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      try {
        final decrypted = encrypter.decryptBytes(
          encrypt.Encrypted(ciphertextBytes),
          iv: encrypt.IV(iv),
        );
        debugPrint('[EncryptionService] ✓ Decrypted ${decrypted.length} bytes');
        return utf8.decode(decrypted);
      } catch (e) {
        // GCM tag mismatch = wrong password OR corrupted data
        throw const DecryptionException(
          'Decryption failed (wrong password or corrupted data)',
        );
      }
    } on DecryptionException {
      rethrow;
    } catch (e) {
      debugPrint(
        '[EncryptionService] ❌ Decryption failed: '
        '${kDebugMode ? e : "error"}',
      );
      throw DecryptionException('Decryption failed', e);
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Vérifie si un ciphertext est déchiffrable avec un password donné.
  bool verifyPassword(String ciphertextBase64, String password) {
    try {
      decrypt(ciphertextBase64, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Génère un password aléatoire sécurisé de [length] caractères.
  String generatePassword({int length = 24}) {
    if (length < 12 || length > 128) {
      throw ArgumentError('Password length must be between 12 and 128');
    }

    const chars =
        'abcdefghijklmnopqrstuvwxyz'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        '0123456789'
        '!@#\$%^&*()-_=+';

    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[_secureRandom.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  /// Hash un password avec SHA-256 (pour stockage, pas pour chiffrement).
  ///
  /// ⚠️ Ne PAS utiliser pour protéger des passwords en base.
  /// Préférer bcrypt/argon2 pour le stockage de passwords utilisateurs.
  String hashPassword(String password) {
    _EncryptionValidators.validatePassword(password);
    final bytes = utf8.encode(password);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }
}
