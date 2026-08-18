// lib/presentation/mon_pays/services/authorities_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http; // N'oubliez pas cette importation !
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/authority.dart';

class AuthoritiesService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================================
  // ASSISTANT IA (Tavily + Astral IA) AVEC PROMPT SOLIDE
  // ============================================================

  /// Interroge vos agents IA (Tavily + Astral IA) avec un prompt structuré
  /// pour récupérer et formater précisément les informations d'une personnalité
  Future<Map<String, dynamic>> fetchAuthorityDataWithAi(String query) async {
    try {
      const String systemPrompt = '''
Tu es l'assistant officiel de la plateforme Thix ID et Mon Pays, spécialisé dans la recherche politique et institutionnelle (RDC et international). 
Ton rôle est d'analyser la requête utilisateur, d'utiliser la recherche web (Tavily) pour trouver des informations factuelles, vérifiées et à jour sur la personnalité demandée, et de les structurer.

Tu dois impérativement retourner ta réponse sous la forme d'un objet JSON strict, sans markdown (pas de ```json ... ```), avec exactement les clés suivantes :

{
  "name": "Nom complet et officiel de la personnalité",
  "title": "Titre ou fonction exacte (ex: Président de la République, Ministre de l'Économie, etc.)",
  "category": "Doit obligatoirement être l'une de ces valeurs exactes : ['Président de la République', 'Présidence', 'Gouvernement', 'Assemblée Nationale', 'Sénat', 'Cours et Tribunaux', 'Entreprises Publiques', 'Gouverneurs', 'Figures Historiques', 'Autres']",
  "biography": "Une biographie professionnelle détaillée, factuelle et neutre de 3 à 5 phrases maximum.",
  "mandate": "La période du mandat au format texte (ex: 2019 - Présent)",
  "party": "Le parti politique ou regroupement (laisser vide si indépendant ou non applicable)",
  "imageUrl": "L'URL directe d'une photo officielle de portrait de la personnalité si trouvée, sinon null"
}

Si tu ne trouves pas une information précise, mets une chaîne vide "" ou null, mais respecte scrupuleusement la structure JSON. N'ajoute aucun commentaire textuel en dehors du JSON.
''';

      // ⚠️ DÉFINISSEZ VOS IDENTIFIANTS API ICI (Ceux de Thix IA / Astral IA)
      final String apiUrl = '[https://votre-api-thix-ia.com/votre-endpoint](https://votre-api-thix-ia.com/votre-endpoint)'; // <- Remplacez par votre vrai lien
      final String apiToken = 'VOTRE_CLE_API_ICI'; // <- Remplacez par votre vrai Token

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
        body: jsonEncode({
          // Adaptez la structure du body selon ce qu'attend votre API exacte
          'system_prompt': systemPrompt,
          'query': 'Recherche les informations factuelles sur : $query',
          'use_tavily': true, 
        }),
      );

      if (response.statusCode == 200) {
        // Récupération de la réponse brute
        String rawBody = response.body;
        
        // Parfois, l'API renvoie le JSON encapsulé dans une clé spécifique (ex: data['response'] ou data['choices'][0]['message']['content'])
        // Si c'est le cas pour votre API, décodez d'abord la réponse globale :
        // final decodedResponse = jsonDecode(rawBody);
        // rawBody = decodedResponse['votre_cle_de_reponse']; 

        // 1. Nettoyage de la réponse (pour enlever les éventuelles balises markdown générées par l'IA)
        rawBody = rawBody.replaceAll('```json', '').replaceAll('```', '').trim();

        // 2. Décodage du JSON propre
        final Map<String, dynamic> aiData = jsonDecode(rawBody);
        
        return aiData;
      } else {
        throw Exception('Erreur serveur API (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de l\'assistant Thix IA: $e');
    }
  }

  // ============================================================
  // STORAGE (UPLOAD FICHIERS)
  // ============================================================

  Future<String> uploadMedia(String fileName, Uint8List fileBytes,
      {String folder = 'photos'}) async {
    try {
      final path =
          'authorities/$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage.from('media').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType:
                  folder == 'videos' ? 'video/mp4' : 'image/jpeg',
            ),
          );
      return _client.storage.from('media').getPublicUrl(path);
    } catch (e) {
      throw Exception('Erreur upload média: $e');
    }
  }

  // ============================================================
  // READ AVEC PAGINATION SCALABLE
  // ============================================================

  Future<PaginatedResult<Authority>> getAuthoritiesPaginated({
    int page = 0,
    int limit = 20,
    String? category,
    String? search,
    bool? activeOnly,
  }) async {
    try {
      final offset = page * limit;
      
      var query = _client
          .from('authorities')
          .select(
              '*, education:authority_education(*), career:authority_career(*), achievements:authority_achievements(*), photos:authority_photos(*), videos:authority_videos(*), documents:authority_documents(*)'
          );

      if (category != null && category != 'Tous') {
        query = query.eq('title', category);
      }
      if (activeOnly == true) {
        query = query.eq('is_active', true);
      } else if (activeOnly == false) {
        query = query.eq('is_active', false);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('name.ilike.%$search%,title.ilike.%$search%');
      }

      final response = await query.order('name').range(offset, offset + limit - 1);

      var countQuery = _client.from('authorities').select();
      if (category != null && category != 'Tous') {
        countQuery = countQuery.eq('title', category);
      }
      if (activeOnly == true) {
        countQuery = countQuery.eq('is_active', true);
      } else if (activeOnly == false) {
        countQuery = countQuery.eq('is_active', false);
      }
      if (search != null && search.trim().isNotEmpty) {
        countQuery = countQuery.or('name.ilike.%$search%,title.ilike.%$search%');
      }
      final countResponse = await countQuery;
      final totalCount = (countResponse as List).length;

      final data = response.map((json) => Authority.fromJson(json)).toList();

      return PaginatedResult(
        data: data,
        total: totalCount,
        page: page,
        limit: limit,
        hasMore: (offset + limit) < totalCount,
      );
    } catch (e) {
      throw Exception('Erreur chargement autorités: $e');
    }
  }

  Future<Authority> getAuthorityWithRelations(String id) async {
    try {
      final response = await _client
          .from('authorities')
          .select(
              '*, education:authority_education(*), career:authority_career(*), achievements:authority_achievements(*), photos:authority_photos(*), videos:authority_videos(*), documents:authority_documents(*)')
          .eq('id', id)
          .single();
      return Authority.fromJson(response);
    } catch (e) {
      throw Exception('Erreur chargement autorité: $e');
    }
  }

  Future<List<Authority>> getActiveAuthorities() async {
    try {
      final response = await _client
          .from('authorities')
          .select('*')
          .eq('is_active', true)
          .order('name');
      return response.map((json) => Authority.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur chargement autorités actives: $e');
    }
  }

  Future<List<Authority>> getHistoricalAuthorities() async {
    try {
      final response = await _client
          .from('authorities')
          .select('*')
          .eq('is_active', false)
          .order('mandate_end', ascending: false);
      return response.map((json) => Authority.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur chargement autorités historiques: $e');
    }
  }

  // ============================================================
  // CREATE / UPDATE / DELETE
  // ============================================================

  Future<Authority> createAuthority(Authority authority) async {
    try {
      final data = authority.toJson();
      data.remove('id');

      data.remove('education');
      data.remove('career');
      data.remove('achievements');
      data.remove('photos');
      data.remove('videos');
      data.remove('documents');

      final response = await _client
          .from('authorities')
          .insert(data)
          .select()
          .single();

      final newAuthority = Authority.fromJson(response);

      await _insertRelations(newAuthority.id, authority);

      return await getAuthorityWithRelations(newAuthority.id);
    } catch (e) {
      throw Exception('Erreur lors de la création: $e');
    }
  }

  Future<Authority> updateAuthority(Authority authority) async {
    try {
      final data = authority.toJson();
      data.remove('education');
      data.remove('career');
      data.remove('achievements');
      data.remove('photos');
      data.remove('videos');
      data.remove('documents');

      await _client
          .from('authorities')
          .update(data)
          .eq('id', authority.id);

      await _deleteRelations(authority.id);
      await _insertRelations(authority.id, authority);

      return await getAuthorityWithRelations(authority.id);
    } catch (e) {
      throw Exception('Erreur mise à jour: $e');
    }
  }

  Future<void> deleteAuthority(String id) async {
    try {
      await _deleteRelations(id);
      await _client.from('authorities').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression: $e');
    }
  }

  Future<void> archiveAuthority(String id) async {
    try {
      await _client
          .from('authorities')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      throw Exception('Erreur archivage: $e');
    }
  }

  // ============================================================
  // RELATIONS PRIVÉES
  // ============================================================

  Future<void> _insertRelations(String authorityId, Authority authority) async {
    for (var item in authority.education) {
      final data = item.toJson();
      data.remove('id');
      data['authority_id'] = authorityId;
      await _client.from('authority_education').insert(data);
    }

    for (var item in authority.career) {
      final data = item.toJson();
      data.remove('id');
      data['authority_id'] = authorityId;
      await _client.from('authority_career').insert(data);
    }

    for (var item in authority.achievements) {
      final data = item.toJson();
      data.remove('id');
      data['authority_id'] = authorityId;
      await _client.from('authority_achievements').insert(data);
    }

    for (var item in authority.photos) {
      final data = item.toJson();
      data.remove('id');
      data['authority_id'] = authorityId;
      await _client.from('authority_photos').insert(data);
    }

    for (var item in authority.videos) {
      final data = item.toJson();
      data.remove('id');
      data['authority_id'] = authorityId;
      await _client.from('authority_videos').insert(data);
    }

    for (var item in authority.documents) {
      final data = item.toJson();
      data.remove('id');
      data['authority_id'] = authorityId;
      await _client.from('authority_documents').insert(data);
    }
  }

  Future<void> _deleteRelations(String authorityId) async {
    await _client.from('authority_education').delete().eq('authority_id', authorityId);
    await _client.from('authority_career').delete().eq('authority_id', authorityId);
    await _client.from('authority_achievements').delete().eq('authority_id', authorityId);
    await _client.from('authority_photos').delete().eq('authority_id', authorityId);
    await _client.from('authority_videos').delete().eq('authority_id', authorityId);
    await _client.from('authority_documents').delete().eq('authority_id', authorityId);
  }
}

class PaginatedResult<T> {
  final List<T> data;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  PaginatedResult({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });
}
