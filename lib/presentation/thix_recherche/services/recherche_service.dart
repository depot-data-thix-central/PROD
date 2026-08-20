import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import '../models/personne_recherchee_model.dart';

class RechercheService {
  final SupabaseClient _client;

  RechercheService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  static const String _table = 'personnes_recherchees';
  static const String _bucket = 'personnes-recherchees';

  /// Alertes actives (liste principale)
  Future<List<PersonneRecherchee>> getAlertesActives({
    TypeAlerte? type,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .eq('statut', 'active');

      if (type != null) {
        query = query.eq('type_alerte', type.name);
      }

      final res = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (res as List)
          .map((e) => PersonneRecherchee.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('RechercheService.getAlertesActives: $e');
      return [];
    }
  }

  /// Alertes à proximité (basé sur le GPS et la formule de Haversine)
  Future<List<PersonneRecherchee>> getAlertesProximite({
    required double lat,
    required double lng,
    double radiusKm = 25,
    int limit = 50,
  }) async {
    try {
      // MVP : charge les actives avec GPS, filtre en local
      final res = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .eq('statut', 'active')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .order('created_at', ascending: false)
          .limit(200);

      final list = (res as List)
          .map((e) => PersonneRecherchee.fromJson(Map<String, dynamic>.from(e)))
          .where((p) {
            if (p.latitude == null || p.longitude == null) return false;
            return _haversineKm(lat, lng, p.latitude!, p.longitude!) <= radiusKm;
          })
          .take(limit)
          .toList();

      return list;
    } catch (e) {
      print('RechercheService.getAlertesProximite: $e');
      return [];
    }
  }

  /// Stream temps réel (liste)
  Stream<List<PersonneRecherchee>> watchAlertesActives({TypeAlerte? type}) {
    final stream = _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return stream.map((rows) {
      var list = rows
          .map((e) => PersonneRecherchee.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.statut == StatutAlerte.active)
          .toList();
      if (type != null) {
        list = list.where((p) => p.typeAlerte == type).toList();
      }
      return list;
    });
  }

  /// Mettre à jour une alerte (propriétaire)
  Future<PersonneRecherchee?> updateAlerte({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final payload = {
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client
        .from(_table)
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return PersonneRecherchee.fromJson(Map<String, dynamic>.from(res));
  }

  /// Soft delete (archive)
  Future<void> archiverAlerte(String id) async {
    await _client.from(_table).update({
      'statut': StatutAlerte.archivee.name,
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Suppression définitive (optionnel)
  Future<void> supprimerAlerte(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
  
  Future<PersonneRecherchee?> getById(String id) async {
    try {
      final res =
          await _client.from(_table).select().eq('id', id).maybeSingle();
      if (res == null) return null;
      return PersonneRecherchee.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      print('RechercheService.getById: $e');
      return null;
    }
  }

  Future<List<PersonneRecherchee>> getMesAlertes() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return [];

    final res = await _client
        .from(_table)
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => PersonneRecherchee.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Upload d'une seule photo
  Future<String?> uploadPhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final userId = SupabaseConfig.currentUser?.id ?? 'anonymous';
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'jpg';

      // ✅ Path propre : uniquement lettres, chiffres, /, ., -, _
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeExt = (ext == 'png' || ext == 'webp' || ext == 'jpg' || ext == 'jpeg')
          ? ext
          : 'jpg';
      final path = '$userId/$timestamp.$safeExt';

      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: safeExt == 'png'
                  ? 'image/png'
                  : (safeExt == 'webp' ? 'image/webp' : 'image/jpeg'),
            ),
          );

      return _client.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      print('RechercheService.uploadPhoto: $e');
      rethrow;
    }
  }

  /// Upload multi-photos (limité à 3)
  Future<List<String>> uploadPhotos(List<({Uint8List bytes, String name})> files) async {
    final urls = <String>[];
    for (final f in files.take(3)) {
      final url = await uploadPhoto(bytes: f.bytes, fileName: f.name);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  /// Création d'une alerte (mise à jour avec catégorie, GPS et multi-photos)
  Future<PersonneRecherchee?> creerAlerte({
    required String nom,
    String? prenom,
    int? age,
    String? sexe,
    double? tailleCm,
    required TypeAlerte typeAlerte,
    CategorieAlerte? categorie,
    List<String>? photoUrls,
    String? photoUrl, // 1ère photo (rétrocompatibilité)
    String? derniereZone,
    DateTime? derniereVueAt,
    double? latitude,
    double? longitude,
    String? description,
    String? contactInfo,
  }) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      final urls = photoUrls ?? (photoUrl != null ? [photoUrl] : <String>[]);

      final data = {
        'nom': nom.trim(),
        'prenom': prenom?.trim(),
        'age': age,
        'sexe': sexe,
        'taille_cm': tailleCm,
        'type_alerte': typeAlerte.name,
        'categorie': categorie?.dbValue,
        'statut': StatutAlerte.active.name,
        'photo_url': urls.isNotEmpty ? urls.first : null,
        'photo_urls': urls,
        'derniere_zone': derniereZone?.trim(),
        'derniere_vue_at': derniereVueAt?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'description': description?.trim(),
        'contact_info': contactInfo?.trim(),
        'created_by': userId,
        'is_active': true,
      };

      final res = await _client.from(_table).insert(data).select().single();
      return PersonneRecherchee.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      print('RechercheService.creerAlerte: $e');
      rethrow;
    }
  }

  /// Marquer comme retrouvée (Unique méthode conservée avec gestion d'erreur)
  Future<void> marquerRetrouvee(String id) async {
    try {
      await _client.from(_table).update({
        'statut': StatutAlerte.retrouvee.name,
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      print('RechercheService.marquerRetrouvee: $e');
      rethrow;
    }
  }

  Future<void> signalerInfo({
    required String personneId,
    required String message,
    String? zone,
  }) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      await _client.from('signalements_recherche').insert({
        'personne_id': personneId,
        'user_id': userId,
        'message': message.trim(),
        'zone': zone?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('RechercheService.signalerInfo: $e');
      rethrow;
    }
  }
}

// --- Helpers Mathématiques pour la Géolocalisation ---

double _haversineKm(
  double lat1, double lon1, double lat2, double lon2,
) {
  const r = 6371.0; // Rayon de la Terre en kilomètres
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) *
          sin(dLon / 2) * sin(dLon / 2);
  return 2 * r * asin(min(1.0, sqrt(a)));
}

double _rad(double d) => d * pi / 180;
