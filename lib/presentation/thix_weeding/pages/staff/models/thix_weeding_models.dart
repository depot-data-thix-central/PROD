// lib/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart

class WeddingModel {
  final String id;
  final String? ownerId;
  final String brideName;
  final String groomName;
  final DateTime? weddingDate;
  final String? venue;
  final String uniqueCode;
  final bool invitationPublished;
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
    required this.createdAt,
  });

  // --- Alias UI ---
  DateTime? get date => weddingDate;
  String? get locationName => venue;
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
            ? DateTime.parse(j['wedding_date'])
            : null,
        venue: j['venue'],
        uniqueCode: j['unique_code'] ?? '',
        invitationPublished: j['invitation_published'] ?? false,
        createdAt: DateTime.parse(j['created_at']),
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
  });

  // --- Alias UI ---
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
        tableNumber: j['table_number'],
        createdAt: DateTime.parse(j['created_at']),
      );
}

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
        price: (j['price'] as num?)?.toDouble(),
        status: j['status'] ?? 'pending',
        notes: j['notes'],
        isBooked: j['is_booked'] ?? false,
        packages: j['thix_weeding_vendor_packages'] != null
            ? (j['thix_weeding_vendor_packages'] as List)
                .map((e) => VendorPackageModel.fromJson(e))
                .toList()
            : [],
        createdAt: DateTime.parse(j['created_at']),
      );
}

class BudgetModel {
  final String id;
  final String weddingId;
  final double totalBudget;
  final double totalSpent;
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.weddingId,
    required this.totalBudget,
    required this.totalSpent,
    required this.createdAt,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> j) => BudgetModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        totalBudget: (j['total_budget'] as num).toDouble(),
        totalSpent: (j['total_spent'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(j['created_at']),
      );
}

class ExpenseModel {
  final String id;
  final String weddingId;
  final String? vendorId;
  final String title;
  final double amount;
  final String category;
  final bool isPaid;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.weddingId,
    this.vendorId,
    required this.title,
    required this.amount,
    required this.category,
    this.isPaid = false,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> j) => ExpenseModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        vendorId: j['vendor_id'],
        title: j['title'] ?? '',
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] ?? '',
        isPaid: j['is_paid'] ?? false,
        createdAt: DateTime.parse(j['created_at']),
      );
}

class ChecklistModel {
  final String id;
  final String weddingId;
  final String title;
  final bool isDone;
  final DateTime? dueDate;
  final DateTime createdAt;

  ChecklistModel({
    required this.id,
    required this.weddingId,
    required this.title,
    this.isDone = false,
    this.dueDate,
    required this.createdAt,
  });

  factory ChecklistModel.fromJson(Map<String, dynamic> j) => ChecklistModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        title: j['title'] ?? '',
        isDone: j['is_done'] ?? false,
        dueDate:
            j['due_date'] != null ? DateTime.parse(j['due_date']) : null,
        createdAt: DateTime.parse(j['created_at']),
      );
}

class GalleryModel {
  final String id;
  final String weddingId;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;

  GalleryModel({
    required this.id,
    required this.weddingId,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
  });

  factory GalleryModel.fromJson(Map<String, dynamic> j) => GalleryModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        imageUrl: j['image_url'] ?? '',
        caption: j['caption'],
        createdAt: DateTime.parse(j['created_at']),
      );
}

class GuestbookModel {
  final String id;
  final String weddingId;
  final String guestName;
  final String message;
  final bool isApproved;
  final DateTime createdAt;

  GuestbookModel({
    required this.id,
    required this.weddingId,
    required this.guestName,
    required this.message,
    this.isApproved = false,
    required this.createdAt,
  });

  factory GuestbookModel.fromJson(Map<String, dynamic> j) => GuestbookModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        guestName: j['guest_name'] ?? '',
        message: j['message'] ?? '',
        isApproved: j['is_approved'] ?? false,
        createdAt: DateTime.parse(j['created_at']),
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
    this.senderType = 'guest',
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        guestId: j['guest_id'],
        senderName: j['sender_name'] ?? '',
        senderType: j['sender_type'] ?? 'guest',
        content: j['content'] ?? '',
        isRead: j['is_read'] ?? false,
        createdAt: DateTime.parse(j['created_at']),
      );
}

class PaymentModel {
  final String id;
  final String weddingId;
  final String? vendorId;
  final String? expenseId;
  final double amount;
  final String method;
  final String status;
  final String? referenceCode;
  final DateTime createdAt;
  final String? vendorName;
  final String? expenseTitle;

  PaymentModel({
    required this.id,
    required this.weddingId,
    this.vendorId,
    this.expenseId,
    required this.amount,
    required this.method,
    required this.status,
    this.referenceCode,
    required this.createdAt,
    this.vendorName,
    this.expenseTitle,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> j) => PaymentModel(
        id: j['id'],
        weddingId: j['wedding_id'],
        vendorId: j['vendor_id'],
        expenseId: j['expense_id'],
        amount: (j['amount'] as num).toDouble(),
        method: j['method'] ?? 'cash',
        status: j['status'] ?? 'pending',
        referenceCode: j['reference_code'],
        createdAt: DateTime.parse(j['created_at']),
        vendorName: j['thix_weeding_vendors'] is Map
            ? j['thix_weeding_vendors']['name']
            : null,
        expenseTitle: j['thix_weeding_expenses'] is Map
            ? j['thix_weeding_expenses']['title']
            : null,
      );
}
