// lib/model/app_user.dart
import 'dart:convert';
import 'account_type.dart';
export 'account_type.dart';

class AppUser {
  final String id;
  final String thixId;
  final String thixChat;
  final int? thixScore;
  final String email;
  final String? phone;
  final String displayName;
  final AccountType accountType;
  final String? photoUrl;
  final String? bio;
  final String? countryOrOrigin;
  final String? contactPhone;
  final String? maritalStatus;
  final String? gender;
  final String? occupation;
  final String? profession;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String? nationality;
  final String? address;
  final String? fatherName;
  final String? motherName;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;
  final String? registrationStatus;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> enrollments;
  final List<String> languages;
  final bool biometricsEnabled;
  final bool twoFaEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String passwordSaltB64;
  final String passwordHashHex;

  const AppUser({
    required this.id,
    required this.thixId,
    required this.thixChat,
    required this.thixScore,
    required this.email,
    required this.phone,
    required this.displayName,
    required this.accountType,
    required this.photoUrl,
    required this.bio,
    required this.countryOrOrigin,
    this.contactPhone,
    this.maritalStatus,
    this.gender,
    this.occupation,
    this.profession,
    this.dateOfBirth,
    this.placeOfBirth,
    this.nationality,
    this.address,
    this.fatherName,
    this.motherName,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
    this.registrationStatus,
    required this.education,
    required this.experience,
    required this.skills,
    required this.enrollments,
    required this.languages,
    required this.biometricsEnabled,
    required this.twoFaEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.passwordSaltB64 = '',
    this.passwordHashHex = '',
  });

  // ====== TES FACTORY EXISTANTES - GARDÉES ======
  factory AppUser.firebase({required String uid, required String? email, required String? phone}) {
    final now = DateTime.now();
    return AppUser(
      id: uid, thixId: 'THIX-000000', thixChat: '', thixScore: null,
      email: (email ?? '').toLowerCase(), phone: phone, displayName: 'Utilisateur THIX',
      accountType: AccountType.personal, photoUrl: null, bio: null, countryOrOrigin: null,
      contactPhone: phone, maritalStatus: null, gender: null, occupation: null, profession: null,
      dateOfBirth: null, placeOfBirth: null, nationality: null, address: null,
      fatherName: null, motherName: null, emergencyContactName: null, emergencyContactPhone: null, emergencyContactRelation: null,
      registrationStatus: null, education: const [], experience: const [], skills: const [], enrollments: const [], languages: const [],
      biometricsEnabled: true, twoFaEnabled: false, createdAt: now, updatedAt: now,
    );
  }

  // ====== NOUVEAU - SCALABLE POUR MILLIONS - SUPABASE FIRST ======
  static AppUser fromSupabase(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _parseMapList(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
      return const [];
    }
    return AppUser(
      id: json['id'] as String,
      thixId: json['thix_id'] ?? json['thixId'] ?? 'THIX-PENDING',
      thixChat: json['thix_chat'] ?? json['thixChat'] ?? '',
      thixScore: (json['thix_score'] ?? json['thixScore']) as int?,
      email: (json['email'] ?? '').toString().toLowerCase(),
      phone: json['phone'] as String?,
      displayName: json['display_name'] ?? json['displayName'] ?? 'Utilisateur THIX',
      accountType: AccountType.personal,
      photoUrl: json['photo_url'] ?? json['photoUrl'],
      bio: json['bio'],
      countryOrOrigin: json['country_or_origin'] ?? json['countryOrOrigin'],
      contactPhone: json['contact_phone'] ?? json['contactPhone'],
      maritalStatus: json['marital_status'] ?? json['maritalStatus'],
      gender: json['gender'],
      occupation: json['occupation'],
      profession: json['profession'],
      dateOfBirth: json['date_of_birth'] ?? json['dateOfBirth'],
      placeOfBirth: json['place_of_birth'] ?? json['placeOfBirth'],
      nationality: json['nationality'],
      address: json['address'],
      fatherName: json['father_name'] ?? json['fatherName'],
      motherName: json['mother_name'] ?? json['motherName'],
      emergencyContactName: json['emergency_contact_name'] ?? json['emergencyContactName'],
      emergencyContactPhone: json['emergency_contact_phone'] ?? json['emergencyContactPhone'],
      emergencyContactRelation: json['emergency_contact_relation'] ?? json['emergencyContactRelation'],
      registrationStatus: json['registration_status'] ?? json['registrationStatus'] ?? json['role'],
      education: _parseMapList(json['education']),
      experience: _parseMapList(json['experience']),
      skills: _parseMapList(json['skills']),
      enrollments: _parseMapList(json['enrollments']),
      languages: ((json['languages'] as List?) ?? const []).whereType<String>().toList(growable: false),
      biometricsEnabled: (json['biometrics_enabled'] ?? json['biometricsEnabled'] ?? true) as bool,
      twoFaEnabled: (json['two_fa_enabled'] ?? json['twoFaEnabled'] ?? false) as bool,
      createdAt: _readDate(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(json['updated_at'] ?? json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'thix_id': thixId,
      'thix_chat': thixChat,
      'thix_score': thixScore,
      'email': email,
      'phone': phone,
      'display_name': displayName,
      'photo_url': photoUrl,
      'bio': bio,
      'registration_status': registrationStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // ====== TES MÉTHODES EXISTANTES - GARDÉES 100% ======
  AppUser copyWith({
    String? id, String? thixId, String? thixChat, int? thixScore, String? email, String? phone,
    String? displayName, AccountType? accountType, String? photoUrl, String? bio, String? countryOrOrigin,
    String? contactPhone, String? maritalStatus, String? gender, String? occupation, String? profession,
    String? dateOfBirth, String? placeOfBirth, String? nationality, String? address,
    String? fatherName, String? motherName, String? emergencyContactName, String? emergencyContactPhone, String? emergencyContactRelation,
    String? registrationStatus, List<Map<String, dynamic>>? education, List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? skills, List<Map<String, dynamic>>? enrollments, List<String>? languages,
    bool? biometricsEnabled, bool? twoFaEnabled, DateTime? createdAt, DateTime? updatedAt,
    String? passwordSaltB64, String? passwordHashHex,
  }) {
    return AppUser(
      id: id ?? this.id, thixId: thixId ?? this.thixId, thixChat: thixChat ?? this.thixChat,
      thixScore: thixScore ?? this.thixScore, email: email ?? this.email, phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName, accountType: accountType ?? this.accountType,
      photoUrl: photoUrl ?? this.photoUrl, bio: bio ?? this.bio, countryOrOrigin: countryOrOrigin ?? this.countryOrOrigin,
      contactPhone: contactPhone ?? this.contactPhone, maritalStatus: maritalStatus ?? this.maritalStatus,
      gender: gender ?? this.gender, occupation: occupation ?? this.occupation, profession: profession ?? this.profession,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth, placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      nationality: nationality ?? this.nationality, address: address ?? this.address,
      fatherName: fatherName ?? this.fatherName, motherName: motherName ?? this.motherName,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      education: education ?? this.education, experience: experience ?? this.experience,
      skills: skills ?? this.skills, enrollments: enrollments ?? this.enrollments, languages: languages ?? this.languages,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled, twoFaEnabled: twoFaEnabled ?? this.twoFaEnabled,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      passwordSaltB64: passwordSaltB64 ?? this.passwordSaltB64, passwordHashHex: passwordHashHex ?? this.passwordHashHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, 'thixId': thixId, 'thixChat': thixChat, 'thixScore': thixScore,
      'email': email, 'phone': phone, 'displayName': displayName, 'accountType': accountType.name,
      'photoUrl': photoUrl, 'bio': bio, 'countryOrOrigin': countryOrOrigin,
      'contactPhone': contactPhone, 'maritalStatus': maritalStatus, 'gender': gender,
      'occupation': occupation, 'profession': profession, 'dateOfBirth': dateOfBirth,
      'placeOfBirth': placeOfBirth, 'nationality': nationality, 'address': address,
      'fatherName': fatherName, 'motherName': motherName,
      'emergencyContactName': emergencyContactName, 'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelation': emergencyContactRelation, 'registrationStatus': registrationStatus,
      'education': education, 'experience': experience, 'skills': skills, 'enrollments': enrollments,
      'languages': languages, 'biometricsEnabled': biometricsEnabled, 'twoFaEnabled': twoFaEnabled,
      'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(),
      'passwordSaltB64': passwordSaltB64, 'passwordHashHex': passwordHashHex,
    };
  }

  static AppUser fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String, thixId: json['thixId'] as String, thixChat: (json['thixChat'] as String?) ?? '',
      thixScore: (json['thixScore'] as num?)?.toInt(), email: json['email'] as String, phone: json['phone'] as String?,
      displayName: json['displayName'] as String, accountType: AccountType.values.firstWhere((e) => e.name == (json['accountType'] as String)),
      photoUrl: json['photoUrl'] as String?, bio: json['bio'] as String?, countryOrOrigin: json['countryOrOrigin'] as String?,
      contactPhone: json['contactPhone'] as String?, maritalStatus: json['maritalStatus'] as String?,
      gender: json['gender'] as String?, occupation: json['occupation'] as String?, profession: json['profession'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?, placeOfBirth: json['placeOfBirth'] as String?,
      nationality: json['nationality'] as String?, address: json['address'] as String?,
      fatherName: json['fatherName'] as String?, motherName: json['motherName'] as String?,
      emergencyContactName: json['emergencyContactName'] as String?, emergencyContactPhone: json['emergencyContactPhone'] as String?,
      emergencyContactRelation: json['emergencyContactRelation'] as String?,
      registrationStatus: json['registrationStatus'] as String?,
      education: ((json['education'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      experience: ((json['experience'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      skills: ((json['skills'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      enrollments: ((json['enrollments'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      languages: ((json['languages'] as List?) ?? const []).whereType<String>().toList(growable: false),
      biometricsEnabled: (json['biometricsEnabled'] as bool?) ?? true, twoFaEnabled: (json['twoFaEnabled'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String), updatedAt: DateTime.parse(json['updatedAt'] as String),
      passwordSaltB64: (json['passwordSaltB64'] as String?) ?? '', passwordHashHex: (json['passwordHashHex'] as String?) ?? '',
    );
  }

  static DateTime? _readDate(Object? v) {
    try { final dyn = v as dynamic; final maybe = dyn?.toDate(); if (maybe is DateTime) return maybe; } catch (_) {}
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static List<AppUser> decodeList(String raw) {
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(AppUser.fromJson).toList(growable: false);
  }

  static String encodeList(List<AppUser> users) => jsonEncode(users.map((u) => u.toJson()).toList(growable: false));

  bool get hasActiveTrial {
    final raw = (registrationStatus ?? '').trim();
    if (!raw.toLowerCase().startsWith('trial_until:')) return false;
    final iso = raw.substring('trial_until:'.length).trim();
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    return dt.isAfter(DateTime.now().toUtc());
  }

  bool get hasRealThixId {
    final v = thixId.trim().toUpperCase();
    return v.isNotEmpty && v != 'THIX-PENDING' && v != 'THIX-000000';
  }

  String? get role {
    final status = (registrationStatus ?? '').trim().toLowerCase();
    if (status == 'admin') return 'admin';
    if (status == 'moderateur' || status == 'moderator') return 'moderateur';
    final occ = (occupation ?? '').trim().toLowerCase();
    if (occ == 'admin') return 'admin';
    if (occ == 'moderateur' || occ == 'moderator') return 'moderateur';
    return null;
  }
}

class DocumentSnapshot {}
