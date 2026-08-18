// lib/services/user_service.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class UserService {
  final SupabaseClient _supabase;

  UserService(this._supabase);

  // ==================== MÉTHODE updateProfile AVEC thixId ====================

  Future<void> updateProfile({
    required String uid,
    String? thixId,
    String? displayName,
    String? fullName,
    String? photoUrl,
    String? registrationStatus,
    String? thixChat,
    String? bio,
    String? chatId,
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
    String? idVerificationStatus,
    bool? biometricsEnabled,
    bool? twoFaEnabled,
    List<String>? languages,
    List<Map<String, dynamic>>? languagesDetailed,
  }) async {
    final Map<String, dynamic> updates = {};

    // Informations personnelles
    if (thixId != null) updates['thix_id'] = thixId;
    if (displayName != null) updates['display_name'] = displayName;
    if (fullName != null) updates['full_name'] = fullName;
    if (photoUrl != null) updates['photo_url'] = photoUrl;
    if (registrationStatus != null) updates['registration_status'] = registrationStatus;
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
    if (idVerificationStatus != null) updates['id_verification_status'] = idVerificationStatus;

    // Sécurité
    if (biometricsEnabled != null) updates['biometrics_enabled'] = biometricsEnabled;
    if (twoFaEnabled != null) updates['two_fa_enabled'] = twoFaEnabled;

    // Langues
    if (languages != null) updates['languages'] = languages;
    if (languagesDetailed != null) updates['languages_detailed'] = languagesDetailed;

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('profiles').update(updates).eq('id', uid);
    }
  }

  // ==================== MÉTHODES DE PAIEMENT ====================

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

  // ==================== MÉTHODES DE SÉCURITÉ ====================

  Future<void> logSecurityEvent({
    required String uid,
    required String type,
    required String label,
  }) async {
    final event = {
      'user_id': uid,
      'type': type,
      'label': label,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _supabase.from('security_events').insert(event);
  }

  Stream<List<Map<String, dynamic>>> streamSecurityEvents(String uid) {
    return _supabase
        .from('security_events')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((list) => list.cast<Map<String, dynamic>>());
  }

  // ==================== MÉTHODES POUR THIX ID ====================

  Future<String> ensureThixId({required String uid}) async {
    try {
      final result = await _supabase.rpc('ensure_thix_id', params: {'p_user_id': uid});
      return result as String;
    } catch (e) {
      debugPrint('⚠️ RPC ensure_thix_id failed: $e');

      final row = await _supabase.from('profiles').select('thix_id').eq('id', uid).maybeSingle();
      final existing = (row?['thix_id'] ?? '').toString().trim();
      if (existing.isNotEmpty && existing != 'THIX-PENDING') return existing;

      String candidate;
      int attempts = 0;
      do {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        candidate = 'THIX-${timestamp.substring(5)}';
        attempts++;
        if (attempts > 5) {
          candidate = 'THIX-${timestamp.substring(5)}-${Random().nextInt(9999)}';
        }
        final existingRow = await _supabase
            .from('profiles')
            .select('id')
            .eq('thix_id', candidate)
            .maybeSingle();
        if (existingRow == null) break;
      } while (true);

      await _supabase.from('profiles').update({'thix_id': candidate}).eq('id', uid);
      return candidate;
    }
  }

  Future<String> ensureThixChat({required String uid, required String desired}) async {
    String normalized = desired.trim().toLowerCase();
    if (normalized.startsWith('@')) {
      normalized = normalized.substring(1);
    }
    if (normalized.length > 20) {
      normalized = normalized.substring(0, 20);
    }
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    if (normalized.isEmpty) {
      normalized = 'user${Random().nextInt(9999)}';
    }
    final String finalChat = '@$normalized';

    try {
      final result = await _supabase.rpc('reserve_thix_chat', params: {
        'p_user_id': uid,
        'p_desired_chat': finalChat,
      });
      return result as String;
    } catch (e) {
      debugPrint('⚠️ RPC reserve_thix_chat failed, fallback: $e');
      await _supabase.from('profiles').update({'thix_chat': finalChat}).eq('id', uid);
      return finalChat;
    }
  }

  // ==================== MÉTHODES POUR HOME PAGE ====================

  Future<AppUser?> getUserByThixId(String thixId) async {
    final row = await _supabase
        .from('profiles')
        .select()
        .eq('thix_id', thixId)
        .maybeSingle();
    if (row == null) return null;
    // `.maybeSingle()` retourne déjà Map<String, dynamic>?, cast inutile.
    return _mapToAppUser(row);
  }

  Future<AppUser?> getUserById(String userId) async {
    final row = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _mapToAppUser(row);
  }

  // ==================== MÉTHODE DE MAPPING ====================

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
}
