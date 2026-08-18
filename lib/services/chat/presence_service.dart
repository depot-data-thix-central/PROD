import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  final SupabaseClient _supabase;
  Timer? _heartbeat;

  PresenceService(this._supabase);

  String get _uid => _supabase.auth.currentUser?.id?? '';

  void initPresence() {
    if (_uid.isEmpty) return;
    _update('online');
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_uid.isNotEmpty) _update('online');
    });
  }

  Future<void> _update(String status) async {
    if (_uid.isEmpty) return;
    try {
      await _supabase.from('user_presence').upsert({
        'user_id': _uid,
        'status': status,
        'last_seen_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Presence error: $e');
    }
  }

  Future<void> setOnline() => _update('online');
  Future<void> setOffline() => _update('offline');

  void dispose() {
    _heartbeat?.cancel();
    // fire and forget, ne pas await dans dispose
    setOffline();
  }
}
