// lib/presentation/thix_weeding/models/provider_models.dart
// ============================================================================
// THIX WEDDING PROVIDER MODELS
// ✅ FIX : userId rendu nullable (String?) dans fromJson
// ============================================================================

import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════
enum ProviderCategory {
  salle('Salle de réception', 'SALLE'),
  traiteur('Traiteur', 'TRAITEUR'),
  photographe('Photographe', 'PHOTO'),
  videaste('Vidéaste', 'VIDEO'),
  decorateur('Décorateur', 'DECOR'),
  dj('DJ / Sonorisation', 'DJ'),
  mc('MC / Animateur', 'MC'),
  maquilleur('Maquilleur / Coiffeur', 'MAQUILLAGE'),
  patissier('Pâtissier', 'PATISSIER'),
  fleuriste('Fleuriste', 'FLEURISTE');

  final String displayName;
  final String iconCode;
  
  const ProviderCategory(this.displayName, this.iconCode);
}

enum TrackingLevel {
  bronze('Bronze', 1),
  silver('Argent', 2),
  gold('Or', 3),
  platinum('Platinum', 4);

  final String displayName;
  final int priority;
  
  const TrackingLevel(this.displayName, this.priority);
}

enum ProviderVerificationStatus {
  pending,
  verified,
  rejected;
}

enum ReservationStatus {
  pending,
  confirmed,
  cancelled,
  completed;
}

enum TaskStatus {
  assigned,
  inProgress,
  completed,
  cancelled;
}

// ═══════════════════════════════════════════════════════════════════════════
// THIX PROVIDER MODEL
// ══════════════════════════════════════════════════════════════════════════
@immutable
class ThixProviderModel {
  final String id;
  final String? userId; // ✅ RENDU NULLABLE
  final String uniqueCode;
  final ProviderCategory category;
  final String businessName;
  final String? description;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final List<String> galleryUrls;
  final List<String> videoUrls;
  final TrackingLevel level;
  final ProviderVerificationStatus verificationStatus;
  final double rating;
  final int reviewCount;
  final double? minPrice;
  final double? maxPrice;
  final String currency;
  final bool isAvailable;
  final Map<String, dynamic> requirements;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ThixProviderModel({
    required this.id,
    this.userId, // ✅ OPTIONNEL
    required this.uniqueCode,
    required this.category,
    required this.businessName,
    this.description,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.galleryUrls = const [],
    this.videoUrls = const [],
    this.level = TrackingLevel.bronze,
    this.verificationStatus = ProviderVerificationStatus.pending,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.minPrice,
    this.maxPrice,
    this.currency = 'USD',
    this.isAvailable = true,
    this.requirements = const {},
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ThixProviderModel.fromJson(Map<String, dynamic> json) {
    return ThixProviderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?, // ✅ CAST EN String? (nullable)
      uniqueCode: json['unique_code'] as String,
      category: ProviderCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ProviderCategory.salle,
      ),
      businessName: json['business_name'] as String,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      galleryUrls: (json['gallery_urls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      videoUrls: (json['video_urls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      level: TrackingLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => TrackingLevel.bronze,
      ),
      verificationStatus: ProviderVerificationStatus.values.firstWhere(
        (s) => s.name == json['verification_status'],
        orElse: () => ProviderVerificationStatus.pending,
      ),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      isAvailable: json['is_available'] as bool? ?? true,
      requirements: json['requirements'] as Map<String, dynamic>? ?? {},
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'unique_code': uniqueCode,
      'category': category.name,
      'business_name': businessName,
      'description': description,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'gallery_urls': galleryUrls,
      'video_urls': videoUrls,
      'level': level.name,
      'verification_status': verificationStatus.name,
      'rating': rating,
      'review_count': reviewCount,
      'min_price': minPrice,
      'max_price': maxPrice,
      'currency': currency,
      'is_available': isAvailable,
      'requirements': requirements,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ThixProviderModel copyWith({
    String? id,
    String? userId,
    String? uniqueCode,
    ProviderCategory? category,
    String? businessName,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? city,
    List<String>? galleryUrls,
    List<String>? videoUrls,
    TrackingLevel? level,
    ProviderVerificationStatus? verificationStatus,
    double? rating,
    int? reviewCount,
    double? minPrice,
    double? maxPrice,
    String? currency,
    bool? isAvailable,
    Map<String, dynamic>? requirements,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ThixProviderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      uniqueCode: uniqueCode ?? this.uniqueCode,
      category: category ?? this.category,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      level: level ?? this.level,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      currency: currency ?? this.currency,
      isAvailable: isAvailable ?? this.isAvailable,
      requirements: requirements ?? this.requirements,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ThixProviderModel(id: $id, businessName: $businessName, uniqueCode: $uniqueCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThixProviderModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          uniqueCode == other.uniqueCode &&
          category == other.category &&
          businessName == other.businessName;

  @override
  int get hashCode => Object.hash(id, userId, uniqueCode, category, businessName);
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER RESERVATION MODEL
// ═══════════════════════════════════════════════════════════════════════════
@immutable
class ProviderReservationModel {
  final String id;
  final String providerId;
  final String weddingId;
  final String clientName;
  final String clientPhone;
  final DateTime eventDate;
  final String? eventType;
  final int? guestCount;
  final double? totalPrice;
  final String currency;
  final ReservationStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProviderReservationModel({
    required this.id,
    required this.providerId,
    required this.weddingId,
    required this.clientName,
    required this.clientPhone,
    required this.eventDate,
    this.eventType,
    this.guestCount,
    this.totalPrice,
    this.currency = 'USD',
    this.status = ReservationStatus.pending,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderReservationModel.fromJson(Map<String, dynamic> json) {
    return ProviderReservationModel(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      weddingId: json['wedding_id'] as String,
      clientName: json['client_name'] as String,
      clientPhone: json['client_phone'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      eventType: json['event_type'] as String?,
      guestCount: json['guest_count'] as int?,
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      status: ReservationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ReservationStatus.pending,
      ),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_id': providerId,
      'wedding_id': weddingId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'event_date': eventDate.toIso8601String(),
      'event_type': eventType,
      'guest_count': guestCount,
      'total_price': totalPrice,
      'currency': currency,
      'status': status.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER TASK MODEL
// ═══════════════════════════════════════════════════════════════════════════
@immutable
class ProviderTaskModel {
  final String id;
  final String providerId;
  final String weddingId;
  final String assignedBy;
  final String title;
  final String? description;
  final DateTime dueDateTime;
  final TaskStatus status;
  final int priority;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ProviderTaskModel({
    required this.id,
    required this.providerId,
    required this.weddingId,
    required this.assignedBy,
    required this.title,
    this.description,
    required this.dueDateTime,
    this.status = TaskStatus.assigned,
    this.priority = 2,
    required this.createdAt,
    this.completedAt,
  });

  factory ProviderTaskModel.fromJson(Map<String, dynamic> json) {
    return ProviderTaskModel(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      weddingId: json['wedding_id'] as String,
      assignedBy: json['assigned_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDateTime: DateTime.parse(json['due_datetime'] as String),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TaskStatus.assigned,
      ),
      priority: json['priority'] as int? ?? 2,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_id': providerId,
      'wedding_id': weddingId,
      'assigned_by': assignedBy,
      'title': title,
      'description': description,
      'due_datetime': dueDateTime.toIso8601String(),
      'status': status.name,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}
