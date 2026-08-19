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
  String get db {
    switch (this) {
      case SosStatus.callingCircle1: return 'calling_circle_1';
      case SosStatus.callingCircle2: return 'calling_circle_2';
      case SosStatus.callingCircle3: return 'calling_circle_3';
      case SosStatus.takenOver: return 'taken_over';
      case SosStatus.crisisRoomActive: return 'crisis_room_active';
      case SosStatus.networkLost: return 'network_lost';
      case SosStatus.cancelPending: return 'cancel_pending';
      default: return name;
    }
  }

  static SosStatus fromDb(String? v) {
    switch (v) {
      case 'calling_circle_1': return SosStatus.callingCircle1;
      case 'calling_circle_2': return SosStatus.callingCircle2;
      case 'calling_circle_3': return SosStatus.callingCircle3;
      case 'taken_over': return SosStatus.takenOver;
      case 'crisis_room_active': return SosStatus.crisisRoomActive;
      case 'network_lost': return SosStatus.networkLost;
      case 'cancel_pending': return SosStatus.cancelPending;
      default:
        return SosStatus.values.firstWhere(
          (e) => e.name == v,
          orElse: () => SosStatus.active,
        );
    }
  }
}

class SosContact {
  final String id;
  final String name;
  final String? phone;
  final String? thixId;
  final String? photoUrl;
  final String? relation;
  final int circle; // 1,2,3
  final int priority;
  final bool verified;
  final bool available;

  const SosContact({
    required this.id,
    required this.name,
    this.phone,
    this.thixId,
    this.photoUrl,
    this.relation,
    required this.circle,
    this.priority = 1,
    this.verified = false,
    this.available = true,
  });

  factory SosContact.fromJson(Map<String, dynamic> j) => SosContact(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String?,
        thixId: j['thix_id'] as String?,
        photoUrl: j['photo_url'] as String?,
        relation: j['relation'] as String?,
        circle: (j['circle'] as num?)?.toInt() ?? 1,
        priority: (j['priority'] as num?)?.toInt() ?? 1,
        verified: j['verified'] as bool? ?? false,
        available: j['available'] as bool? ?? true,
      );
}

class SosIncident {
  final String id;
  final String publicId;
  final String victimId;
  final SosStatus status;
  final int activeCircle;
  final double? lastLat;
  final double? lastLng;
  final DateTime? heartbeatAt;
  final int? batteryPct;
  final DateTime startedAt;
  final DateTime? resolvedAt;

  const SosIncident({
    required this.id,
    required this.publicId,
    required this.victimId,
    required this.status,
    this.activeCircle = 1,
    this.lastLat,
    this.lastLng,
    this.heartbeatAt,
    this.batteryPct,
    required this.startedAt,
    this.resolvedAt,
  });

  bool get isActive =>
      status != SosStatus.cancelled &&
      status != SosStatus.resolved &&
      status != SosStatus.archived;

  Duration get duration => DateTime.now().difference(startedAt);

  factory SosIncident.fromJson(Map<String, dynamic> j) => SosIncident(
        id: j['id'] as String,
        publicId: j['public_id'] as String? ?? '',
        victimId: j['victim_id'] as String? ?? '',
        status: SosStatusX.fromDb(j['status'] as String?),
        activeCircle: (j['active_circle'] as num?)?.toInt() ?? 1,
        lastLat: (j['last_lat'] as num?)?.toDouble(),
        lastLng: (j['last_lng'] as num?)?.toDouble(),
        heartbeatAt: DateTime.tryParse(j['heartbeat_at'] as String? ?? ''),
        batteryPct: (j['battery_pct'] as num?)?.toInt(),
        startedAt: DateTime.tryParse(j['started_at'] as String? ?? '') ?? DateTime.now(),
        resolvedAt: DateTime.tryParse(j['resolved_at'] as String? ?? ''),
      );
}
