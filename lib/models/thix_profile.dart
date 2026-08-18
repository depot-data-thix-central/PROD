import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class ThixVisibilitySettings {
  final bool bio;
  final bool education;
  final bool experience;
  final bool skills;
  final bool certifications;
  final bool documents;
  final bool contacts;

  const ThixVisibilitySettings({
    this.bio = true,
    this.education = true,
    this.experience = true,
    this.skills = true,
    this.certifications = true,
    this.documents = true,
    this.contacts = false,
  });

  Map<String, dynamic> toJson() => {
        'bio': bio,
        'education': education,
        'experience': experience,
        'skills': skills,
        'certifications': certifications,
        'documents': documents,
        'contacts': contacts,
      };

  factory ThixVisibilitySettings.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    bool b(String k, bool d) => (j[k] is bool) ? j[k] as bool : d;
    return ThixVisibilitySettings(
      bio: b('bio', true),
      education: b('education', true),
      experience: b('experience', true),
      skills: b('skills', true),
      certifications: b('certifications', true),
      documents: b('documents', true),
      contacts: b('contacts', false),
    );
  }

  ThixVisibilitySettings copyWith({
    bool? bio,
    bool? education,
    bool? experience,
    bool? skills,
    bool? certifications,
    bool? documents,
    bool? contacts,
  }) {
    return ThixVisibilitySettings(
      bio: bio ?? this.bio,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
      certifications: certifications ?? this.certifications,
      documents: documents ?? this.documents,
      contacts: contacts ?? this.contacts,
    );
  }
}

@immutable
class ThixProfile {
  final String userId;
  final String thixId;
  final String displayName;
  /// Optional canonical full name (DB column: `full_name`).
  ///
  /// We keep `displayName` as the UI-facing name but also read/write `full_name`
  /// for compatibility with projects that rely on it.
  final String? fullName;
  final String? photoUrl;
  final String? bio;
  // Newer schema may use `profession` separate from `occupation`.
  final String? profession;
  final String? occupation;
  final String? countryOrOrigin;
  final String? contactPhone;
  final String? maritalStatus;
  final String? gender;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String? nationality;
  final String? address;
  final String? fatherName;
  final String? motherName;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;

  // Structured origin & residence.
  final String? originProvince;
  final String? originTerritory;
  final String? originSector;

  final String? residenceCountry;
  final String? residenceProvince;
  final String? residenceTerritory;
  final String? residenceCity;
  final String? residenceCommune;
  final String? residenceQuarter;
  final String? residenceAvenue;
  final String? residenceNumber;

  // Emergency contacts (multi-add).
  final List<Map<String, dynamic>> emergencyContacts;

  // Physical / identity information.
  final String? height;
  final String? weight;
  final String? bloodGroup;
  final bool? hasPhysicalDisability;
  final String? physicalDisabilityDescription;
  final String? nationalIdNumber;
  final String? idDocumentType;
  final String? idDocumentIssueDate;
  final String? idDocumentExpiryDate;
  final String? idDocumentIssuePlace;

  // National identity document media (stored as documents.doc_id references).
  final String? idDocumentFrontDocId;
  final String? idDocumentBackDocId;
  final String? idDocumentSelfieDocId;
  final String? idVerificationStatus;

  /// Free-form competence summary (DB column: `competence`).
  ///
  /// This is kept separate from `skills` (structured list) for compatibility
  /// with projects that store a single text field.
  final String? competence;

  /// Languages with level: [{"name": "Français", "level": "C1"}]
  final List<Map<String, dynamic>> languagesDetailed;

  /// Formations / trainings (multi-add).
  final List<Map<String, dynamic>> trainings;
  final String? thixChat;
  final List<String> languages;

  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> certifications;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> contacts;

  final ThixVisibilitySettings visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ThixProfile({
    required this.userId,
    required this.thixId,
    required this.displayName,
    required this.fullName,
    required this.photoUrl,
    required this.bio,
    required this.profession,
    required this.occupation,
    required this.countryOrOrigin,
    required this.contactPhone,
    required this.maritalStatus,
    required this.gender,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.nationality,
    required this.address,
    required this.fatherName,
    required this.motherName,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.emergencyContactRelation,
    required this.originProvince,
    required this.originTerritory,
    required this.originSector,
    required this.residenceCountry,
    required this.residenceProvince,
    required this.residenceTerritory,
    required this.residenceCity,
    required this.residenceCommune,
    required this.residenceQuarter,
    required this.residenceAvenue,
    required this.residenceNumber,
    required this.emergencyContacts,
    required this.height,
    required this.weight,
    required this.bloodGroup,
    required this.hasPhysicalDisability,
    required this.physicalDisabilityDescription,
    required this.nationalIdNumber,
    required this.idDocumentType,
    required this.idDocumentIssueDate,
    required this.idDocumentExpiryDate,
    required this.idDocumentIssuePlace,
    required this.idDocumentFrontDocId,
    required this.idDocumentBackDocId,
    required this.idDocumentSelfieDocId,
    required this.idVerificationStatus,
    required this.competence,
    required this.languagesDetailed,
    required this.trainings,
    required this.thixChat,
    required this.languages,
    required this.education,
    required this.experience,
    required this.skills,
    required this.certifications,
    required this.documents,
    required this.contacts,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convenience empty profile for screens that require a non-null object.
  factory ThixProfile.empty({required String userId}) {
    final now = DateTime.now();
    return ThixProfile(
      userId: userId,
      thixId: '',
      displayName: '',
      fullName: null,
      photoUrl: null,
      bio: null,
      profession: null,
      occupation: null,
      countryOrOrigin: null,
      contactPhone: null,
      maritalStatus: null,
      gender: null,
      dateOfBirth: null,
      placeOfBirth: null,
      nationality: null,
      address: null,
      fatherName: null,
      motherName: null,
      emergencyContactName: null,
      emergencyContactPhone: null,
      emergencyContactRelation: null,
      originProvince: null,
      originTerritory: null,
      originSector: null,
      residenceCountry: null,
      residenceProvince: null,
      residenceTerritory: null,
      residenceCity: null,
      residenceCommune: null,
      residenceQuarter: null,
      residenceAvenue: null,
      residenceNumber: null,
      emergencyContacts: const <Map<String, dynamic>>[],
      height: null,
      weight: null,
      bloodGroup: null,
      hasPhysicalDisability: null,
      physicalDisabilityDescription: null,
      nationalIdNumber: null,
      idDocumentType: null,
      idDocumentIssueDate: null,
      idDocumentExpiryDate: null,
      idDocumentIssuePlace: null,
      idDocumentFrontDocId: null,
      idDocumentBackDocId: null,
      idDocumentSelfieDocId: null,
      idVerificationStatus: null,
      competence: null,
      languagesDetailed: const <Map<String, dynamic>>[],
      trainings: const <Map<String, dynamic>>[],
      thixChat: null,
      languages: const <String>[],
      education: const <Map<String, dynamic>>[],
      experience: const <Map<String, dynamic>>[],
      skills: const <Map<String, dynamic>>[],
      certifications: const <Map<String, dynamic>>[],
      documents: const <Map<String, dynamic>>[],
      contacts: const <Map<String, dynamic>>[],
      visibility: const ThixVisibilitySettings(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ThixProfile.fallback({required String userId, required String thixId, required String displayName}) {
    final now = DateTime.now();
    return ThixProfile(
      userId: userId,
      thixId: thixId,
      displayName: displayName,
      fullName: displayName,
      photoUrl: null,
      bio: null,
      profession: null,
      occupation: null,
      countryOrOrigin: null,
      contactPhone: null,
      maritalStatus: null,
      gender: null,
      dateOfBirth: null,
      placeOfBirth: null,
      nationality: null,
      address: null,
      fatherName: null,
      motherName: null,
      emergencyContactName: null,
      emergencyContactPhone: null,
      emergencyContactRelation: null,
      originProvince: null,
      originTerritory: null,
      originSector: null,
      residenceCountry: null,
      residenceProvince: null,
      residenceTerritory: null,
      residenceCity: null,
      residenceCommune: null,
      residenceQuarter: null,
      residenceAvenue: null,
      residenceNumber: null,
      emergencyContacts: const [],
      height: null,
      weight: null,
      bloodGroup: null,
      hasPhysicalDisability: null,
      physicalDisabilityDescription: null,
      nationalIdNumber: null,
      idDocumentType: null,
      idDocumentIssueDate: null,
      idDocumentExpiryDate: null,
      idDocumentIssuePlace: null,
      idDocumentFrontDocId: null,
      idDocumentBackDocId: null,
      idDocumentSelfieDocId: null,
      idVerificationStatus: null,
      competence: null,
      languagesDetailed: const [],
      trainings: const [],
      thixChat: null,
      languages: const [],
      education: const [],
      experience: const [],
      skills: const [],
      certifications: const [],
      documents: const [],
      contacts: const [],
      visibility: const ThixVisibilitySettings(),
      createdAt: now,
      updatedAt: now,
    );
  }

  ThixProfile copyWith({
    String? displayName,
    String? fullName,
    String? photoUrl,
    String? bio,
    String? profession,
    String? occupation,
    String? countryOrOrigin,
    String? contactPhone,
    String? maritalStatus,
    String? gender,
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
    String? thixChat,
    List<String>? languages,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? skills,
    List<Map<String, dynamic>>? certifications,
    List<Map<String, dynamic>>? documents,
    List<Map<String, dynamic>>? contacts,
    ThixVisibilitySettings? visibility,
    DateTime? updatedAt,
  }) {
    return ThixProfile(
      userId: userId,
      thixId: thixId,
      displayName: displayName ?? this.displayName,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      profession: profession ?? this.profession,
      occupation: occupation ?? this.occupation,
      countryOrOrigin: countryOrOrigin ?? this.countryOrOrigin,
      contactPhone: contactPhone ?? this.contactPhone,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      nationality: nationality ?? this.nationality,
      address: address ?? this.address,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      originProvince: originProvince ?? this.originProvince,
      originTerritory: originTerritory ?? this.originTerritory,
      originSector: originSector ?? this.originSector,
      residenceCountry: residenceCountry ?? this.residenceCountry,
      residenceProvince: residenceProvince ?? this.residenceProvince,
      residenceTerritory: residenceTerritory ?? this.residenceTerritory,
      residenceCity: residenceCity ?? this.residenceCity,
      residenceCommune: residenceCommune ?? this.residenceCommune,
      residenceQuarter: residenceQuarter ?? this.residenceQuarter,
      residenceAvenue: residenceAvenue ?? this.residenceAvenue,
      residenceNumber: residenceNumber ?? this.residenceNumber,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      hasPhysicalDisability: hasPhysicalDisability ?? this.hasPhysicalDisability,
      physicalDisabilityDescription: physicalDisabilityDescription ?? this.physicalDisabilityDescription,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      idDocumentType: idDocumentType ?? this.idDocumentType,
      idDocumentIssueDate: idDocumentIssueDate ?? this.idDocumentIssueDate,
      idDocumentExpiryDate: idDocumentExpiryDate ?? this.idDocumentExpiryDate,
      idDocumentIssuePlace: idDocumentIssuePlace ?? this.idDocumentIssuePlace,
      idDocumentFrontDocId: idDocumentFrontDocId ?? this.idDocumentFrontDocId,
      idDocumentBackDocId: idDocumentBackDocId ?? this.idDocumentBackDocId,
      idDocumentSelfieDocId: idDocumentSelfieDocId ?? this.idDocumentSelfieDocId,
      idVerificationStatus: idVerificationStatus ?? this.idVerificationStatus,
      competence: competence ?? this.competence,
      languagesDetailed: languagesDetailed ?? this.languagesDetailed,
      trainings: trainings ?? this.trainings,
      thixChat: thixChat ?? this.thixChat,
      languages: languages ?? this.languages,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
      certifications: certifications ?? this.certifications,
      documents: documents ?? this.documents,
      contacts: contacts ?? this.contacts,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toPrivateRowJson() {
    return {
      // Canonical key for `public.profiles`.
      'id': userId,
      'thix_id': thixId,
      'display_name': displayName,
      'full_name': (fullName ?? displayName).trim().isEmpty ? displayName : (fullName ?? displayName),
      'avatar_url': photoUrl,
      'bio': bio,
      'profession': profession,
      'occupation': occupation,
      'country_or_origin': countryOrOrigin,
      'contact_phone': contactPhone,
      'marital_status': maritalStatus,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'place_of_birth': placeOfBirth,
      'nationality': nationality,
      'address': address,
      'father_name': fatherName,
      'mother_name': motherName,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'emergency_contact_relation': emergencyContactRelation,
      'origin_province': originProvince,
      'origin_territory': originTerritory,
      'origin_sector': originSector,
      'residence_country': residenceCountry,
      'residence_province': residenceProvince,
      'residence_territory': residenceTerritory,
      'residence_city': residenceCity,
      'residence_commune': residenceCommune,
      'residence_quarter': residenceQuarter,
      'residence_avenue': residenceAvenue,
      'residence_number': residenceNumber,
      'emergency_contacts': emergencyContacts,
      'height': height,
      'weight': weight,
      'blood_group': bloodGroup,
      'has_physical_disability': hasPhysicalDisability,
      'physical_disability_description': physicalDisabilityDescription,
      'national_id_number': nationalIdNumber,
      'id_document_type': idDocumentType,
      'id_document_issue_date': idDocumentIssueDate,
      'id_document_expiry_date': idDocumentExpiryDate,
      'id_document_issue_place': idDocumentIssuePlace,
      'id_document_front_doc_id': idDocumentFrontDocId,
      'id_document_back_doc_id': idDocumentBackDocId,
      'id_document_selfie_doc_id': idDocumentSelfieDocId,
      'id_verification_status': idVerificationStatus,
      'competence': competence,
      'languages_detailed': languagesDetailed,
      'trainings': trainings,
      'thix_chat': thixChat,
      'languages': languages,
      'education': education,
      'experience': experience,
      'skills': skills,
      'certifications': certifications,
      'documents': documents,
      'contacts': contacts,
      'visibility_settings': visibility.toJson(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static ThixProfile fromPrivateRow(Map<String, dynamic> row) {
    final createdAt = _parseDate(row['created_at']) ?? DateTime.now();
    final updatedAt = _parseDate(row['updated_at']) ?? createdAt;
    final fullName = (row['full_name'] ?? row['fullName'])?.toString();
    final displayName = ((row['display_name'] ?? row['displayName'])?.toString() ?? '').trim();
    final effectiveName = (fullName ?? '').trim().isNotEmpty ? fullName!.trim() : displayName;

    List<String> readLanguagesFallback() {
      final list = ((row['languages'] as List?) ?? const []).whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
      if (list.isNotEmpty) return list;
      final detailed = _readJsonList(row['languages_detailed']);
      return detailed.map((e) => (e['name'] ?? e['language'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
    }

    String? readAlias(List<String> keys) {
      for (final k in keys) {
        final v = row[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    return ThixProfile(
      userId: (row['id'] as String?) ?? (row['user_id'] as String?) ?? '',
      thixId: (row['thix_id'] as String?) ?? '',
      displayName: effectiveName,
      fullName: fullName,
      photoUrl: (row['avatar_url'] ?? row['photo_url']) as String?,
      bio: row['bio'] as String?,
      profession: (row['profession'] ?? row['job_title'])?.toString(),
      occupation: (row['occupation'] ?? row['occupation_title'])?.toString(),
      countryOrOrigin: row['country_or_origin'] as String?,
      contactPhone: row['contact_phone']?.toString(),
      maritalStatus: row['marital_status']?.toString(),
      gender: row['gender']?.toString(),
      dateOfBirth: row['date_of_birth']?.toString(),
      placeOfBirth: row['place_of_birth']?.toString(),
      nationality: row['nationality']?.toString(),
      address: row['address']?.toString(),
      fatherName: row['father_name']?.toString(),
      motherName: row['mother_name']?.toString(),
      emergencyContactName: row['emergency_contact_name']?.toString(),
      emergencyContactPhone: row['emergency_contact_phone']?.toString(),
      emergencyContactRelation: row['emergency_contact_relation']?.toString(),
      originProvince: readAlias(['origin_province', 'province_origine']),
      originTerritory: readAlias(['origin_territory', 'territoire_origine']),
      originSector: readAlias(['origin_sector', 'secteur_origine']),
      residenceCountry: readAlias(['residence_country', 'pays_residence', 'current_residence_country']),
      residenceProvince: readAlias(['residence_province', 'province_residence']),
      residenceTerritory: readAlias(['residence_territory', 'territoire_residence']),
      residenceCity: readAlias(['residence_city', 'ville_residence']),
      residenceCommune: readAlias(['residence_commune', 'commune_residence']),
      residenceQuarter: readAlias(['residence_quarter', 'quartier_residence']),
      residenceAvenue: readAlias(['residence_avenue', 'avenue_residence']),
      residenceNumber: readAlias(['residence_number', 'numero_residence']),
      emergencyContacts: _readJsonList(row['emergency_contacts']),
      height: row['height']?.toString(),
      weight: row['weight']?.toString(),
      bloodGroup: row['blood_group']?.toString(),
      hasPhysicalDisability: row['has_physical_disability'] as bool?,
      physicalDisabilityDescription: row['physical_disability_description']?.toString(),
      nationalIdNumber: row['national_id_number']?.toString(),
      idDocumentType: row['id_document_type']?.toString(),
      idDocumentIssueDate: row['id_document_issue_date']?.toString(),
      idDocumentExpiryDate: row['id_document_expiry_date']?.toString(),
      idDocumentIssuePlace: row['id_document_issue_place']?.toString(),
      idDocumentFrontDocId: row['id_document_front_doc_id']?.toString(),
      idDocumentBackDocId: row['id_document_back_doc_id']?.toString(),
      idDocumentSelfieDocId: row['id_document_selfie_doc_id']?.toString(),
      idVerificationStatus: row['id_verification_status']?.toString(),
      competence: row['competence']?.toString(),
      languagesDetailed: _readJsonList(row['languages_detailed']),
      trainings: _readJsonList(row['trainings']),
      thixChat: row['thix_chat'] as String?,
      languages: readLanguagesFallback(),
      education: _readJsonList(row['education']),
      experience: _readJsonList(row['experience']),
      skills: _readJsonList(row['skills']),
      certifications: _readJsonList(row['certifications']),
      documents: _readJsonList(row['documents']),
      contacts: _readJsonList(row['contacts']),
      visibility: ThixVisibilitySettings.fromJson((row['visibility_settings'] as Map?)?.cast<String, dynamic>()),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static List<Map<String, dynamic>> _readJsonList(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
        }
      } catch (_) {}
    }
    return const [];
  }

  static DateTime? _parseDate(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
