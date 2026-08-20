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
    try {
      final res = await _client
          .from(_table)
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);
      return (res as List)
          .map((e) => PersonneRecherchee.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      return [];
    }
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
