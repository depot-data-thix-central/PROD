import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Émission client UNIQUEMENT pour les événements hors-DB
/// (appels, live, SOS…). Le reste est géré par les triggers SQL.
class NotifEmitter {
  NotifEmitter._();
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> call({
    required String recipientUid,
    required String type, // 'call' | 'call_missed'
    required String title,
    String body = '',
    String? route,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _db.rpc('notify_event', params: {
        'p_recipient': recipientUid,
        'p_category': 'messages',
        'p_type': type,
        'p_title': title,
        'p_body': body,
        'p_route': route,
        'p_data': data ?? const {},
        'p_priority': 1,
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[NotifEmitter] ❌ call: $e');
    }
  }

  static Future<void> custom({
    required String recipientUid,
    required String category,
    required String type,
    required String title,
    String body = '',
    String? route,
    int priority = 0,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _db.rpc('notify_event', params: {
        'p_recipient': recipientUid,
        'p_category': category,
        'p_type': type,
        'p_title': title,
        'p_body': body,
        'p_route': route,
        'p_data': data ?? const {},
        'p_priority': priority,
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[NotifEmitter] ❌ custom: $e');
    }
  }
}
