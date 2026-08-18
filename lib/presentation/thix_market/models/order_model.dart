class OrderModel {
  final String id;
  final String userId;
  final String? shopId;
  final double total;
  final String status;
  final List<OrderItemModel> items;
  final String? shippingAddress;
  final String? shippingCity;
  final String? shippingPhone;
  final double? shippingCost;
  final String? trackingNumber;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  OrderModel({
    required this.id,
    required this.userId,
    this.shopId,
    required this.total,
    required this.status,
    required this.items,
    this.shippingAddress,
    this.shippingCity,
    this.shippingPhone,
    this.shippingCost,
    this.trackingNumber,
    this.paymentMethod,
    this.paymentStatus,
    required this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.shippedAt,
    this.deliveredAt,
    this.cancelledAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      shopId: json['shop_id'] as String?,
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String,
      items: (json['items'] as List?)
          ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      shippingAddress: json['shipping_address'] as String?,
      shippingCity: json['shipping_city'] as String?,
      shippingPhone: json['shipping_phone'] as String?,
      shippingCost: (json['shipping_cost'] as num?)?.toDouble(),
      trackingNumber: json['tracking_number'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      shippedAt: json['shipped_at'] != null
          ? DateTime.parse(json['shipped_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'shop_id': shopId,
      'total': total,
      'status': status,
      'items': items.map((e) => e.toJson()).toList(),
      'shipping_address': shippingAddress,
      'shipping_city': shippingCity,
      'shipping_phone': shippingPhone,
      'shipping_cost': shippingCost,
      'tracking_number': trackingNumber,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'shipped_at': shippedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isShipped => status == 'shipped';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get canCancel => isPending || isProcessing;
}

class OrderItemModel {
  final String id;
  final String productId;
  final String name;
  final String? imageUrl;
  final int quantity;
  final double price;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.price,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'image_url': imageUrl,
      'quantity': quantity,
      'price': price,
    };
  }

  double get subtotal => price * quantity;
}
