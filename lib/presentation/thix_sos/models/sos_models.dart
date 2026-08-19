/// THIX SOS — Models (production)
library;

enum SosStatus {
  created,
  activating,
  active,
  callingCircle1,
  callingCircle2,
  callingCircle3,
  takenOver,
  crisisRoomActive,
  networkLost,
  recovering,
  cancelPending,
  cancelled,
  resolved,
  archived,
}

extension SosStatusX on SosStatus {
  String get dbValue {
    switch (this) {
      case SosStatus.callingCircle1:
        return 'calling_circle_1';
      case SosStatus.callingCircle2:
        return 'calling_circle_2';
      case SosStatus.callingCircle3:
        return 'calling_circle_3';
      case SosStatus.takenOver:
        return 'taken_over';
      case SosStatus.crisisRoomActive:
        return 'crisis_room_active';
      case SosStatus.networkLost:
        return 'network_lost';
      case SosStatus.cancelPending:
        return 'cancel_pending';
      default:
        return name;
    }
  }

  static SosStatus fromDb(String? value) {
    switch (value) {
      case 'calling_circle_1':
        return SosStatus.callingCircle1;
      case 'calling_circle_2':
        return SosStatus.callingCircle2;
      case 'calling_circle_3':
        return SosStatus.callingCircle3;
      case 'taken_over':
        return SosStatus.takenOver;
      case 'crisis_room_active':
        return SosStatus.crisisRoomActive;
      case 'network_lost':
        return SosStatus.networkLost;
      case 'cancel_pending':
        return SosStatus.cancelPending;
      case 'created':
        return SosStatus.created;
      case 'activating':
        return SosStatus.activating;
      case 'active':
        return SosStatus.active;
      case 'recovering':
        return SosStatus.recovering;
      case 'cancelled':
        return SosStatus.cancelled;
      case 'resolved':
        return SosStatus.resolved;
      case 'archived':
        return SosStatus.archived;
      default:
        return SosStatus.active;
    }
  }

  bool get isTerminal =>
      this == SosStatus.cancelled ||
      this == SosStatus.resolved ||
      this == SosStatus.archived;

  bool get isLive => !isTerminal;

  String get labelFr {
    switch (this) {
      case SosStatus.created:
        return 'Créé';
      case SosStatus.activating:
        return 'Activation…';
      case SosStatus.active:
        return 'Actif';
      case SosStatus.callingCircle1:
        return 'Appel Cercle 1';
      case SosStatus.callingCircle2:
        return 'Appel Cercle 2';
      case SosStatus.callingCircle3:
        return 'Appel Cercle 3';
      case SosStatus.takenOver:
        return 'Pris en charge';
      case SosStatus.crisisRoomActive:
        return 'Chambre de crise';
      case SosStatus.networkLost:
        return 'Connexion perdue';
      case SosStatus.recovering:
        return 'Récupération…';
      case SosStatus.cancelPending:
        return 'Annulation…';
      case SosStatus.cancelled:
        return 'Annulé';
      case SosStatus.resolved:
        return 'Résolu';
      case SosStatus.archived:
        return 'Archivé';
    }
  }
}

class SosContact {
  final String id;
  final String ownerId;
  final String name;
  final String? phone;
  final String? thixId;
  final String? photoUrl;
  final String? relation;
  final int circle; // 1 | 2 | 3
  final int priority;
  final bool verified;
  final bool available;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SosContact({
    required this.id,
    required this.ownerId,
    required this.name,
    this.phone,
    this.thixId,
    this.photoUrl,
    this.relation,
    required this.circle,
    this.priority = 1,
    this.verified = false,
    this.available = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SosContact.fromJson(Map<String, dynamic> json) {
    return SosContact(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
      phone: json['phone'] as String?,
      thixId: json['thix_id'] as String?,
      photoUrl: json['photo_url'] as String?,
      relation: json['relation'] as String?,
      circle: (json['circle'] as num?)?.toInt() ?? 1,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      verified: json['verified'] as bool? ?? false,
      available: json['available'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson({required String ownerId}) {
    return {
      'owner_id': ownerId,
      'name': name.trim(),
      'phone': phone?.trim(),
      'thix_id': thixId?.trim(),
      'photo_url': photoUrl,
      'relation': relation?.trim(),
      'circle': circle,
      'priority': priority,
      'verified': verified,
      'available': available,
    };
  }

  SosContact copyWith({
    String? name,
    String? phone,
    String? thixId,
    String? photoUrl,
    String? relation,
    int? circle,
    int? priority,
    bool? verified,
    bool? available,
  }) {
    return SosContact(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      thixId: thixId ?? this.thixId,
      photoUrl: photoUrl ?? this.photoUrl,
      relation: relation ?? this.relation,
      circle: circle ?? this.circle,
      priority: priority ?? this.priority,
      verified: verified ?? this.verified,
      available: available ?? this.available,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class SosIncident {
  final String id;
  final String publicId;
  final String victimId;
  final SosStatus status;
  final int activeCircle;
  final String? responsibleContactId;
  final double? lastLat;
  final double? lastLng;
  final double? lastAccuracyM;
  final DateTime? lastLocationAt;
  final DateTime? heartbeatAt;
  final int? batteryPct;
  final DateTime startedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SosIncident({
    required this.id,
    required this.publicId,
    required this.victimId,
    required this.status,
    this.activeCircle = 1,
    this.responsibleContactId,
    this.lastLat,
    this.lastLng,
    this.lastAccuracyM,
    this.lastLocationAt,
    this.heartbeatAt,
    this.batteryPct,
    required this.startedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status.isLive;

  Duration get elapsed => DateTime.now().difference(startedAt);

  String get elapsedLabel {
    final d = elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get hasLocation => lastLat != null && lastLng != null;

  factory SosIncident.fromJson(Map<String, dynamic> json) {
    return SosIncident(
      id: json['id'] as String,
      publicId: json['public_id'] as String? ?? '',
      victimId: json['victim_id'] as String? ?? '',
      status: SosStatusX.fromDb(json['status'] as String?),
      activeCircle: (json['active_circle'] as num?)?.toInt() ?? 1,
      responsibleContactId: json['responsible_contact_id'] as String?,
      lastLat: (json['last_lat'] as num?)?.toDouble(),
      lastLng: (json['last_lng'] as num?)?.toDouble(),
      lastAccuracyM: (json['last_accuracy_m'] as num?)?.toDouble(),
      lastLocationAt: DateTime.tryParse(json['last_location_at'] as String? ?? ''),
      heartbeatAt: DateTime.tryParse(json['heartbeat_at'] as String? ?? ''),
      batteryPct: (json['battery_pct'] as num?)?.toInt(),
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? '') ?? DateTime.now(),
      resolvedAt: DateTime.tryParse(json['resolved_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  SosIncident copyWith({
    SosStatus? status,
    int? activeCircle,
    String? responsibleContactId,
    double? lastLat,
    double? lastLng,
    double? lastAccuracyM,
    DateTime? lastLocationAt,
    DateTime? heartbeatAt,
    int? batteryPct,
    DateTime? resolvedAt,
  }) {
    return SosIncident(
      id: id,
      publicId: publicId,
      victimId: victimId,
      status: status ?? this.status,
      activeCircle: activeCircle ?? this.activeCircle,
      responsibleContactId: responsibleContactId ?? this.responsibleContactId,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      heartbeatAt: heartbeatAt ?? this.heartbeatAt,
      batteryPct: batteryPct ?? this.batteryPct,
      startedAt: startedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class SosLocationPoint {
  final String id;
  final String incidentId;
  final double lat;
  final double lng;
  final double? accuracyM;
  final double? speedMps;
  final double? headingDeg;
  final DateTime capturedAt;

  const SosLocationPoint({
    required this.id,
    required this.incidentId,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
    required this.capturedAt,
  });

  factory SosLocationPoint.fromJson(Map<String, dynamic> json) {
    return SosLocationPoint(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      speedMps: (json['speed_mps'] as num?)?.toDouble(),
      headingDeg: (json['heading_deg'] as num?)?.toDouble(),
      capturedAt: DateTime.tryParse(json['captured_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SosEvent {
  final String id;
  final String incidentId;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const SosEvent({
    required this.id,
    required this.incidentId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  factory SosEvent.fromJson(Map<String, dynamic> json) {
    return SosEvent(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      type: json['type'] as String? ?? '',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
