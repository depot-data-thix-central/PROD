import 'package:encrypt/encrypt.dart';

class EncryptionService {
  // Le mot de passe doit être dérivé d'une clé de 32 caractères
  static Encrypter _getEncrypter(String password) {
    final key = Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
    return Encrypter(AES(key));
  }

  static String encrypt(String text, String password) {
    final iv = IV.fromLength(16);
    return _getEncrypter(password).encrypt(text, iv: iv).base64;
  }

  static String decrypt(String encryptedBase64, String password) {
    final iv = IV.fromLength(16);
    return _getEncrypter(password).decrypt64(encryptedBase64, iv: iv);
  }
}
