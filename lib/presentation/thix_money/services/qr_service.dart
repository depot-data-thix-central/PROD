// lib/presentation/thix_money/services/qr_service.dart
import 'dart:convert';

class QrService {
  // Génère QR avec thix_id vérifié
  static String encodeThixQr({required String thixId, required String displayName}) {
    final payload = {'thix_id': thixId, 'name': displayName, 'v': 1};
    return 'THIX:${base64Encode(utf8.encode(jsonEncode(payload)))}';
  }

  // Décode QR et vérifie format THIX ID
  static Map<String, dynamic>? decodeThixQr(String raw) {
    try {
      if (!raw.startsWith('THIX:')) {
        // Ancien format simple phone
        if (RegExp(r'^\d{10}$').hasMatch(raw)) return {'phone': raw};
        return null;
      }
      final b64 = raw.substring(5);
      final jsonStr = utf8.decode(base64Decode(b64));
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data['thix_id'] == null) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  static bool isValidThixId(String thixId) {
    return thixId.startsWith('THIX-') && thixId.split('-').length == 6;
  }
}
