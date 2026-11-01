// lib/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart
// ============================================================================
// THIX WEDDING — MODELS (PRODUCTION v5 — SYNC)
// ✅ user_id sur Guest (lien profiles THIX Hub)
// ✅ invitation_activated_at
// ✅ SeatingTableModel + SeatingLayoutModel (plan de table 3D)
// ============================================================================

class WeddingModel {
  final String id;
  final String? ownerId;
  final String brideName;
  final String groomName;
  final DateTime? weddingDate;
  final String? venue;
  final String uniqueCode;
  final bool invitationPublished;
  final DateTime? invitationActivatedAt;
  final DateTime createdAt;

  WeddingModel({
    required this.id,
    this.ownerId,
    required this.brideName,
    required this.groomName,
    this.weddingDate,
    this.venue,
    required this.uniqueCode,
    this.invitationPublished = false,
    this.invitationActivatedAt,
    required this.createdAt,
  });

  DateTime? get date => weddingDate;
  String? get locationName => venue;

  /// Actif tant que invitation publiée ET date mariage + 14 jours non dépassée
  bool get isInvitationStillActive {
    if (!invitationPublished) return false;
    if (weddingDate == null) return true;
    final limit = weddingDate!.add(const Duration(days: 14));
    return !DateTime.now().isAfter(limit);
  }

  String get coupleNames {
    final b = brideName.trim();
    final g = groomName.trim();
    if (b.isEmpty && g.isEmpty) return '';
    if (b.isEmpty) return g;
    if (g.isEmpty) return b;
    return '$b & $g';
  }

  factory WeddingModel.fromJson(Map<String, dynamic> j) => WeddingModel(
        id: j['id'],
        ownerId: j['owner_id'],
        brideName: j['bride_name'] ?? '',
        groomName: j['groom_name'] ?? '',
        weddingDate: j['wedding_date'] != null
            ? DateTime.parse(j['wedding_date'].toString())
            : null,
        venue: j['venue'],
        uniqueCode: j['unique_code'] ?? '',
        invitationPublished: j['invitation_published'] ?? false,
        invitationActivatedAt: j['invitation_activated_at'] != null
            ? DateTime.tryParse(j['invitation_activated_at'].toString())
            : null,
        createdAt: DateTime.parse(j['created_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'bride_name': brideName,
        'groom_name': groomName,
        'wedding_date': weddingDate?.toIso8601String().split('T')[0],
        'venue': venue,
      };
}

class GuestModel {
  final String id;
  final String weddingId;
  final String name;
  final String? email;
  final String? phone;
  final String? groupName;
  final int guestsCount;
  final String rsvpStatus;
  final bool isPresent;
  final int? tableNumber;
  final DateTime createdAt;
  final bool isVip;
  final bool isCompanion;
  final String? notes;
  final String? thixId;
  /// Lien vers profiles.id (THIX Hub)
  final String? userId;
  /// Siège précis dans le plan 3D (optionnel)
  final String? seatId;

  GuestModel({
    required this.id,
    required this.weddingId,
    required this.name,
    this.email,
    this.phone,
    this.groupName,
    this.guestsCount = 1,
    this.rsvpStatus = 'pending',
    this.isPresent = false,
    this.tableNumber,
    required this.createdAt,
    this.isVip = false,
    this.isCompanion = false,
    this.notes,
    this.thixId,
    this.userId,
    this.seatId,
  });

  String get fullName => name;

  factory GuestModel.fromJson(Map<String, dynamic> j) => GuestModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        name: j['name'] ?? '',
        email: j['email'],
        phone: j['phone'],
        groupName: j['group_name'],
        guestsCount: j['guests_count'] is int
            ? j['guests_count'] as int
            : int.tryParse('${j['guests_count']}') ?? 1,
        rsvpStatus: j['rsvp_status'] ?? 'pending',
        isPresent: j['is_present'] ?? false,
        tableNumber: j['table_number'] is int
            ? j['table_number'] as int
            : int.tryParse('${j['table_number']}'),
        createdAt: DateTime.parse(j['created_at'].toString()),
        isVip: (j['is_vip'] as bool?) ?? false,
        isCompanion: (j['is_companion'] as bool?) ?? false,
        notes: j['notes'] as String?,
        thixId: j['thix_id'] as String?,
        userId: j['user_id'] as String?,
        seatId: j['seat_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'wedding_id': weddingId,
        'name': name,
        'email': email,
        'phone': phone,
        'group_name': groupName,
        'guests_count': guestsCount,
        'rsvp_status': rsvpStatus,
        'is_present': isPresent,
        'table_number': tableNumber,
        'created_at': createdAt.toIso8601String(),
        'is_vip': isVip,
        'is_companion': isCompanion,
        'notes': notes,
        'thix_id': thixId,
        'user_id': userId,
        'seat_id': seatId,
      };

  GuestModel copyWith({
    int? tableNumber,
    String? seatId,
    bool clearTable = false,
  }) {
    return GuestModel(
      id: id,
      weddingId: weddingId,
      name: name,
      email: email,
      phone: phone,
      groupName: groupName,
      guestsCount: guestsCount,
      rsvpStatus: rsvpStatus,
      isPresent: isPresent,
      tableNumber: clearTable ? null : (tableNumber ?? this.tableNumber),
      createdAt: createdAt,
      isVip: isVip,
      isCompanion: isCompanion,
      notes: notes,
      thixId: thixId,
      userId: userId,
      seatId: clearTable ? null : (seatId ?? this.seatId),
    );
  }
}

/// Profil minimal THIX Hub (table profiles)
class ThixProfileLite {
  final String id;
  final String thixId;
  final String displayName;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? username;

  ThixProfileLite({
    required this.id,
    required this.thixId,
    required this.displayName,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.username,
  });

  String get bestName {
    final f = (fullName ?? '').trim();
    if (f.isNotEmpty) return f;
    final d = displayName.trim();
    if (d.isNotEmpty) return d;
    return username ?? thixId;
  }

  factory ThixProfileLite.fromJson(Map<String, dynamic> j) => ThixProfileLite(
        id: j['id'] as String,
        thixId: (j['thix_id'] as String?) ?? '',
        displayName: (j['display_name'] as String?) ?? '',
        fullName: j['full_name'] as String?,
        phone: (j['contact_phone'] as String?) ?? (j['phone_number'] as String?),
        avatarUrl: (j['avatar_url'] as String?) ?? (j['photo_url'] as String?),
        username: j['username'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAN DE TABLE 3D / SALLE
// ═══════════════════════════════════════════════════════════════════════════

enum TableShape { round, rect, oval, square }

class SeatingTableModel {
  final String id;
  final String weddingId;
  final String label;
  final TableShape shape;
  final int capacity;
  /// Position normalisée 0..1 dans la salle
  final double x;
  final double y;
  /// Rotation en degrés
  final double rotation;
  /// Couleur accent (hex)
  final String colorHex;
  /// Zone (ex: famille_marié, vip, amis…)
  final String? zone;
  final int orderIndex;

  SeatingTableModel({
    required this.id,
    required this.weddingId,
    required this.label,
    this.shape = TableShape.round,
    this.capacity = 8,
    this.x = 0.5,
    this.y = 0.5,
    this.rotation = 0,
    this.colorHex = '#D4AF37',
    this.zone,
    this.orderIndex = 0,
  });

  factory SeatingTableModel.fromJson(Map<String, dynamic> j) {
    TableShape shape = TableShape.round;
    final s = (j['shape'] as String?)?.toLowerCase();
    if (s == 'rect') shape = TableShape.rect;
    if (s == 'oval') shape = TableShape.oval;
    if (s == 'square') shape = TableShape.square;

    return SeatingTableModel(
      id: j['id'] as String,
      weddingId: j['wedding_id'] as String,
      label: (j['label'] as String?) ?? 'Table',
      shape: shape,
      capacity: (j['capacity'] as int?) ?? 8,
      x: (j['x'] as num?)?.toDouble() ?? 0.5,
      y: (j['y'] as num?)?.toDouble() ?? 0.5,
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
      colorHex: (j['color_hex'] as String?) ?? '#D4AF37',
      zone: j['zone'] as String?,
      orderIndex: (j['order_index'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'wedding_id': weddingId,
        'label': label,
        'shape': shape.name,
        'capacity': capacity,
        'x': x,
        'y': y,
        'rotation': rotation,
        'color_hex': colorHex,
        'zone': zone,
        'order_index': orderIndex,
      };

  SeatingTableModel copyWith({
    String? label,
    TableShape? shape,
    int? capacity,
    double? x,
    double? y,
    double? rotation,
    String? colorHex,
    String? zone,
  }) {
    return SeatingTableModel(
      id: id,
      weddingId: weddingId,
      label: label ?? this.label,
      shape: shape ?? this.shape,
      capacity: capacity ?? this.capacity,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      colorHex: colorHex ?? this.colorHex,
      zone: zone ?? this.zone,
      orderIndex: orderIndex,
    );
  }
}

/// Layout global de la salle (dimensions, ambiance lumière)
class SeatingLayoutModel {
  final String weddingId;
  final double roomWidth;
  final double roomHeight;
  /// 0..1 intensité lumière ambiante
  final double ambientLight;
  /// Couleur dominante de la salle
  final String roomColorHex;
  final bool showDanceFloor;
  final bool showStage;
  final List<SeatingTableModel> tables;

  SeatingLayoutModel({
    required this.weddingId,
    this.roomWidth = 1.0,
    this.roomHeight = 1.0,
    this.ambientLight = 0.75,
    this.roomColorHex = '#1A1520',
    this.showDanceFloor = true,
    this.showStage = true,
    this.tables = const [],
  });

  factory SeatingLayoutModel.fromJson(Map<String, dynamic> j, List<SeatingTableModel> tables) {
    return SeatingLayoutModel(
      weddingId: j['wedding_id'] as String? ?? '',
      roomWidth: (j['room_width'] as num?)?.toDouble() ?? 1.0,
      roomHeight: (j['room_height'] as num?)?.toDouble() ?? 1.0,
      ambientLight: (j['ambient_light'] as num?)?.toDouble() ?? 0.75,
      roomColorHex: (j['room_color_hex'] as String?) ?? '#1A1520',
      showDanceFloor: (j['show_dance_floor'] as bool?) ?? true,
      showStage: (j['show_stage'] as bool?) ?? true,
      tables: tables,
    );
  }

  Map<String, dynamic> toLayoutJson() => {
        'wedding_id': weddingId,
        'room_width': roomWidth,
        'room_height': roomHeight,
        'ambient_light': ambientLight,
        'room_color_hex': roomColorHex,
        'show_dance_floor': showDanceFloor,
        'show_stage': showStage,
      };
}

// ─── Autres modèles existants (Vendor, Budget…) ───────────────────────────

class VendorPackageModel {
  final String id;
  final String vendorId;
  final String title;
  final double price;
  final String? description;

  VendorPackageModel({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.price,
    this.description,
  });

  factory VendorPackageModel.fromJson(Map<String, dynamic> j) =>
      VendorPackageModel(
        id: j['id'],
        vendorId: j['vendor_id'],
        title: j['title'] ?? '',
        price: (j['price'] as num).toDouble(),
        description: j['description'],
      );
}

class VendorModel {
  final String id;
  final String weddingId;
  final String name;
  final String category;
  final String? contactName;
  final String? phone;
  final String? email;
  final double? price;
  final String status;
  final String? notes;
  final bool isBooked;
  final List<VendorPackageModel> packages;
  final DateTime createdAt;

  VendorModel({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.category,
    this.contactName,
    this.phone,
    this.email,
    this.price,
    this.status = 'pending',
    this.notes,
    this.isBooked = false,
    this.packages = const [],
    required this.createdAt,
  });

  factory VendorModel.fromJson(Map<String, dynamic> j) => VendorModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        contactName: j['contact_name'],
        phone: j['phone'],
        email: j['email'],
        price: j['price'] != null ? (j['price'] as num).toDouble() : null,
        status: j['status'] ?? 'pending',
        notes: j['notes'],
        isBooked: j['is_booked'] ?? false,
        packages: const [],
        createdAt: DateTime.parse(j['created_at'].toString()),
      );
}

class BudgetModel {
  final String id;
  final String weddingId;
  final double totalBudget;
  final double spent;

  BudgetModel({
    required this.id,
    required this.weddingId,
    required this.totalBudget,
    this.spent = 0,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> j) => BudgetModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        totalBudget: (j['total_budget'] as num?)?.toDouble() ?? 0,
        spent: (j['spent'] as num?)?.toDouble() ?? 0,
      );
}


class ExpenseModel {
  final String id;
  final String weddingId;
  final String title;
  final double amount;
  final String? category;
  final DateTime createdAt;
  final bool isPaid;
  final String? vendorId;

  ExpenseModel({
    required this.id,
    required this.weddingId,
    required this.title,
    required this.amount,
    this.category,
    required this.createdAt,
    this.isPaid = false,
    this.vendorId,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> j) => ExpenseModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        title: j['title'] ?? '',
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String?,
        createdAt: DateTime.parse(j['created_at'].toString()),
        isPaid: (j['is_paid'] as bool?) ?? false,
        vendorId: j['vendor_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'wedding_id': weddingId,
        'title': title,
        'amount': amount,
        'category': category,
        'is_paid': isPaid,
        'vendor_id': vendorId,
      };
}

class ChecklistModel {
  final String id;
  final String weddingId;
  final String title;
  final bool isDone;
  final int orderIndex;
  final DateTime? dueDate;
  final String priority;
  final String? category;

  ChecklistModel({
    required this.id,
    required this.weddingId,
    required this.title,
    this.isDone = false,
    this.orderIndex = 0,
    this.dueDate,
    this.priority = 'normal',
    this.category,
  });

  factory ChecklistModel.fromJson(Map<String, dynamic> j) => ChecklistModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        title: j['title'] ?? '',
        isDone: j['is_done'] ?? false,
        orderIndex: j['order_index'] ?? 0,
        dueDate: j['due_date'] != null
            ? DateTime.tryParse(j['due_date'].toString())
            : null,
        priority: (j['priority'] as String?) ?? 'normal',
        category: j['category'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'wedding_id': weddingId,
        'title': title,
        'is_done': isDone,
        'order_index': orderIndex,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'category': category,
      };
}

class GalleryModel {
  final String id;
  final String weddingId;
  final String url;
  final String? caption;
  final DateTime? createdAt;

  GalleryModel({
    required this.id,
    required this.weddingId,
    required this.url,
    this.caption,
    this.createdAt,
  });

  /// Alias utilisé dans le dashboard / galerie
  String get imageUrl => url;

  factory GalleryModel.fromJson(Map<String, dynamic> j) => GalleryModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        url: (j['url'] as String?) ??
            (j['image_url'] as String?) ??
            '',
        caption: j['caption'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
      );
}

class GuestbookModel {
  final String id;
  final String weddingId;
  final String authorName;
  final String message;
  final bool isApproved;
  final DateTime createdAt;

  GuestbookModel({
    required this.id,
    required this.weddingId,
    required this.authorName,
    required this.message,
    this.isApproved = false,
    required this.createdAt,
  });

  /// Alias UI (dashboard / livre d'or)
  String get guestName => authorName;

  factory GuestbookModel.fromJson(Map<String, dynamic> j) => GuestbookModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        authorName: (j['author_name'] as String?) ??
            (j['guest_name'] as String?) ??
            '',
        message: j['message'] ?? '',
        isApproved: j['is_approved'] ?? false,
        createdAt: DateTime.parse(j['created_at'].toString()),
      );
}

class MessageModel {
  final String id;
  final String weddingId;
  final String? guestId;
  final String senderName;
  final String senderType;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.weddingId,
    this.guestId,
    required this.senderName,
    required this.senderType,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        guestId: j['guest_id'],
        senderName: j['sender_name'] ?? '',
        senderType: j['sender_type'] ?? 'staff',
        content: j['content'] ?? '',
        isRead: j['is_read'] ?? false,
        createdAt: DateTime.parse(j['created_at'].toString()),
      );
}

class PaymentModel {
  final String id;
  final String weddingId;
  final String title;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? method;
  final String? referenceCode;
  final String? vendorId;
  final String? expenseId;
  final String? vendorName;
  final String? expenseTitle;

  PaymentModel({
    required this.id,
    required this.weddingId,
    required this.title,
    required this.amount,
    this.status = 'pending',
    required this.createdAt,
    this.method,
    this.referenceCode,
    this.vendorId,
    this.expenseId,
    this.vendorName,
    this.expenseTitle,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> j) {
    // Jointures optionnelles
    String? vendorName;
    final v = j['thix_weeding_vendors'];
    if (v is Map) {
      vendorName = v['name'] as String?;
    } else {
      vendorName = j['vendor_name'] as String?;
    }

    String? expenseTitle;
    final e = j['thix_weeding_expenses'];
    if (e is Map) {
      expenseTitle = e['title'] as String?;
    } else {
      expenseTitle = j['expense_title'] as String?;
    }

    return PaymentModel(
      id: j['id'],
      weddingId: j['wedding_id'],
      title: (j['title'] as String?) ?? '',
      amount: (j['amount'] as num).toDouble(),
      status: (j['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(j['created_at'].toString()),
      method: j['method'] as String?,
      referenceCode: j['reference_code'] as String?,
      vendorId: j['vendor_id'] as String?,
      expenseId: j['expense_id'] as String?,
      vendorName: vendorName,
      expenseTitle: expenseTitle,
    );
  }
}
