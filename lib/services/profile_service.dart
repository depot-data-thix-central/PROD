// lib/services/profile_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/services/supabase_safe_write.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class ProfileService {
  static const String table = 'profiles';
  static const String formationsTable = 'formations';
  static const String experiencesTable = 'experiences';
  static const String emergencyContactsTable = 'contacts_urgence';
  static const String credentialsBucket = 'thix-credentials';

  // Désactivation automatique des tables optionnelles si elles n'existent pas
  static final Set<String> _disabledOptionalTables = <String>{};

  static bool _isMissingTableError(Object e) =>
      e is PostgrestException &&
      (e.code == 'PGRST205' || e.message.contains('Could not find the table'));

  static bool _isUnknownColumnError(Object e) {
    if (e is! PostgrestException) return false;
    return e.code == 'PGRST204' ||
        e.code == '42703' ||
        e.message.contains("Could not find the '") ||
        e.message.toLowerCase().contains('does not exist');
  }

  /// Recharge le cache de schéma PostgREST (utile après une migration)
  Future<void> _reloadSchemaCache() async {
    try {
      await SupabaseConfig.client.rpc('pgrst_schema_reload');
      debugPrint('ProfileService: schema reloaded via RPC');
    } catch (_) {
      try {
        await SupabaseConfig.client.functions.invoke('pgrst_schema_reload', body: {});
        debugPrint('ProfileService: schema reloaded via edge function');
      } catch (e) {
        debugPrint('ProfileService: schema reload failed: $e');
      }
    }
  }

  String? _normalizeDateOrNull(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\d{4}$').hasMatch(t)) return '$t-01-01';
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(t)) return '$t-01';
    return t;
  }

  // ─── Récupération publique (PAGINATION SCALABLE) ──────────────────────

  /// Récupère des suggestions de profils avec pagination (Offset/Limit)
  Future<List<ThixProfile>> fetchPublicSuggestions({int page = 0, int limit = 12}) async {
    try {
      final int start = page * limit;
      final int end = start + limit - 1;

      final res = await SupabaseConfig.client
          .from(table)
          .select()
          .order('updated_at', ascending: false)
          .range(start, end);

      // `res` est déjà un List<Map<String, dynamic>> (PostgrestList),
      // le type check et le cast explicites sont donc inutiles.
      final rows = res.toList();

      return rows
          .map(ThixProfile.fromPrivateRow)
          .where((p) => p.thixId.trim().isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('fetchPublicSuggestions error: $e');
      return const [];
    }
  }

  // ─── Garantir l’existence d’un profil ──────────────────────────────────

  Future<void> ensureProfileExists({required AppUser user}) async {
    final base = ThixProfile.fallback(
      userId: user.id,
      thixId: user.thixId,
      displayName: user.displayName,
    );
    try {
      await SupabaseSafeWrite.upsert(
        client: SupabaseConfig.client,
        table: table,
        payload: {
          'id': base.userId,
          'thix_id': base.thixId,
          'avatar_url': user.photoUrl,
        },
        onUnknownColumn: _reloadSchemaCache,
      );
    } catch (e) {
      debugPrint('ensureProfileExists failed: $e');
    }
  }

  // ─── Streams en temps réel (Supabase Realtime) ────────────────────────

  Stream<ThixProfile?> streamMyProfile(String userId) {
    return _streamProfileById(userId);
  }

  Stream<ThixProfile?> streamPublicProfileByThixId(String thixId) {
    final normalized = thixId.trim().toUpperCase();
    return _streamProfileByEq('thix_id', normalized);
  }

  Stream<ThixProfile?> streamPublicProfileByUserId(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return const Stream<ThixProfile?>.empty();
    return _streamProfileByEq('id', uid);
  }

  Stream<ThixProfile?> _streamProfileById(String userId) {
    return _streamProfileByEq('id', userId);
  }

  Stream<ThixProfile?> _streamProfileByEq(String column, String value) {
    return SupabaseConfig.client
        .from(table)
        .stream(primaryKey: ['id'])
        .eq(column, value)
        .map((rows) {
          if (rows.isEmpty) return null;
          return ThixProfile.fromPrivateRow(rows.first);
        });
  }

  // ─── Fetch ponctuels (sans cache) ──────────────────────────────────────

  Future<ThixProfile?> fetchPublicProfileByUserId(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return null;
    try {
      final row = await SupabaseConfig.client
          .from(table)
          .select()
          .eq('id', uid)
          .maybeSingle();
      return row != null ? ThixProfile.fromPrivateRow(row) : null;
    } catch (e) {
      debugPrint('fetchPublicProfileByUserId error: $e');
      return null;
    }
  }

  Future<ThixProfile?> fetchPublicProfileByThixId(String thixId) async {
    final normalized = thixId.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final row = await SupabaseConfig.client
          .from(table)
          .select()
          .eq('thix_id', normalized)
          .maybeSingle();
      return row != null ? ThixProfile.fromPrivateRow(row) : null;
    } catch (e) {
      debugPrint('fetchPublicProfileByThixId error: $e');
      return null;
    }
  }

  // ─── Streams des sous‑tables (Realtime) ───────────────────────────────

  Stream<List<Map<String, dynamic>>> streamFormations(String userId) =>
      _streamSubTable(formationsTable, userId);

  Stream<List<Map<String, dynamic>>> streamExperiences(String userId) =>
      _streamSubTable(experiencesTable, userId);

  Stream<List<Map<String, dynamic>>> streamEmergencyContacts(String userId) =>
      _streamSubTable(emergencyContactsTable, userId);

  Stream<List<Map<String, dynamic>>> _streamSubTable(String tableName, String userId) {
    if (_disabledOptionalTables.contains(tableName)) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }
    return SupabaseConfig.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  // ─── Mises à jour du profil principal ──────────────────────────────────

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? fullName,
    String? photoUrl,
    String? bio,
    String? thixId,
    String? profession,
    String? occupation,
    String? countryOrOrigin,
    String? maritalStatus,
    String? gender,
    String? thixChat,
    String? contactPhone,
    String? dateOfBirth,
    String? placeOfBirth,
    String? nationality,
    String? address,
    String? fatherName,
    String? motherName,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? originProvince,
    String? originTerritory,
    String? originSector,
    String? residenceCountry,
    String? residenceProvince,
    String? residenceTerritory,
    String? residenceCity,
    String? residenceCommune,
    String? residenceQuarter,
    String? residenceAvenue,
    String? residenceNumber,
    List<Map<String, dynamic>>? emergencyContacts,
    String? height,
    String? weight,
    String? bloodGroup,
    bool? hasPhysicalDisability,
    String? physicalDisabilityDescription,
    String? nationalIdNumber,
    String? idDocumentType,
    String? idDocumentIssueDate,
    String? idDocumentExpiryDate,
    String? idDocumentIssuePlace,
    String? idDocumentFrontDocId,
    String? idDocumentBackDocId,
    String? idDocumentSelfieDocId,
    String? idVerificationStatus,
    String? competence,
    List<Map<String, dynamic>>? languagesDetailed,
    List<Map<String, dynamic>>? trainings,
    List<String>? languages,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? skills,
    List<Map<String, dynamic>>? certifications,
    List<Map<String, dynamic>>? documents,
    List<Map<String, dynamic>>? contacts,
    ThixVisibilitySettings? visibility,
  }) async {
    final authedUid = SupabaseConfig.client.auth.currentUser?.id;
    final effectiveUserId = (authedUid != null && authedUid.trim().isNotEmpty)
        ? authedUid
        : userId;

    final data = <String, dynamic>{};

    // Transforme les String vides ("") en null
    void put(String k, Object? v) {
      if (v is String) {
        final trimmed = v.trim();
        data[k] = trimmed.isEmpty ? null : trimmed;
      } else {
        if (v != null) data[k] = v;
      }
    }

    void putAliases(List<String> keys, Object? v) {
      for (final k in keys) {
        put(k, v);
      }
    }

    // Renommé sans underscore : c'est une variable/fonction locale, pas privée.
    double? parseDoubleOrNull(String? s) {
      if (s == null) return null;
      final t = s.trim().replaceAll(',', '.');
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    put('thix_id', thixId);
    put('full_name', fullName ?? displayName);
    put('display_name', displayName);
    put('avatar_url', photoUrl);
    put('bio', bio);
    put('profession', profession);
    put('occupation', occupation);
    put('country_or_origin', countryOrOrigin);
    put('marital_status', maritalStatus);
    put('gender', gender);
    put('thix_chat', thixChat);
    put('contact_phone', contactPhone);
    put('date_of_birth', dateOfBirth);
    put('place_of_birth', placeOfBirth);
    put('nationality', nationality);
    put('address', address);
    put('father_name', fatherName);
    put('mother_name', motherName);
    put('emergency_contact_name', emergencyContactName);
    put('emergency_contact_phone', emergencyContactPhone);
    put('emergency_contact_relation', emergencyContactRelation);
    putAliases(['origin_province'], originProvince);
    putAliases(['origin_territory'], originTerritory);
    putAliases(['origin_sector'], originSector);
    putAliases(['residence_country', 'pays_residence'], residenceCountry);
    putAliases(['residence_province', 'province_residence'], residenceProvince);
    putAliases(['residence_territory', 'territoire_residence'], residenceTerritory);
    putAliases(['residence_city', 'ville_residence'], residenceCity);
    putAliases(['residence_commune', 'commune_residence'], residenceCommune);
    putAliases(['residence_quarter', 'quartier_residence'], residenceQuarter);
    putAliases(['residence_avenue', 'avenue_residence'], residenceAvenue);
    putAliases(['residence_number', 'numero_residence'], residenceNumber);
    put('emergency_contacts', emergencyContacts);
    put('height', height);
    put('weight', weight);
    final heightNum = parseDoubleOrNull(height);
    if (heightNum != null) data['height_cm'] = heightNum;
    final weightNum = parseDoubleOrNull(weight);
    if (weightNum != null) data['weight_kg'] = weightNum;
    put('blood_group', bloodGroup);
    if (hasPhysicalDisability != null) data['has_physical_disability'] = hasPhysicalDisability;
    put('physical_disability_description', physicalDisabilityDescription);
    put('national_id_number', nationalIdNumber);
    put('id_document_type', idDocumentType);
    put('id_document_issue_date', idDocumentIssueDate);
    put('id_document_expiry_date', idDocumentExpiryDate);
    put('id_document_issue_place', idDocumentIssuePlace);
    put('id_document_front_doc_id', idDocumentFrontDocId);
    put('id_document_back_doc_id', idDocumentBackDocId);
    put('id_document_selfie_doc_id', idDocumentSelfieDocId);
    put('id_verification_status', idVerificationStatus);
    put('competence', competence);
    put('languages_detailed', languagesDetailed);
    put('trainings', trainings);
    put('languages', languages);
    put('education', education);
    put('experience', experience);
    put('skills', skills);
    put('certifications', certifications);
    put('documents', documents);
    put('contacts', contacts);
    if (visibility != null) data['visibility_settings'] = visibility.toJson();

    data['updated_at'] = DateTime.now().toUtc().toIso8601String();

    if (data.keys.length <= 1) return;

    try {
      await SupabaseSafeWrite.update(
        client: SupabaseConfig.client,
        table: table,
        patch: data,
        filters: {'id': effectiveUserId},
        onUnknownColumn: _reloadSchemaCache,
      );

      if (trainings != null || education != null) {
        final merged = <Map<String, dynamic>>[];
        merged.addAll(trainings ?? []);
        merged.addAll(education ?? []);
        await replaceFormations(userId: effectiveUserId, entries: merged);
      }
      if (experience != null) {
        await replaceExperiences(userId: effectiveUserId, entries: experience);
      }
      if (emergencyContacts != null) {
        await replaceEmergencyContacts(userId: effectiveUserId, entries: emergencyContacts);
      }
    } catch (e) {
      debugPrint('updateProfile failed: $e');
      rethrow;
    }
  }

  // ─── Gestion des sous‑tables (remplacement complet) ──────────────────

  Future<void> replaceFormations({
    required String userId,
    required List<Map<String, dynamic>> entries,
  }) async =>
      _replaceSubTable(formationsTable, userId, entries);

  Future<void> replaceExperiences({
    required String userId,
    required List<Map<String, dynamic>> entries,
  }) async =>
      _replaceSubTable(experiencesTable, userId, entries);

  Future<void> replaceEmergencyContacts({
    required String userId,
    required List<Map<String, dynamic>> entries,
  }) async =>
      _replaceSubTable(emergencyContactsTable, userId, entries);

  Future<void> _replaceSubTable(
    String tableName,
    String userId,
    List<Map<String, dynamic>> entries,
  ) async {
    if (_disabledOptionalTables.contains(tableName)) return;
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null || uid != userId) return;

    try {
      await SupabaseConfig.client.from(tableName).delete().eq('user_id', userId);
      if (entries.isEmpty) return;

      List<Map<String, dynamic>> rows;
      if (tableName == formationsTable) {
        rows = entries.map(_trainingEntryToFormationRow).toList();
      } else if (tableName == experiencesTable) {
        rows = entries.map(_experienceEntryToRow).toList();
      } else {
        rows = entries.map((e) => {'user_id': userId, 'payload': e}).toList();
      }

      if (rows.isEmpty) return;

      await SupabaseSafeWrite.insertMany(
        client: SupabaseConfig.client,
        table: tableName,
        rows: rows,
        onUnknownColumn: _reloadSchemaCache,
      );
    } catch (e) {
      if (_isMissingTableError(e)) {
        _disabledOptionalTables.add(tableName);
        return;
      }
      if (_isUnknownColumnError(e)) {
        return;
      }
      debugPrint('_replaceSubTable error for $tableName: $e');
    }
  }

  // ─── Transformation des entrées ──────────────────────────────────────

  Map<String, dynamic> _trainingEntryToFormationRow(Map<String, dynamic> entry) {
    final title = (entry['title'] ?? entry['name'] ?? entry['degree'] ?? entry['level'] ?? '').toString().trim();
    var type = (entry['type'] ?? entry['category'] ?? '').toString().trim();
    final organizer = (entry['organizer'] ?? entry['organized_by'] ?? entry['provider'] ?? entry['institution'] ?? '').toString().trim();
    final startDate = _normalizeDateOrNull((entry['start_date'] ?? entry['start'] ?? entry['startYear'] ?? '').toString());
    final endDate = _normalizeDateOrNull((entry['end_date'] ?? entry['end'] ?? entry['endYear'] ?? '').toString());
    final duration = (entry['duration'] ?? entry['period'] ?? '').toString().trim();
    final skills = (entry['skills'] ?? entry['skills_acquired'] ?? entry['competences'] ?? '').toString().trim();

    if (type.isEmpty && entry.containsKey('institution')) type = 'Études';

    return {
      'title': title.isEmpty ? null : title,
      'name': title.isEmpty ? null : title,
      'type': type.isEmpty ? null : type,
      'organizer': organizer.isEmpty ? null : organizer,
      'organized_by': organizer.isEmpty ? null : organizer,
      'start_date': startDate?.isEmpty == true ? null : startDate,
      'end_date': endDate?.isEmpty == true ? null : endDate,
      'duration': duration.isEmpty ? null : duration,
      'skills': skills.isEmpty ? null : skills,
      'skills_acquired': skills.isEmpty ? null : skills,
      'description': (entry['description'] ?? entry['details'] ?? '').toString().trim().isEmpty
          ? null
          : (entry['description'] ?? entry['details']).toString().trim(),
      'verification_status': (entry['verification_status'] ?? entry['verificationStatus'] ?? 'pending').toString(),
      'evidence': entry['evidence'],
    }..removeWhere((k, v) => v == null);
  }

  Map<String, dynamic> _experienceEntryToRow(Map<String, dynamic> entry) {
    final companyName = (entry['company_name'] ?? entry['company'] ?? entry['employer'] ?? entry['org'] ?? '').toString().trim();
    final position = (entry['position'] ?? entry['title'] ?? entry['role'] ?? entry['poste'] ?? '').toString().trim();
    final startDate = _normalizeDateOrNull((entry['start_date'] ?? entry['start'] ?? entry['startYear'] ?? '').toString());
    final endDate = _normalizeDateOrNull((entry['end_date'] ?? entry['end'] ?? entry['endYear'] ?? '').toString());

    final missions = (entry['description'] ?? entry['missions'] ?? entry['tasks'] ?? '').toString().trim();
    final sector = (entry['sector'] ?? entry['industry'] ?? '').toString().trim();
    final city = (entry['city'] ?? '').toString().trim();
    final descParts = <String>[];
    if (missions.isNotEmpty) descParts.add(missions);
    if (sector.isNotEmpty) descParts.add('Secteur: $sector');
    if (city.isNotEmpty) descParts.add('Ville: $city');
    final description = descParts.join('\n');

    return {
      'company_name': companyName.isEmpty ? null : companyName,
      'company': companyName.isEmpty ? null : companyName,
      'employer': companyName.isEmpty ? null : companyName,
      'position': position.isEmpty ? null : position,
      'title': position.isEmpty ? null : position,
      'start_date': startDate?.isEmpty == true ? null : startDate,
      'end_date': endDate?.isEmpty == true ? null : endDate,
      'description': description.isEmpty ? null : description,
      'missions': missions.isEmpty ? null : missions,
      'sector': sector.isEmpty ? null : sector,
      'city': city.isEmpty ? null : city,
      'verification_status': (entry['verification_status'] ?? entry['verificationStatus'] ?? 'pending').toString(),
      'evidence': entry['evidence'],
    }..removeWhere((k, v) => v == null);
  }

  // ─── Activation du compte (RPC) ────────────────────────────────────────

  Future<String> activateAccountAfterPayment({
    required String userId,
    required String countryCode,
    required String displayName,
    required String txRef,
    required String method,
    required num amount,
    required String currency,
    String? photoUrl,
  }) async {
    try {
      final res = await SupabaseConfig.client.rpc(
        'thix_activate_account_after_payment',
        params: {
          'p_user_id': userId,
          'p_country_code': countryCode,
          'p_display_name': displayName,
          'p_photo_url': photoUrl,
          'p_method': method,
          'p_tx_ref': txRef,
          'p_amount': amount,
          'p_currency': currency,
        },
      );
      final thixId = (res is String) ? res : (res?.toString() ?? '').trim();
      if (thixId.isEmpty) throw Exception('Activation RPC returned empty THIX UID.');
      return thixId;
    } catch (e) {
      debugPrint('activateAccountAfterPayment failed: $e');
      rethrow;
    }
  }

  // ─── Visibilité ─────────────────────────────────────────────────────────

  Future<void> updateVisibility({
    required String userId,
    required ThixVisibilitySettings visibility,
  }) async {
    await updateProfile(userId: userId, visibility: visibility);
  }

  // ─── Génération et Réservation 100% DART (Fallback) ────────────────────

  /// Génère un nouveau THIX ID unique
  Future<String> generateThixId({
    required String uid,
    String? prefix,
    String? countryCode,
  }) async {
    final rand = Random();
    String newId = '';
    bool exists = true;
    int attempts = 0;

    while (exists && attempts < 10) {
      final p = prefix ?? 'THIX';
      final cc = countryCode ?? 'CD';
      final d = DateTime.now();
      final datePart = '${d.month.toString().padLeft(2, '0')}${d.year.toString().substring(2)}';
      final numPart = (10000 + rand.nextInt(90000)).toString();

      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final alphaPart = String.fromCharCodes(Iterable.generate(3, (_) => chars.codeUnitAt(rand.nextInt(chars.length))));
      final checksum = rand.nextInt(10).toString();

      newId = '$p-$cc-$datePart-$numPart-$alphaPart-$checksum';

      try {
        final res = await SupabaseConfig.client.from(table).select('id').eq('thix_id', newId).maybeSingle();
        if (res == null) {
          exists = false;
        }
      } catch (e) {
        exists = false;
      }
      attempts++;
    }

    if (exists) {
      newId = 'THIX-CD-FALLBACK-${DateTime.now().millisecondsSinceEpoch}';
    }

    return newId;
  }

  /// Réserve un pseudonyme THIX CHAT en vérifiant son unicité
  Future<String> reserveThixChat({required String userId, required String desired}) async {
    final formattedHandle = desired.startsWith('@') ? desired : '@$desired';

    try {
      final existing = await SupabaseConfig.client
          .from(table)
          .select('id')
          .eq('thix_chat', formattedHandle)
          .neq('id', userId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Ce pseudo THIX CHAT est déjà utilisé.');
      }

      await SupabaseConfig.client.from(table).update({
        'thix_chat': formattedHandle,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      return formattedHandle;
    } catch (e) {
      debugPrint('Error reserveThixChat: $e');
      rethrow;
    }
  }
}
