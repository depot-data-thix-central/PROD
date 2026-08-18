// lib/providers/auth_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  bool _isModerator = false;
  bool get isModerator => _isModerator;

  @override
  Future<bool> build() async {
    await _checkRole();
    return _isModerator;
  }

  Future<void> _checkRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { _isModerator = false; return; }
    try {
      final res = await Supabase.instance.client.from('users').select('role').eq('id', user.id).maybeSingle();
      _isModerator = res != null && (res['role'] == 'moderator' || res['role'] == 'admin');
    } catch (_) { _isModerator = false; }
  }

  Future<void> refresh() async {
    await _checkRole();
    ref.invalidateSelf();
  }
}
