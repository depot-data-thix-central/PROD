// lib/features/auth/presentation/providers/auth_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:thix_id/models/app_user.dart';
import '../../data/auth_repository.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
Stream<dynamic> authUserStream(AuthUserStreamRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

@Riverpod(keepAlive: true)
class AppUserNotifier extends _$AppUserNotifier {
  @override
  Future<AppUser?> build() async {
    final user = await ref.watch(authUserStreamProvider.future);
    if (user == null) return null;
    final row = await ref.read(authRepositoryProvider).fetchUserRow(user.id);
    if (row == null) return null;
    return AppUser.fromSupabase(row);
  }
}
