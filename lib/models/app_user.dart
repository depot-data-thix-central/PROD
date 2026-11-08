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

  final String? _certificationTier;
  final String? _certificationStatus;
  final String? _accountStatus;
  final DateTime? _scheduledDeletionAt;

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
    String? certificationTier,
    String? certificationStatus,
    String? accountStatus,
    DateTime? scheduledDeletionAt,
  })  : _certificationTier = certificationTier,
        _certificationStatus = certificationStatus,
        _accountStatus = accountStatus,
        _scheduledDeletionAt = scheduledDeletionAt;

  String? get avatarUrl => photoUrl;
  String? get certificationTier => _certificationTier;
  String? get certificationStatus => _certificationStatus;
  String? get accountStatus => _accountStatus;
  DateTime? get scheduledDeletionAt => _scheduledDeletionAt;
  bool get isPendingDeletion => _accountStatus == 'pending_deletion';
  bool get isDeactivated => _accountStatus == 'deactivated';

  // ====== FACTORY FIREBASE ======
  factory AppUser.firebase({required String uid, required String? email, required String? phone}) {
    final now = DateTime.now();
    return AppUser(
      id: uid, thixId: 'THIX-000000', thixChat: '', thixScore: null,
      email: (email ?? '').toLowerCase(), phone: phone, displayName: 'Utilisateur THIX',
      accountType: AccountType.personal, photoUrl: null, bio: null, countryOrOrigin: null,
      contactPhone: phone, education: const [], experience: const [], skills: const [],
      enrollments: const [], languages: const [], biometricsEnabled: true, twoFaEnabled: false,
      createdAt: now, updatedAt: now, accountStatus: 'active',
    );
  }

  // ====== FROM SUPABASE ======
  static AppUser fromSupabase(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _parseMapList(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
      return const [];
    }
    return AppUser(
      id: (json['id'] ?? '').toString(),
      thixId: (json['thix_id'] ?? json['thixId'] ?? 'THIX-PENDING').toString(),
      thixChat: (json['thix_chat'] ?? json['thixChat'] ?? '').toString(),
      thixScore: (json['thix_score'] ?? json['thixScore']) as int?,
      email: (json['email'] ?? '').toString().toLowerCase(),
      phone: json['phone'] as String?,
      displayName: (json['display_name'] ?? json['displayName'] ?? 'Utilisateur THIX').toString(),
      accountType: AccountType.personal,
      photoUrl: (json['photo_url'] ?? json['photoUrl']) as String?,
      bio: json['bio'] as String?,
      countryOrOrigin: (json['country_or_origin'] ?? json['countryOrOrigin']) as String?,
      contactPhone: (json['contact_phone'] ?? json['contactPhone']) as String?,
      maritalStatus: json['marital_status'] as String? ?? json['maritalStatus'] as String?,
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String?,
      profession: json['profession'] as String?,
      dateOfBirth: (json['date_of_birth'] ?? json['dateOfBirth']) as String?,
      placeOfBirth: (json['place_of_birth'] ?? json['placeOfBirth']) as String?,
      nationality: json['nationality'] as String?,
      address: json['address'] as String?,
      fatherName: (json['father_name'] ?? json['fatherName']) as String?,
      motherName: (json['mother_name'] ?? json['motherName']) as String?,
      emergencyContactName: (json['emergency_contact_name'] ?? json['emergencyContactName']) as String?,
      emergencyContactPhone: (json['emergency_contact_phone'] ?? json['emergencyContactPhone']) as String?,
      emergencyContactRelation: (json['emergency_contact_relation'] ?? json['emergencyContactRelation']) as String?,
      registrationStatus: (json['registration_status'] ?? json['registrationStatus'] ?? json['role']) as String?,
      education: _parseMapList(json['education']),
      experience: _parseMapList(json['experience']),
      skills: _parseMapList(json['skills']),
      enrollments: _parseMapList(json['enrollments']),
      languages: ((json['languages'] as List?) ?? const <String>[]).whereType<String>().toList(growable: false),
      biometricsEnabled: (json['biometrics_enabled'] ?? json['biometricsEnabled'] ?? true) as bool,
      twoFaEnabled: (json['two_fa_enabled'] ?? json['twoFaEnabled'] ?? false) as bool,
      createdAt: _readDate(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(json['updated_at'] ?? json['updatedAt']) ?? DateTime.now(),
      certificationTier: (json['certification_tier'] ?? json['certificationTier'])?.toString(),
      certificationStatus: (json['certification_status'] ?? json['certificationStatus'])?.toString(),
      accountStatus: (json['status'] ?? 'active').toString(),
      scheduledDeletionAt: _readDate(json['scheduled_deletion_at'] ?? json['scheduledDeletionAt']),
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
      'certification_tier': _certificationTier,
      'certification_status': _certificationStatus,
      'status': _accountStatus,
      'scheduled_deletion_at': _scheduledDeletionAt?.toIso8601String(),
    };
  }

  // ====== COPYWITH ======
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
    String? certificationTier, String? certificationStatus,
    String? accountStatus, DateTime? scheduledDeletionAt,
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
      certificationTier: certificationTier ?? _certificationTier,
      certificationStatus: certificationStatus ?? _certificationStatus,
      accountStatus: accountStatus ?? _accountStatus,
      scheduledDeletionAt: scheduledDeletionAt ?? _scheduledDeletionAt,
    );
  }

  // ✅ FIX SÉCURITÉ : toJson() n'inclut PLUS passwordSaltB64 / passwordHashHex
  // (ce sont des secrets qui ne doivent pas être persistés en clair dans Hive).
  // Le snapshot Hive sert à restaurer l'état UI, pas les credentials.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thixId': thixId,
      'thixChat': thixChat,
      'thixScore': thixScore,
      'email': email,
      'phone': phone,
      'displayName': displayName,
      'accountType': accountType.name,
      'photoUrl': photoUrl,
      'bio': bio,
      'countryOrOrigin': countryOrOrigin,
      'contactPhone': contactPhone,
      'maritalStatus': maritalStatus,
      'gender': gender,
      'occupation': occupation,
      'profession': profession,
      'dateOfBirth': dateOfBirth,
      'placeOfBirth': placeOfBirth,
      'nationality': nationality,
      'address': address,
      'fatherName': fatherName,
      'motherName': motherName,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelation': emergencyContactRelation,
      'registrationStatus': registrationStatus,
      'education': education,
      'experience': experience,
      'skills': skills,
      'enrollments': enrollments,
      'languages': languages,
      'biometricsEnabled': biometricsEnabled,
      'twoFaEnabled': twoFaEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'certificationTier': _certificationTier,
      'certificationStatus': _certificationStatus,
      'accountStatus': _accountStatus,
      'scheduledDeletionAt': _scheduledDeletionAt?.toIso8601String(),
    };
  }

  // ✅ FIX ROBUSTESSE : fromJson() tolère des snapshots Hive partiels ou anciens
  // (aucun cast `as String` en dur → valeurs par défaut si absent).
  static AppUser fromJson(Map<String, dynamic> json) {
    String? _str(Object? v) => v?.toString();
    final now = DateTime.now();

    List<Map<String, dynamic>> _parseMapList(dynamic v) {
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
      }
      return const <Map<String, dynamic>>[];
    }

    List<String> _parseStringList(dynamic v) {
      if (v is List) return v.whereType<String>().toList(growable: false);
      return const <String>[];
    }

    AccountType accountType;
    try {
      final raw = json['accountType']?.toString() ?? '';
      accountType = AccountType.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => AccountType.personal,
      );
    } catch (_) {
      accountType = AccountType.personal;
    }

    return AppUser(
      id: _str(json['id']) ?? '',
      thixId: _str(json['thixId']) ?? 'THIX-PENDING',
      thixChat: _str(json['thixChat']) ?? '',
      thixScore: (json['thixScore'] as num?)?.toInt(),
      email: _str(json['email']) ?? '',
      phone: _str(json['phone']),
      displayName: _str(json['displayName']) ?? 'Utilisateur THIX',
      accountType: accountType,
      photoUrl: _str(json['photoUrl']),
      bio: _str(json['bio']),
      countryOrOrigin: _str(json['countryOrOrigin']),
      contactPhone: _str(json['contactPhone']),
      maritalStatus: _str(json['maritalStatus']),
      gender: _str(json['gender']),
      occupation: _str(json['occupation']),
      profession: _str(json['profession']),
      dateOfBirth: _str(json['dateOfBirth']),
      placeOfBirth: _str(json['placeOfBirth']),
      nationality: _str(json['nationality']),
      address: _str(json['address']),
      fatherName: _str(json['fatherName']),
      motherName: _str(json['motherName']),
      emergencyContactName: _str(json['emergencyContactName']),
      emergencyContactPhone: _str(json['emergencyContactPhone']),
      emergencyContactRelation: _str(json['emergencyContactRelation']),
      registrationStatus: _str(json['registrationStatus']),
      education: _parseMapList(json['education']),
      experience: _parseMapList(json['experience']),
      skills: _parseMapList(json['skills']),
      enrollments: _parseMapList(json['enrollments']),
      languages: _parseStringList(json['languages']),
      biometricsEnabled: (json['biometricsEnabled'] as bool?) ?? true,
      twoFaEnabled: (json['twoFaEnabled'] as bool?) ?? false,
      createdAt: _readDate(json['createdAt']) ?? now,
      updatedAt: _readDate(json['updatedAt']) ?? now,
      certificationTier: _str(json['certificationTier']),
      certificationStatus: _str(json['certificationStatus']),
      accountStatus: _str(json['accountStatus']) ?? 'active',
      scheduledDeletionAt: _readDate(json['scheduledDeletionAt']),
      // ✅ FIX SÉCURITÉ : les credentials ne sont pas restaurés du snapshot.
      passwordSaltB64: '',
      passwordHashHex: '',
    );
  }

  // ✅ FIX : _readDate ne dépend plus de Firestore (.toDate())
  static DateTime? _readDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }
    if (v is num) {
      // Timestamp millisecondes (parfois vu dans certains exports)
      try {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: false);
      } catch (_) {}
    }
    return null;
  }

  static List<AppUser> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final list = decoded.cast<Map<String, dynamic>>();
    return list.map(AppUser.fromJson).toList(growable: false);
  }

  static String encodeList(List<AppUser> users) =>
      jsonEncode(users.map((u) => u.toJson()).toList(growable: false));

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
