import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Secure enterprise session bootstrap.
///
/// Calls Supabase Edge Function `thix_enterprise_create_session` which:
/// - captures request IP + user agent
/// - stores device fingerprint
/// - creates a short-lived secure session row
class EnterpriseSessionService {
  static const String functionName = 'thix_enterprise_create_session';
  DateTime? _last;
  String? _sessionId;

  Future<void> ensureSecureSession({required String companySlug}) async {
    // Simple throttle to avoid spamming the edge function.
    final now = DateTime.now();
    if (_last != null && now.difference(_last!).inMinutes < 3 && (_sessionId ?? '').isNotEmpty) return;
    _last = now;

    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final fingerprint = _deviceFingerprint(uid: uid);
      final res = await SupabaseConfig.client.functions.invoke(
        functionName,
        body: {
          'company_slug': companySlug,
          'device_fingerprint': fingerprint,
        },
      );
      if (res.data is Map) {
        _sessionId = (res.data['session_id'] ?? '').toString();
      }
    } catch (e, st) {
      debugPrint('EnterpriseSessionService.ensureSecureSession failed err=$e');
      debugPrint('$st');
    }
  }

  String _deviceFingerprint({required String uid}) {
    // We keep this privacy-conscious and stable per user per device.
    // On web we can include host + platform info; on mobile we keep it minimal.
    final raw = jsonEncode({
      'uid': uid,
      'platform': defaultTargetPlatform.name,
      'isWeb': kIsWeb,
      'host': kIsWeb ? Uri.base.host : '',
    });
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
