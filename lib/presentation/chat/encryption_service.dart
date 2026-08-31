// lib/services/encryption_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;

// ============================================================================
// EXCEPTION TYPÉE
// ============================================================================

/// Exception dédiée au chiffrement avec code machine-readable
class EncryptionException implements Exception {
  final String message;
  final String code;

  const EncryptionException(this.message, {required this.code});

  @override
  String toString() => 'EncryptionException[$code]: $message';

  // Codes d'erreur standards
  static const String passwordRequired = 'password_required';
  static const String passwordTooShort = 'password_too_short';
  static const String passwordTooLong = 'password_too_long';
  static const String textTooLong = 'text_too_long';
  static const String cipherTooLong = 'cipher_too_long';
  static const String invalidFormat = 'invalid_format';
  static const String dataTooShort = 'data_too_short';
  static const String hmacMismatch = 'hmac_mismatch';
  static const String decryptionFailed = 'decryption_failed';
  static const String invalidBase64 = 'invalid_base64';
}

// ============================================================================
// CONSTANTS CRYPTOGRAPHIQUES
// ============================================================================

/// Service de chiffrement AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC)
///
/// Format du cipher:
///   ENCv1:<base64(salt[16] + iv[16] + ciphertext[n] + hmac[32])>
///
/// Sécurité:
///   - PBKDF2-HMAC-SHA256, 100,000 itérations (OWASP 2023)
///   - Salt unique 16 bytes par message
///   - IV unique 16 bytes par message
///   - AES-256-CBC + PKCS7
///   - HMAC-SHA256 (Encrypt-then-MAC)
///   - Comparaison HMAC en temps constant
class EncryptionService {
  EncryptionService._();

  // Constantes cryptographiques
  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _hmacLength = 32; // SHA-256 output
  static const int _iterations = 100000; // OWASP 2023 minimum pour SHA-256
  static const int _keyLength = 32; // AES-256
  static const String _prefix = 'ENCv1:';

  // Constantes de validation
  static const int _minPasswordLength = 8;
  static const int _maxPasswordLength = 1000;
  static const int _maxPlainTextLength = 100000; // 100KB
  static const int _maxCipherTextLength = 500000; // 500KB
  static const int _minPayloadLength = _saltLength + _ivLength + _hmacLength + 1;

  // Emoji legacy (à supprimer progressivement)
  static const String _legacyLockEmoji = '🔒';

  // Regex base64 strict (RFC 4648)
  static final RegExp _base64Regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  /// Chiffre un message avec un mot de passe.
  ///
  /// Retourne une chaîne au format `ENCv1:<base64(...)>`.
  /// Lance [EncryptionException] en cas d'erreur.
  static String encryptMessage(String? plainText, String? password) {
    if (plainText == null || plainText.isEmpty) {
      debugPrint('[Encryption] ℹ️ Empty plaintext, returning empty string');
      return '';
    }

    _validatePassword(password);
    _validatePlainText(plainText);

    try {
      final salt = _secureRandomBytes(_saltLength);
      final iv = _secureRandomBytes(_ivLength);

      final keyBytes = _pbkdf2(
        Uint8List.fromList(utf8.encode(password!)),
        salt,
        _iterations,
        _keyLength,
      );
      final key = encrypt.Key(keyBytes);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      final encrypted = encrypter.encrypt(plainText, iv: encrypt.IV(iv));

      // HMAC-SHA256 sur IV + ciphertext (Encrypt-then-MAC)
      final hmac = crypto.Hmac(crypto.sha256, keyBytes);
      final mac = hmac
          .convert(Uint8List.fromList([...iv, ...encrypted.bytes]))
          .bytes;

      // Format: salt + iv + ciphertext + hmac
      final combined = Uint8List.fromList([
        ...salt,
        ...iv,
        ...encrypted.bytes,
        ...mac,
      ]);

      debugPrint('[Encryption] 🔐 Encrypted ${plainText.length} chars');
      return '$_prefix${base64.encode(combined)}';
    } on EncryptionException {
      rethrow;
    } catch (e) {
      debugPrint('[Encryption] ❌ Encryption failed: $e');
      throw const EncryptionException(
        'Échec du chiffrement',
        code: EncryptionException.decryptionFailed,
      );
    }
  }

  /// Déchiffre un message avec un mot de passe.
  ///
  /// Lance [EncryptionException] si:
  /// - Format invalide
  /// - HMAC ne correspond pas (mot de passe incorrect ou données corrompues)
  /// - Données trop courtes
  static String decryptMessage(String? cipherText, String? password) {
    if (cipherText == null || cipherText.isEmpty) {
      debugPrint('[Encryption] ℹ️ Empty ciphertext, returning empty string');
      return '';
    }

    _validatePassword(password);
    _validateCipherText(cipherText);

    try {
      final b64 = _normalizeCipherText(cipherText);
      final combined = _decodeBase64(b64);

      if (combined.length < _minPayloadLength) {
        throw const EncryptionException(
          'Données trop courtes',
          code: EncryptionException.dataTooShort,
        );
      }

      // Extraire les composants
      final salt = combined.sublist(0, _saltLength);
      final iv = combined.sublist(_saltLength, _saltLength + _ivLength);
      final cipherEnd = combined.length - _hmacLength;
      final cipherBytes = combined.sublist(_saltLength + _ivLength, cipherEnd);
      final macReceived = combined.sublist(cipherEnd);

      // Dérivation de clé
      final keyBytes = _pbkdf2(
        Uint8List.fromList(utf8.encode(password!)),
        Uint8List.fromList(salt),
        _iterations,
        _keyLength,
      );

      // Vérification HMAC (avant déchiffrement — Encrypt-then-MAC)
      final hmac = crypto.Hmac(crypto.sha256, keyBytes);
      final macExpected = hmac
          .convert(Uint8List.fromList([...iv, ...cipherBytes]))
          .bytes;

      if (!_constantTimeEquals(macReceived, macExpected)) {
        debugPrint('[Encryption] ❌ HMAC mismatch — wrong password or corrupted data');
        throw const EncryptionException(
          'Mot de passe incorrect ou données corrompues',
          code: EncryptionException.hmacMismatch,
        );
      }

      // Déchiffrement
      final key = encrypt.Key(keyBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(Uint8List.fromList(cipherBytes)),
        iv: encrypt.IV(Uint8List.fromList(iv)),
      );

      debugPrint('[Encryption] 🔓 Decrypted ${decrypted.length} chars');
      return decrypted;
    } on EncryptionException {
      rethrow;
    } catch (e) {
      debugPrint('[Encryption] ❌ Decryption failed: $e');
      throw const EncryptionException(
        'Échec du déchiffrement',
        code: EncryptionException.decryptionFailed,
      );
    }
  }

  /// Détecte si un contenu semble chiffré.
  ///
  /// Retourne `true` si:
  /// - Préfixe `ENCv1:` présent
  /// - Emoji 🔒 présent (legacy)
  /// - String base64 longue sans espaces
  static bool isEncrypted(String? content) {
    if (content == null || content.isEmpty) return false;

    final trimmed = content.trim();
    if (trimmed.startsWith(_prefix)) return true;
    if (trimmed.startsWith(_legacyLockEmoji)) return true;

    // Heuristique: long base64 sans espaces
    if (trimmed.length > 60 && !trimmed.contains(' ')) {
      return _isValidBase64(trimmed);
    }

    return false;
  }

  /// Retourne la version du format de chiffrement.
  static String get formatVersion => 'ENCv1';

  /// Retourne le nombre d'itérations PBKDF2 configuré.
  static int get pbkdf2Iterations => _iterations;

  // =========================================================================
  // VALIDATIONS
  // =========================================================================

  static void _validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      throw const EncryptionException(
        'Le mot de passe est requis',
        code: EncryptionException.passwordRequired,
      );
    }
    if (password.length < _minPasswordLength) {
      throw const EncryptionException(
        'Le mot de passe doit contenir au moins $_minPasswordLength caractères',
        code: EncryptionException.passwordTooShort,
      );
    }
    if (password.length > _maxPasswordLength) {
      throw const EncryptionException(
        'Le mot de passe est trop long (max $_maxPasswordLength caractères)',
        code: EncryptionException.passwordTooLong,
      );
    }
  }

  static void _validatePlainText(String plainText) {
    if (plainText.length > _maxPlainTextLength) {
      throw EncryptionException(
        'Le texte est trop long (max ${_maxPlainTextLength ~/ 1000}KB)',
        code: EncryptionException.textTooLong,
      );
    }
  }

  static void _validateCipherText(String cipherText) {
    if (cipherText.length > _maxCipherTextLength) {
      throw EncryptionException(
        'Le cipher est trop long (max ${_maxCipherTextLength ~/ 1000}KB)',
        code: EncryptionException.cipherTooLong,
      );
    }
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  /// Normalise le cipher text en retirant préfixe et emoji legacy.
  static String _normalizeCipherText(String cipherText) {
    var result = cipherText.trim();

    if (result.startsWith(_prefix)) {
      result = result.substring(_prefix.length);
    }

    // Retirer tous les emojis 🔒 legacy
    while (result.startsWith(_legacyLockEmoji)) {
      result = result.substring(_legacyLockEmoji.length).trim();
    }

    return result;
  }

  /// Décode base64 avec validation stricte.
  static Uint8List _decodeBase64(String b64) {
    if (!_isValidBase64(b64)) {
      throw const EncryptionException(
        'Format base64 invalide',
        code: EncryptionException.invalidBase64,
      );
    }
    try {
      return base64.decode(b64);
    } catch (e) {
      throw const EncryptionException(
        'Décodage base64 échoué',
        code: EncryptionException.invalidBase64,
      );
    }
  }

  /// Validation base64 stricte (regex avant decode pour perf).
  static bool _isValidBase64(String s) {
    if (s.isEmpty) return false;
    if (s.length % 4 != 0) return false; // Base64 doit être multiple de 4
    if (!_base64Regex.hasMatch(s)) return false;
    try {
      base64.decode(s);
      return true;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // PBKDF2 IMPLEMENTATION
  // =========================================================================

  /// PBKDF2-HMAC-SHA256 (RFC 2898).
  ///
  /// Implémentation custom pour éviter dépendance externe.
  /// Conforme à RFC 2898 section 5.2.
  static Uint8List _pbkdf2(Uint8List password, Uint8List salt, int iterations, int dkLen) {
    const hLen = 32; // SHA-256 output length
    final blocksNeeded = (dkLen / hLen).ceil();
    final dk = Uint8List(dkLen);

    for (int i = 1; i <= blocksNeeded; i++) {
      final block = _pbkdf2Block(password, salt, iterations, i);
      final offset = (i - 1) * hLen;
      final len = min(hLen, dkLen - offset);
      dk.setRange(offset, offset + len, block.sublist(0, len));
    }

    return dk;
  }

  /// Calcule un block PBKDF2: U1 ^ U2 ^ ... ^ Uc
  static Uint8List _pbkdf2Block(Uint8List password, Uint8List salt, int iterations, int blockIndex) {
    // salt || INT_32_BE(i)
    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setAll(0, salt);
    saltWithIndex[salt.length] = (blockIndex >> 24) & 0xFF;
    saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xFF;
    saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xFF;
    saltWithIndex[salt.length + 3] = blockIndex & 0xFF;

    // U1 = PRF(password, salt || INT(i))
    var u = Uint8List.fromList(crypto.Hmac(crypto.sha256, password).convert(saltWithIndex).bytes);
    final result = Uint8List.fromList(u);

    // U2 ... Uc
    for (int i = 1; i < iterations; i++) {
      u = Uint8List.fromList(crypto.Hmac(crypto.sha256, password).convert(u).bytes);
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    return result;
  }

  // =========================================================================
  // COMPARAISON TEMPS CONSTANT
  // =========================================================================

  /// Comparaison en temps constant pour éviter les attaques timing.
  ///
  /// IMPORTANT: Ne doit PAS early-return sur longueur différente,
  /// sinon l'attaquant peut détecter la longueur du HMAC attendu.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    int diff = a.length ^ b.length;

    for (int i = 0; i < maxLen; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      diff |= ai ^ bi;
    }

    return diff == 0;
  }

  // =========================================================================
  // RANDOMNESS
  // =========================================================================

  /// Génère des bytes aléatoires cryptographiquement sûrs.
  ///
  /// Utilise `Random.secure()` qui exploite `/dev/urandom` (Linux/Android)
  /// ou `CryptGenRandom` (Windows).
  static Uint8List _secureRandomBytes(int length) {
    if (length <= 0) {
      throw ArgumentError('length must be positive');
    }
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
  }
}
