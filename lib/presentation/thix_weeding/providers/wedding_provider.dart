// lib/presentation/thix_weeding/providers/wedding_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/failure.dart';
import '../data/repositories/wedding_repository_impl.dart';
import '../domain/entities/wedding_entity.dart';

part 'wedding_provider.g.dart';

@riverpod
Future<WeddingEntity> guestWedding(GuestWeddingRef ref, String weddingId) async {
  if (weddingId.trim().length < 4) {
    throw const Failure('ID de mariage invalide');
  }
  final repo = ref.read(weddingRepositoryProvider);
  return repo.getWeddingById(weddingId);
}
