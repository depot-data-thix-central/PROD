import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;

class EncryptionService {
  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _hmacLength = 32;
  static const int _iterations = 15000;
  static const int _keyLength = 32;
  static const String _prefix = 'ENCv1:';

  static String encryptMessage(String plainText, String password) {
    if (plainText.isEmpty) return '';
    if (password.isEmpty) throw Exception('Le mot de passe est requis');

    final salt = _secureRandomBytes(_saltLength);
    final iv = _secureRandomBytes(_ivLength);
    final keyBytes = _pbkdf2(
      Uint8List.fromList(utf8.encode(password)),
      salt,
      _iterations,
      _keyLength,
    );
    final key = encrypt.Key(keyBytes);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    final encrypted = encrypter.encrypt(plainText, iv: encrypt.IV(iv));

    final hmac = crypto.Hmac(crypto.sha256, keyBytes);
    final mac = hmac.convert(Uint8List.fromList([...iv,...encrypted.bytes])).bytes;

    final combined = Uint8List.fromList([...salt,...iv,...encrypted.bytes,...mac]);
    return '$_prefix${base64.encode(combined)}';
  }

  static String decryptMessage(String cipherTextBase64, String password) {
    if (cipherTextBase64.isEmpty) return '';
    if (password.isEmpty) throw Exception('Le mot de passe est requis');
    try {
      String b64 = cipherTextBase64.trim();
      if (b64.startsWith(_prefix)) {
        b64 = b64.substring(_prefix.length);
      }
      b64 = b64.replaceAll('🔒', '').trim();
      final combined = base64.decode(b64);

      if (combined.length < _saltLength + _ivLength + _hmacLength + 1) {
        throw Exception('short');
      }

      final salt = combined.sublist(0, _saltLength);
      final iv = combined.sublist(_saltLength, _saltLength + _ivLength);
      final cipherEnd = combined.length - _hmacLength;
      final cipherBytes = combined.sublist(_saltLength + _ivLength, cipherEnd);
      final macReceived = combined.sublist(cipherEnd);

      final keyBytes = _pbkdf2(
        Uint8List.fromList(utf8.encode(password)),
        Uint8List.fromList(salt),
        _iterations,
        _keyLength,
      );

      final hmac = crypto.Hmac(crypto.sha256, keyBytes);
      final macExpected = hmac.convert(Uint8List.fromList([...iv,...cipherBytes])).bytes;

      if (!_constantTimeEquals(macReceived, macExpected)) {
        throw Exception('hmac fail');
      }

      final key = encrypt.Key(keyBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      return encrypter.decrypt(
        encrypt.Encrypted(Uint8List.fromList(cipherBytes)),
        iv: encrypt.IV(Uint8List.fromList(iv)),
      );
    } catch (_) {
      throw Exception('Mot de passe incorrect ou message corrompu');
    }
  }

  static bool isEncrypted(String content) {
    if (content.isEmpty) return false;
    final t = content.trim();
    if (t.startsWith(_prefix)) return true;
    if (t.startsWith('🔒')) return true;
    if (t.length > 40 &&!t.contains(' ') && _isBase64(t)) return true;
    return false;
  }

  static Uint8List _pbkdf2(Uint8List password, Uint8List salt, int c, int dkLen) {
    const hLen = 32;
    final l = (dkLen / hLen).ceil();
    final dk = Uint8List(dkLen);
    for (int i = 1; i <= l; i++) {
      final block = _f(password, salt, c, i);
      final offset = (i - 1) * hLen;
      final len = min(hLen, dkLen - offset);
      dk.setRange(offset, offset + len, block.sublist(0, len));
    }
    return dk;
  }

  static Uint8List _f(Uint8List pwd, Uint8List salt, int c, int blockIndex) {
    final block = Uint8List(salt.length + 4);
    block.setAll(0, salt);
    block[salt.length] = (blockIndex >> 24) & 0xFF;
    block[salt.length + 1] = (blockIndex >> 16) & 0xFF;
    block[salt.length + 2] = (blockIndex >> 8) & 0xFF;
    block[salt.length + 3] = blockIndex & 0xFF;

    var u = Uint8List.fromList(crypto.Hmac(crypto.sha256, pwd).convert(block).bytes);
    var result = Uint8List.fromList(u);

    for (int i = 1; i < c; i++) {
      u = Uint8List.fromList(crypto.Hmac(crypto.sha256, pwd).convert(u).bytes);
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length!= b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _secureRandomBytes(int len) {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(len, (_) => rnd.nextInt(256)));
  }

  static bool _isBase64(String s) {
    try {
      base64.decode(s);
      return true;
    } catch (_) {
      return false;
    }
  }
}
