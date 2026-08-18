import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/failure.dart';
import '../../domain/entities/wedding_entity.dart';
import '../../models/program_item_model.dart';

final weddingRepositoryProvider =
    Provider<WeddingRepository>((ref) => WeddingRepositoryImpl());

abstract class WeddingRepository {
  Future<WeddingEntity> getWeddingById(String id);
  Future<List<WeddingEntity>> getWeddingsByOwnerId(String ownerId);
  Future<List<String>> getGallery(String weddingId, {int page = 1});
  Future<void> submitRsvp(RsvpEntity rsvp);
  Future<void> submitLivreOr(String weddingId, String name, String message);
  Future<List<GiftItem>> getGifts(String weddingId);
  Future<List<ProgramItem>> getProgram(String weddingId);
}

class WeddingRepositoryImpl implements WeddingRepository {
  WeddingEntity _map(Map<String, dynamic> response, {String? fallbackId}) {
    final dateRaw = response['date'] ?? response['wedding_date'];
    DateTime date;
    try {
      date = dateRaw != null ? DateTime.parse(dateRaw.toString()) : DateTime.now();
    } catch (_) {
      date = DateTime.now();
    }

    final bride = response['bride_name']?.toString() ?? '';
    final groom = response['groom_name']?.toString() ?? '';
    final couple = (response['couple_names']?.toString().isNotEmpty == true)
        ? response['couple_names'].toString()
        : [bride, groom].where((e) => e.isNotEmpty).join(' & ');

    return WeddingEntity(
      id: response['id']?.toString() ?? fallbackId ?? '',
      locationName:
          response['location_name']?.toString() ?? response['venue']?.toString() ?? '',
      locationAddress: response['location_address']?.toString() ?? '',
      latitude: (response['latitude'] ?? 0).toDouble(),
      longitude: (response['longitude'] ?? 0).toDouble(),
      coupleNames: couple,
      welcomeMessage: response['welcome_message']?.toString() ?? '',
      announcement: response['announcement']?.toString() ?? '',
      date: date,
      coverImageUrl: response['cover_image_url']?.toString() ??
          'https://picsum.photos/800/600',
    );
  }

  @override
  Future<WeddingEntity> getWeddingById(String id) async {
    final cleanId = id.trim().toUpperCase();

    if (cleanId.length < 4) {
      throw const Failure('ID de mariage invalide');
    }

    try {
      final response = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select()
          .eq('id', cleanId)
          .maybeSingle();

      if (response == null) {
        throw const Failure(
          'Aucun mariage trouvé avec cet ID. Veuillez vérifier votre code.',
        );
      }

      return _map(response, fallbackId: cleanId);
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Erreur de connexion : ${e.toString()}');
    }
  }

  @override
  Future<List<WeddingEntity>> getWeddingsByOwnerId(String ownerId) async {
    try {
      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res).map(_map).toList();
    } catch (e) {
      throw Failure('Erreur chargement mariages : ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getGallery(String weddingId, {int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.generate(
      20,
      (i) => 'https://picsum.photos/400/400?random=${page * 20 + i}',
    );
  }

  @override
  Future<void> submitRsvp(RsvpEntity rsvp) async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Future<void> submitLivreOr(
    String weddingId,
    String name,
    String message,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<List<GiftItem>> getGifts(String weddingId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      const GiftItem(
        id: '1',
        name: 'Lune de miel',
        imageUrl: 'https://picsum.photos/200',
        price: 500000,
        contributed: 150000,
      ),
      const GiftItem(
        id: '2',
        name: 'Service à vaisselle',
        imageUrl: 'https://picsum.photos/200',
        price: 200000,
        contributed: 200000,
      ),
    ];
  }

  @override
  Future<List<ProgramItem>> getProgram(String weddingId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return <ProgramItem>[];
  }
}
