import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import '../models/objet_model.dart';

class ObjetService {
  final SupabaseClient _client;

  ObjetService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  static const String _table = 'thix_objets';
  static const String _bucket = 'objets';

  /// Upload photo (Web + Mobile)
  /// [bytes] = contenu du fichier
  /// [fileName] = nom avec extension (ex: photo.jpg)
  Future<String?> uploadPhotoBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final userId = SupabaseConfig.currentUser?.id ?? 'anonymous';
      final ext = fileName.split('.').last.toLowerCase();
      final safeName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$userId/$safeName';

      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Erreur uploadPhotoBytes: $e');
      rethrow;
    }
  }

  Future<ObjetModel?> declarerObjet({
    required String titre,
    required String description,
    required StatutObjet statut,
    required String lieu,
    String? recompense,
    String? categorie,
    String? contactInfo,
    double? latitude,
    double? longitude,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    try {
      String? imageUrl;

      if (photoBytes != null && photoBytes.isNotEmpty) {
        imageUrl = await uploadPhotoBytes(
          bytes: photoBytes,
          fileName: photoFileName ?? 'photo.jpg',
        );
      }

      final userId = SupabaseConfig.currentUser?.id;

      final data = {
        'titre': titre.trim(),
        'description': description.trim(),
        'statut': statut.name,
        'lieu': lieu.trim(),
        'date_signalement': DateTime.now().toIso8601String(),
        'recompense': recompense?.trim(),
        'categorie': categorie,
        'contact_info': contactInfo?.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'user_id': userId,
      };

      final res = await _client.from(_table).insert(data).select().single();
      return ObjetModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      print('Erreur declarerObjet: $e');
      rethrow;
    }
  }

  Future<List<ObjetModel>> getObjetsRecents({int limit = 30}) async {
    try {
      final res = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (res as List)
          .map((e) => ObjetModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Erreur getObjetsRecents: $e');
      return [];
    }
  }

  Future<List<ObjetModel>> getMesObjets() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (res as List)
          .map((e) => ObjetModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Erreur getMesObjets: $e');
      return [];
    }
  }

  Future<List<ObjetModel>> rechercherCorrespondances(ObjetModel perdu) async {
    try {
      final keyword = perdu.titre.split(' ').first;
      final res = await _client
          .from(_table)
          .select()
          .eq('statut', 'trouve')
          .ilike('titre', '%$keyword%')
          .order('created_at', ascending: false)
          .limit(10);

      return (res as List)
          .map((e) => ObjetModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> marquerRecupere(String objetId) async {
    await _client.from(_table).update({
      'statut': 'recupere',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', objetId);
  }
}
