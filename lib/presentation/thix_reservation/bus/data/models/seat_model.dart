/// ============================================================================
/// SeatModel
/// ============================================================================
///
/// Représentation d'un siège de bus dans le système THIX.
///
/// Un siège peut avoir plusieurs états :
/// - **available** : Libre, peut être sélectionné
/// - **locked** : Temporairement réservé par un utilisateur (timer actif)
/// - **booked** : Réservé et payé (définitif)
/// - **blocked** : Bloqué manuellement par l'agence
///
/// Features :
/// - Enum `SeatStatus` pour type-safety
/// - Détection du lock par l'utilisateur courant
/// - Calcul automatique VIP (flag OU extra_price > 0)
/// - copyWith pour modifications immuables
/// - toJson pour serialization API
/// - Égalité structurelle (== et hashCode)
/// - Validation robuste dans fromJson
/// - Getters utilitaires pour logique métier
///
/// ============================================================================
class SeatModel {
  // ─── Identifiants ─────────────────────────────────────────
  final String id;
  final String tripId;
  final String seatNumber;

  // ─── État ─────────────────────────────────────────────────
  final SeatStatus status;
  final String? lockedBy;
  final DateTime? lockedUntil;

  // ─── Configuration ────────────────────────────────────────
  final bool isVip;
  final int extraPrice;

  // ─── Métadonnées (optionnelles) ───────────────────────────
  final int? row;
  final String? column;
  final bool isAisle;
  final bool isWindow;

  const SeatModel({
    required this.id,
    required this.tripId,
    required this.seatNumber,
    required this.status,
    this.lockedBy,
    this.lockedUntil,
    this.isVip = false,
    this.extraPrice = 0,
    this.row,
    this.column,
    this.isAisle = false,
    this.isWindow = false,
  });

  // ─── Factory from JSON ────────────────────────────────────
  factory SeatModel.fromJson(Map<String, dynamic> json) {
    // Parsing robuste du prix supplémentaire
    final extraRaw = json['extra_price'] ??
        json['vip_supplement'] ??
        json['supplement'] ??
        0;
    final parsedExtra = _parseIntSafe(extraRaw);

    // Parsing du flag VIP
    final vipFlag = _parseBoolSafe(json['is_vip']);

    // Parsing du statut
    final statusStr = (json['status'] as String?)?.toLowerCase() ?? 'available';
    final status = SeatStatus.fromString(statusStr);

    // Parsing de locked_until
    DateTime? lockedUntil;
    if (json['locked_until'] != null) {
      if (json['locked_until'] is String) {
        lockedUntil = DateTime.tryParse(json['locked_until'] as String);
      } else if (json['locked_until'] is DateTime) {
        lockedUntil = json['locked_until'] as DateTime;
      }
    }

    // Parsing row/column (optionnels)
    final row = _parseIntSafe(json['row']);
    final column = json['column'] as String?;

    return SeatModel(
      id: (json['id'] as String?) ?? '',
      tripId: (json['trip_id'] as String?) ?? '',
      seatNumber: (json['seat_number'] as String?) ?? '',
      status: status,
      lockedBy: json['locked_by'] as String?,
      lockedUntil: lockedUntil,
      isVip: vipFlag || parsedExtra > 0,
      extraPrice: parsedExtra,
      row: row > 0 ? row : null,
      column: column,
      isAisle: _parseBoolSafe(json['is_aisle']),
      isWindow: _parseBoolSafe(json['is_window']),
    );
  }

  // ─── Serialization to JSON ────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'seat_number': seatNumber,
      'status': status.value,
      if (lockedBy != null) 'locked_by': lockedBy,
      if (lockedUntil != null) 'locked_until': lockedUntil!.toIso8601String(),
      'is_vip': isVip,
      'extra_price': extraPrice,
      if (row != null) 'row': row,
      if (column != null) 'column': column,
      'is_aisle': isAisle,
      'is_window': isWindow,
    };
  }

  // ─── CopyWith ─────────────────────────────────────────────
  SeatModel copyWith({
    String? id,
    String? tripId,
    String? seatNumber,
    SeatStatus? status,
    String? lockedBy,
    DateTime? lockedUntil,
    bool? isVip,
    int? extraPrice,
    int? row,
    String? column,
    bool? isAisle,
    bool? isWindow,
    bool clearLockedBy = false,
    bool clearLockedUntil = false,
    bool clearRow = false,
    bool clearColumn = false,
  }) {
    return SeatModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      seatNumber: seatNumber ?? this.seatNumber,
      status: status ?? this.status,
      lockedBy: clearLockedBy ? null : (lockedBy ?? this.lockedBy),
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      isVip: isVip ?? this.isVip,
      extraPrice: extraPrice ?? this.extraPrice,
      row: clearRow ? null : (row ?? this.row),
      column: clearColumn ? null : (column ?? this.column),
      isAisle: isAisle ?? this.isAisle,
      isWindow: isWindow ?? this.isWindow,
    );
  }

  // ─── Getters d'état ───────────────────────────────────────

  /// Le siège est-il disponible pour sélection ?
  /// (available OU locked par nous-mêmes)
  bool get isAvailable => status == SeatStatus.available;

  /// Le siège est-il réservé (définitif) ?
  bool get isBooked => status == SeatStatus.booked;

  /// Le siège est-il temporairement verrouillé ?
  bool get isLocked => status == SeatStatus.locked;

  /// Le siège est-il bloqué par l'agence ?
  bool get isBlocked => status == SeatStatus.blocked;

  /// Le siège peut-il être sélectionné par l'utilisateur ?
  bool get isSelectable =>
      status == SeatStatus.available ||
      (status == SeatStatus.locked && isLockedByCurrentUser);

  /// Le lock est-il actif (non expiré) ?
  bool get isLockActive {
    if (lockedUntil == null) return false;
    return lockedUntil!.isAfter(DateTime.now());
  }

  /// Secondes restantes avant expiration du lock
  int get lockRemainingSeconds {
    if (lockedUntil == null) return 0;
    final diff = lockedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Le lock expire-t-il bientôt (< 60s) ?
  bool get isLockExpiringSoon =>
      lockRemainingSeconds > 0 && lockRemainingSeconds < 60;

  /// Le lock expire-t-il urgemment (< 30s) ?
  bool get isLockExpiringUrgent =>
      lockRemainingSeconds > 0 && lockRemainingSeconds < 30;

  // ─── Détection utilisateur courant ────────────────────────

  /// Vérifie si le siège est verrouillé par l'utilisateur courant
  /// À utiliser avec : `seat.isLockedByUser(currentUserId)`
  bool isLockedByUser(String? userId) {
    if (userId == null || lockedBy == null) return false;
    return lockedBy == userId && isLockActive;
  }

  /// Raccourci pour compatibilité (à éviter, préférer isLockedByUser)
  bool get isLockedByCurrentUser => isLockActive;

  // ─── Getters utilitaires ──────────────────────────────────

  /// Label formaté pour affichage (ex: "12A", "VIP 5B")
  String get displayLabel {
    final prefix = isVip ? 'VIP ' : '';
    return '$prefix$seatNumber';
  }

  /// Position descriptive (ex: "Rangée 12, Couloir")
  String get positionDescription {
    final parts = <String>[];
    if (row != null) parts.add('Rangée $row');
    if (isWindow) {
      parts.add('Fenêtre');
    } else if (isAisle) {
      parts.add('Couloir');
    }
    return parts.isEmpty ? seatNumber : parts.join(', ');
  }

  /// Prix total (base + extra) — nécessite priceBase en paramètre
  int totalPrice(int priceBase) => priceBase + extraPrice;

  // ─── Égalité et hash ──────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeatModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tripId == other.tripId &&
          seatNumber == other.seatNumber &&
          status == other.status &&
          lockedBy == other.lockedBy &&
          lockedUntil == other.lockedUntil &&
          isVip == other.isVip &&
          extraPrice == other.extraPrice;

  @override
  int get hashCode => Object.hash(
        id,
        tripId,
        seatNumber,
        status,
        lockedBy,
        lockedUntil,
        isVip,
        extraPrice,
      );

  @override
  String toString() {
    return 'SeatModel($seatNumber, $status${isVip ? ", VIP" : ""})';
  }

  // ─── Helpers de parsing ───────────────────────────────────
  static int _parseIntSafe(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

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
}

/// ============================================================================
/// SeatStatus — Enum des statuts de siège
/// ============================================================================
enum SeatStatus {
  available('available'),
  locked('locked'),
  booked('booked'),
  blocked('blocked');

  final String value;
  const SeatStatus(this.value);

  /// Parse depuis une string (case-insensitive)
  static SeatStatus fromString(String? value) {
    if (value == null) return SeatStatus.available;
    final lower = value.toLowerCase();
    return SeatStatus.values.firstWhere(
      (s) => s.value == lower,
      orElse: () => SeatStatus.available,
    );
  }

  /// Label humain pour affichage
  String get label {
    switch (this) {
      case SeatStatus.available:
        return 'Disponible';
      case SeatStatus.locked:
        return 'Réservé temporairement';
      case SeatStatus.booked:
        return 'Réservé';
      case SeatStatus.blocked:
        return 'Bloqué';
    }
  }

  /// Couleur associée (pour UI)
  String get colorHex {
    switch (this) {
      case SeatStatus.available:
        return '#FFFFFF';
      case SeatStatus.locked:
        return '#FBBF24';
      case SeatStatus.booked:
        return '#0B4FE3';
      case SeatStatus.blocked:
        return '#9CA3AF';
    }
  }
}
