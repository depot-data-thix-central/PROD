/// ============================================================================
/// AgencyModel
/// ============================================================================
///
/// Représentation d'une agence de transport dans le système THIX.
///
/// Utilisée pour :
/// - Multi-tenant SaaS (chaque agence = tenant isolé)
/// - Affichage dans les cartes de trajets
/// - Vérification de statut (active/pending/suspended)
/// - Dashboard agence
///
/// Features :
/// - Enum AgencyStatus type-safe
/// - Parsing JSON robuste (gestion null, types incorrects)
/// - Serialization bidirectionnelle (toJson/fromJson)
/// - Égalité structurelle (== et hashCode)
/// - CopyWith pour modifications immuables
/// - Getters utilitaires (displayName, initials, verification)
/// - Validation des champs
/// - Support logo/image
///
/// ============================================================================
class AgencyModel {
  // ─── Identifiants ─────────────────────────────────────────
  final String id;
  final String ownerId;
  final String name;
  final String countryCode;

  // ─── Informations ─────────────────────────────────────────
  final String? description;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? address;

  // ─── État ─────────────────────────────────────────────────
  final AgencyStatus status;
  final bool isVerified;

  // ─── Métadonnées ──────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? totalTrips;
  final int? totalBookings;
  final double? rating;

  const AgencyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.countryCode,
    this.description,
    this.logoUrl,
    this.phone,
    this.email,
    this.address,
    this.status = AgencyStatus.pending,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.totalTrips,
    this.totalBookings,
    this.rating,
  });

  // ─── Factory from JSON ────────────────────────────────────
  factory AgencyModel.fromJson(Map<String, dynamic> json) {
    return AgencyModel(
      id: (json['id'] as String?) ?? '',
      ownerId: (json['owner_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Agence',
      countryCode: ((json['country_code'] as String?) ?? 
                    (json['countryCode'] as String?) ?? 
                    '').toUpperCase(),
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String? ?? json['logoUrl'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      status: AgencyStatus.fromString(json['status'] as String?),
      isVerified: _parseBoolSafe(json['is_verified'] ?? json['isVerified']),
      createdAt: _parseDateTimeSafe(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTimeSafe(json['updated_at'] ?? json['updatedAt']),
      totalTrips: _parseIntSafe(json['total_trips']),
      totalBookings: _parseIntSafe(json['total_bookings']),
      rating: _parseDoubleSafe(json['rating']),
    );
  }

  // ─── Serialization to JSON ────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'country_code': countryCode,
      if (description != null) 'description': description,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      'status': status.value,
      'is_verified': isVerified,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (totalTrips != null) 'total_trips': totalTrips,
      if (totalBookings != null) 'total_bookings': totalBookings,
      if (rating != null) 'rating': rating,
    };
  }

  // ─── CopyWith ─────────────────────────────────────────────
  AgencyModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? countryCode,
    String? description,
    String? logoUrl,
    String? phone,
    String? email,
    String? address,
    AgencyStatus? status,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalTrips,
    int? totalBookings,
    double? rating,
    bool clearDescription = false,
    bool clearLogoUrl = false,
    bool clearPhone = false,
    bool clearEmail = false,
    bool clearAddress = false,
  }) {
    return AgencyModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      description: clearDescription ? null : (description ?? this.description),
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      phone: clearPhone ? null : (phone ?? this.phone),
      email: clearEmail ? null : (email ?? this.email),
      address: clearAddress ? null : (address ?? this.address),
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalTrips: totalTrips ?? this.totalTrips,
      totalBookings: totalBookings ?? this.totalBookings,
      rating: rating ?? this.rating,
    );
  }

  // ─── Getters d'état ───────────────────────────────────────
  bool get isActive => status == AgencyStatus.active;
  bool get isPending => status == AgencyStatus.pending;
  bool get isSuspended => status == AgencyStatus.suspended;
  bool get isRejected => status == AgencyStatus.rejected;

  bool get canCreateTrips => isActive && !isSuspended;
  bool get canReceiveBookings => isActive && isVerified;

  // ─── Getters utilitaires ──────────────────────────────────

  /// Nom formaté pour affichage
  String get displayName {
    if (countryCode.isEmpty) return name;
    return '$name ($countryCode)';
  }

  /// Initiales pour avatar (2 lettres max)
  String get initials {
    if (name.isEmpty) return 'A';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].substring(0, words[0].length > 2 ? 2 : 1).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Drapeau emoji du pays
  String get flag {
    if (countryCode.isEmpty || countryCode.length != 2) return '🏢';
    final code = countryCode.toUpperCase();
    final base = 0x1F1E6;
    final first = base + (code.codeUnitAt(0) - 65);
    final second = base + (code.codeUnitAt(1) - 65);
    return String.fromCharCodes([first, second]);
  }

  /// L'agence a-t-elle un logo ?
  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  /// L'agence a-t-elle des coordonnées ?
  bool get hasContact => phone != null || email != null;

  /// Rating formaté (ex: "4.5/5")
  String get ratingLabel => rating != null ? '${rating!.toStringAsFixed(1)}/5' : 'N/A';

  /// L'agence est-elle valide ?
  bool get isValid =>
      id.isNotEmpty &&
      name.isNotEmpty &&
      countryCode.length == 2;

  // ─── Égalité et hash ──────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgencyModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownerId == other.ownerId &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, ownerId, name);

  @override
  String toString() {
    return 'AgencyModel($name, $countryCode, ${status.value}${isVerified ? ", verified" : ""})';
  }

  // ─── Helpers de parsing ───────────────────────────────────
  static bool _parseBoolSafe(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDoubleSafe(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTimeSafe(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// ============================================================================
/// AgencyStatus — Enum des statuts d'agence
/// ============================================================================
enum AgencyStatus {
  active('active'),
  pending('pending'),
  suspended('suspended'),
  rejected('rejected');

  final String value;
  const AgencyStatus(this.value);

  static AgencyStatus fromString(String? value) {
    if (value == null) return AgencyStatus.pending;
    final lower = value.toLowerCase();
    return AgencyStatus.values.firstWhere(
      (s) => s.value == lower,
      orElse: () => AgencyStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case AgencyStatus.active:
        return 'Active';
      case AgencyStatus.pending:
        return 'En attente';
      case AgencyStatus.suspended:
        return 'Suspendue';
      case AgencyStatus.rejected:
        return 'Refusée';
    }
  }

  String get colorHex {
    switch (this) {
      case AgencyStatus.active:
        return '#10B981';
      case AgencyStatus.pending:
        return '#F59E0B';
      case AgencyStatus.suspended:
        return '#6B7280';
      case AgencyStatus.rejected:
        return '#EF4444';
    }
  }
}
