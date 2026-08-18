// lib/features/auth/data/auth_repository.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(SupabaseClientRef ref) => Supabase.instance.client;

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository(ref.watch(supabaseClientProvider));

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);
  Stream<User?> authStateChanges() => _client.auth.onAuthStateChange.map((e) => e.session?.user);
  Future<Map<String, dynamic>?> fetchUserRow(String id) async => await _client.from('users').select().eq('id', id).maybeSingle();
}
