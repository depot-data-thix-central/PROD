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
    // Photos réelles uploadées par le staff (table thix_weeding_gallery)
    const pageSize = 30;
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    try {
      final res = await Supabase.instance.client
          .from('thix_weeding_gallery')
          .select('url, image_url')
          .eq('wedding_id', weddingId)
          .order('created_at', ascending: false)
          .range(from, to);

      final list = <String>[];
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final u = (row['url'] as String?) ?? (row['image_url'] as String?) ?? '';
        if (u.trim().isNotEmpty) list.add(u.trim());
      }
      return list;
    } catch (e) {
      throw Failure('Galerie: ${e.toString()}');
    }
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
    try {
      final res = await Supabase.instance.client
          .from('thix_weeding_gifts')
          .select()
          .eq('wedding_id', weddingId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res).map((e) {
        return GiftItem(
          id: e['id']?.toString() ?? '',
          name: e['name']?.toString() ?? '',
          imageUrl: (e['image_url'] as String?) ?? '',
          price: (e['price'] as num?)?.toDouble() ?? 0,
          contributed: (e['contributed'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (e) {
      throw Failure('Cadeaux: ${e.toString()}');
    }
  }

  @override
  Future<List<ProgramItem>> getProgram(String weddingId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return <ProgramItem>[];
  }
}
