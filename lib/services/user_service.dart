import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class UserService {
  final SupabaseClient _supabase;

  UserService(this._supabase);

  // ==========================================================================
  // UPDATE PROFILE — Colonnes sensibles GELÉES
  // ==========================================================================

  Future<void> updateProfile({
    required String uid,
    // ⭐ SUPPRIMÉ : thixId (géré par le serveur)
    String? displayName,
    String? fullName,
    String? photoUrl,
    // ⭐ SUPPRIMÉ : registrationStatus (géré par le serveur)
    String? thixChat,
    String? bio,
    String? competence,
    String? countryOrOrigin,
    String? contactPhone,
    String? dateOfBirth,
    String? placeOfBirth,
    String? nationality,
    String? maritalStatus,
    String? gender,
    String? occupation,
    String? profession,
    String? address,
    String? fatherName,
    String? motherName,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? experience,
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
    // ⭐ SUPPRIMÉ : idVerificationStatus (géré par le serveur)
    // ⭐ SUPPRIMÉ : biometricsEnabled (géré par le serveur)
    // ⭐ SUPPRIMÉ : twoFaEnabled (géré par le serveur)
    List<String>? languages,
    List<Map<String, dynamic>>? languagesDetailed,
  }) async {
    final Map<String, dynamic> updates = {};

    // Informations personnelles (autorisées)
    if (displayName != null) updates['display_name'] = displayName;
    if (fullName != null) updates['full_name'] = fullName;
    if (photoUrl != null) updates['photo_url'] = photoUrl;
    if (thixChat != null) updates['thix_chat'] = thixChat;
    if (bio != null) updates['bio'] = bio;
    if (competence != null) updates['competence'] = competence;
    if (countryOrOrigin != null) updates['country_or_origin'] = countryOrOrigin;
    if (contactPhone != null) updates['contact_phone'] = contactPhone;
    if (dateOfBirth != null) updates['date_of_birth'] = dateOfBirth;
    if (placeOfBirth != null) updates['place_of_birth'] = placeOfBirth;
    if (nationality != null) updates['nationality'] = nationality;
    if (maritalStatus != null) updates['marital_status'] = maritalStatus;
    if (gender != null) updates['gender'] = gender;
    if (occupation != null) updates['occupation'] = occupation;
    if (profession != null) updates['profession'] = profession;
    if (address != null) updates['address'] = address;
    if (fatherName != null) updates['father_name'] = fatherName;
    if (motherName != null) updates['mother_name'] = motherName;
    if (emergencyContactName != null) updates['emergency_contact_name'] = emergencyContactName;
    if (emergencyContactPhone != null) updates['emergency_contact_phone'] = emergencyContactPhone;
    if (emergencyContactRelation != null) updates['emergency_contact_relation'] = emergencyContactRelation;
    if (education != null) updates['education'] = education;
    if (experience != null) updates['experience'] = experience;

    // Origine
    if (originProvince != null) updates['origin_province'] = originProvince;
    if (originTerritory != null) updates['origin_territory'] = originTerritory;
    if (originSector != null) updates['origin_sector'] = originSector;

    // Résidence
    if (residenceCountry != null) updates['residence_country'] = residenceCountry;
    if (residenceProvince != null) updates['residence_province'] = residenceProvince;
    if (residenceTerritory != null) updates['residence_territory'] = residenceTerritory;
    if (residenceCity != null) updates['residence_city'] = residenceCity;
    if (residenceCommune != null) updates['residence_commune'] = residenceCommune;
    if (residenceQuarter != null) updates['residence_quarter'] = residenceQuarter;
    if (residenceAvenue != null) updates['residence_avenue'] = residenceAvenue;
    if (residenceNumber != null) updates['residence_number'] = residenceNumber;

    // Contacts d'urgence
    if (emergencyContacts != null) updates['emergency_contacts'] = emergencyContacts;

    // Informations physiques
    if (height != null) updates['height'] = height;
    if (weight != null) updates['weight'] = weight;
    if (bloodGroup != null) updates['blood_group'] = bloodGroup;
    if (hasPhysicalDisability != null) updates['has_physical_disability'] = hasPhysicalDisability;
    if (physicalDisabilityDescription != null) updates['physical_disability_description'] = physicalDisabilityDescription;

    // Documents d'identité
    if (nationalIdNumber != null) updates['national_id_number'] = nationalIdNumber;
    if (idDocumentType != null) updates['id_document_type'] = idDocumentType;
    if (idDocumentIssueDate != null) updates['id_document_issue_date'] = idDocumentIssueDate;
    if (idDocumentExpiryDate != null) updates['id_document_expiry_date'] = idDocumentExpiryDate;
    if (idDocumentIssuePlace != null) updates['id_document_issue_place'] = idDocumentIssuePlace;
    if (idDocumentFrontDocId != null) updates['id_document_front_doc_id'] = idDocumentFrontDocId;
    if (idDocumentBackDocId != null) updates['id_document_back_doc_id'] = idDocumentBackDocId;
    if (idDocumentSelfieDocId != null) updates['id_document_selfie_doc_id'] = idDocumentSelfieDocId;

    // Langues
    if (languages != null) updates['languages'] = languages;
    if (languagesDetailed != null) updates['languages_detailed'] = languagesDetailed;

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('profiles').update(updates).eq('id', uid);
    }
  }

  // ==========================================================================
  // MÉTHODES DE PAIEMENT (inchangées)
  // ==========================================================================

  Future<void> addPaymentTransaction({
    required String uid,
    required String title,
    required double amount,
    required String currency,
    required String method,
    required String status,
  }) async {
    final payment = {
      'user_id': uid,
      'title': title,
      'amount': amount,
      'currency': currency,
      'method': method,
      'status': status,
      'tx_ref': 'TX-${DateTime.now().millisecondsSinceEpoch}',
      'created_at': DateTime.now().toIso8601String(),
    };
    await _supabase.from('thix_payments').insert(payment);
  }

  Stream<List<Map<String, dynamic>>> streamPayments(String uid) {
    return _supabase
        .from('thix_payments')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((list) => list.cast<Map<String, dynamic>>());
  }

  // ==========================================================================
  // MÉTHODES DE SÉCURITÉ — Supprimées (gérées par RPCs serveur)
  // ==========================================================================

  // ⭐ SUPPRIMÉ : logSecurityEvent() — Utiliser la RPC serveur à la place
  // La table security_events est protégée et seuls les RPCs SECURITY DEFINER peuvent y écrire.

  Stream<List<Map<String, dynamic>>> streamSecurityEvents(String uid) {
    return _supabase
        .from('security_events')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((list) => list.cast<Map<String, dynamic>>());
  }

  // ==========================================================================
  // MÉTHODES POUR THIX ID — SUPPRIMÉES (gérées par finalize_registration)
  // ==========================================================================

  // ⭐ SUPPRIMÉ : ensureThixId()
  // La génération de THIX ID est UNIQUEMENT côté serveur via finalize_registration().
  // Cette méthode est obsolète et dangereuse (fallback client-side).

  // ⭐ SUPPRIMÉ : ensureThixChat()
  // La réservation de THIX CHAT est UNIQUEMENT côté serveur via finalize_registration().
  // Cette méthode est obsolète et dangereuse (fallback client-side).

  // ==========================================================================
  // MÉTHODES POUR HOME PAGE — Utilisent profiles_public
  // ==========================================================================

  Future<AppUser?> getUserByThixId(String thixId) async {
    try {
      // ⭐ CORRECTION : Utiliser profiles_public au lieu de profiles
      final row = await _supabase
          .from('profiles_public')
          .select()
          .eq('thix_id', thixId)
          .maybeSingle();
      if (row == null) return null;
      return _mapToAppUserPublic(row);
    } catch (e) {
      debugPrint('getUserByThixId failed: $e');
      return null;
    }
  }

  Future<AppUser?> getUserById(String userId) async {
    try {
      // Vérifier si c'est l'utilisateur courant
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == userId) {
        // Lecture complète pour le propriétaire
        final row = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (row == null) return null;
        return _mapToAppUser(row);
      } else {
        // Lecture publique pour les autres
        final row = await _supabase
            .from('profiles_public')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (row == null) return null;
        return _mapToAppUserPublic(row);
      }
    } catch (e) {
      debugPrint('getUserById failed: $e');
      return null;
    }
  }

  // ==========================================================================
  // MÉTHODES DE MAPPING
  // ==========================================================================

  AppUser _mapToAppUser(Map<String, dynamic> row) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final createdAt = row['created_at'] != null ? parseDate(row['created_at']) : DateTime.now();
    final updatedAt = row['updated_at'] != null ? parseDate(row['updated_at']) : DateTime.now();

    List<Map<String, dynamic>> mapList(dynamic value) {
      if (value is List) {
        return value.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      }
      return <Map<String, dynamic>>[];
    }

    List<String> stringList(dynamic value) {
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return <String>[];
    }

    final educationList = mapList(row['education']);
    final experienceList = mapList(row['experience']);
    final skillsList = mapList(row['skills']);
    final enrollmentsList = mapList(row['enrollments']);
    final languagesList = stringList(row['languages']);

    int thixScore = 0;
    final score = row['thix_score'];
    if (score is num) thixScore = score.toInt();

    return AppUser(
      id: row['id'] ?? '',
      thixId: row['thix_id'] ?? 'THIX-PENDING',
      thixChat: row['thix_chat'] ?? '',
      thixScore: thixScore,
      email: row['email'] ?? '',
      phone: row['phone'] ?? '',
      displayName: row['display_name'] ?? 'Utilisateur',
      accountType: (row['account_type'] ?? 'personal') == 'enterprise' ? AccountType.enterprise : AccountType.personal,
      photoUrl: row['photo_url'],
      bio: row['bio'],
      occupation: row['occupation'],
      countryOrOrigin: row['country_or_origin'],
      contactPhone: row['contact_phone'],
      maritalStatus: row['marital_status'],
      gender: row['gender'],
      profession: row['profession'],
      dateOfBirth: row['date_of_birth'],
      placeOfBirth: row['place_of_birth'],
      nationality: row['nationality'],
      address: row['address'],
      fatherName: row['father_name'],
      motherName: row['mother_name'],
      emergencyContactName: row['emergency_contact_name'],
      emergencyContactPhone: row['emergency_contact_phone'],
      emergencyContactRelation: row['emergency_contact_relation'],
      registrationStatus: row['registration_status'],
      education: educationList,
      experience: experienceList,
      skills: skillsList,
      enrollments: enrollmentsList,
      languages: languagesList,
      biometricsEnabled: (row['biometrics_enabled'] as bool?) ?? true,
      twoFaEnabled: (row['two_fa_enabled'] as bool?) ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Mapping pour les profils publics (données limitées)
  AppUser _mapToAppUserPublic(Map<String, dynamic> row) {
    return AppUser(
      id: row['id'] ?? '',
      thixId: row['thix_id'] ?? 'THIX-PENDING',
      thixChat: row['thix_chat'] ?? '',
      thixScore: 0,
      email: '', // ⭐ Masqué pour les profils publics
      phone: '', // ⭐ Masqué pour les profils publics
      displayName: row['display_name'] ?? 'Utilisateur',
      accountType: AccountType.personal,
      photoUrl: row['photo_url'],
      bio: row['bio'],
      occupation: row['occupation'],
      countryOrOrigin: row['country_or_origin'],
      contactPhone: '', // ⭐ Masqué pour les profils publics
      maritalStatus: '', // ⭐ Masqué pour les profils publics
      gender: '', // ⭐ Masqué pour les profils publics
      profession: row['profession'],
      dateOfBirth: '', // ⭐ Masqué pour les profils publics
      placeOfBirth: '', // ⭐ Masqué pour les profils publics
      nationality: '', // ⭐ Masqué pour les profils publics
      address: '', // ⭐ Masqué pour les profils publics
      fatherName: '', // ⭐ Masqué pour les profils publics
      motherName: '', // ⭐ Masqué pour les profils publics
      emergencyContactName: '', // ⭐ Masqué pour les profils publics
      emergencyContactPhone: '', // ⭐ Masqué pour les profils publics
      emergencyContactRelation: '', // ⭐ Masqué pour les profils publics
      registrationStatus: row['registration_status'],
      education: const [],
      experience: const [],
      skills: const [],
      enrollments: const [],
      languages: const [],
      biometricsEnabled: false,
      twoFaEnabled: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
