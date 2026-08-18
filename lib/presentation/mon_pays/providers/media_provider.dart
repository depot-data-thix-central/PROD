// Fichier n°16 : providers/media_provider.dart
// lib/presentation/mon_pays/providers/media_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/province_media.dart';
import '../services/media_service.dart';

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService();
});

final mediaByProvinceProvider = FutureProvider.family<List<ProvinceMedia>, String>((ref, provinceId) async {
  final service = ref.watch(mediaServiceProvider);
  return service.getMediaByProvince(provinceId);
});

final photosByProvinceProvider = FutureProvider.family<List<ProvinceMedia>, String>((ref, provinceId) async {
  final service = ref.watch(mediaServiceProvider);
  return service.getMediaByProvince(provinceId, type: 'photo');
});

final videosByProvinceProvider = FutureProvider.family<List<ProvinceMedia>, String>((ref, provinceId) async {
  final service = ref.watch(mediaServiceProvider);
  return service.getMediaByProvince(provinceId, type: 'video');
});

// Admin
final adminMediaProvider = StateNotifierProvider<AdminMediaNotifier, AsyncValue<List<ProvinceMedia>>>((ref) {
  return AdminMediaNotifier(ref);
});

class AdminMediaNotifier extends StateNotifier<AsyncValue<List<ProvinceMedia>>> {
  final Ref _ref;
  String? _currentProvinceId;

  AdminMediaNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> loadMedia(String provinceId) async {
    _currentProvinceId = provinceId;
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(mediaServiceProvider);
      final list = await service.getMediaByProvince(provinceId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createMedia(ProvinceMedia media) async {
    try {
      final service = _ref.read(mediaServiceProvider);
      await service.createMedia(media);
      if (_currentProvinceId != null) {
        await loadMedia(_currentProvinceId!);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateMedia(ProvinceMedia media) async {
    try {
      final service = _ref.read(mediaServiceProvider);
      await service.updateMedia(media);
      if (_currentProvinceId != null) {
        await loadMedia(_currentProvinceId!);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteMedia(String id) async {
    try {
      final service = _ref.read(mediaServiceProvider);
      await service.deleteMedia(id);
      if (_currentProvinceId != null) {
        await loadMedia(_currentProvinceId!);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
