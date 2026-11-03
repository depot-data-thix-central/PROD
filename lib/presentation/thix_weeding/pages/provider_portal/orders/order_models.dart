// lib/presentation/thix_weeding/pages/provider_portal/orders/order_models.dart

import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — MODÈLES DE COMMANDES (WORKFLOW COMPLET)
/// ═══════════════════════════════════════════════════════════════════════

enum OrderStatus {
  pending,           // Commande reçue, en attente de confirmation
  confirmed,         // Confirmée par le prestataire
  inProgress,        // En cours de traitement/préparation
  ready,             // Prête (à livrer ou à récupérer)
  delivered,         // Livrée / Prestation effectuée
  completed,         // Terminée avec succès
  cancelled,         // Annulée
}

enum OrderPriority {
  low,
  normal,
  high,
  urgent,
}

enum PaymentStatus {
  pending,
  partial,
  paid,
  refunded,
}

class WeddingOrder {
  final String id;
  final String offerId;
  final String offerTitle;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String? clientPhone;
  final String providerId;
  final String providerName;
  final DateTime orderDate;
  final DateTime eventDate;
  final String? eventLocation;
  final OrderStatus status;
  final OrderPriority priority;
  final PaymentStatus paymentStatus;
  final Map<String, dynamic> orderData;
  final double totalAmount;
  final double? paidAmount;
  final String? notes;
  final List<OrderTimeline> timeline;
  final bool isTraiteur;
  final String? menuId;
  final bool menuValidated;
  final bool menuPublic;
  final Map<String, dynamic>? specificFields;

  const WeddingOrder({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    this.clientPhone,
    required this.providerId,
    required this.providerName,
    required this.orderDate,
    required this.eventDate,
    this.eventLocation,
    required this.status,
    required this.priority,
    this.paymentStatus = PaymentStatus.pending,
    required this.orderData,
    required this.totalAmount,
    this.paidAmount,
    this.notes,
    this.timeline = const [],
    this.isTraiteur = false,
    this.menuId,
    this.menuValidated = false,
    this.menuPublic = false,
    this.specificFields,
  });

  String get statusDisplayName {
    switch (status) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.inProgress:
        return 'En cours';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.completed:
        return 'Terminée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  Color getStatusColor() {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF3B82F6);
      case OrderStatus.inProgress:
        return const Color(0xFFF59E0B);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.delivered:
        return const Color(0xFF14B8A6);
      case OrderStatus.completed:
        return const Color(0xFF059669);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  IconData getStatusIcon() {
    switch (status) {
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.inProgress:
        return Icons.sync;
      case OrderStatus.ready:
        return Icons.check_circle;
      case OrderStatus.delivered:
        return Icons.local_shipping;
      case OrderStatus.completed:
        return Icons.verified;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case OrderPriority.low:
        return 'Basse';
      case OrderPriority.normal:
        return 'Normale';
      case OrderPriority.high:
        return 'Haute';
      case OrderPriority.urgent:
        return 'Urgente';
    }
  }

  Color getPriorityColor() {
    switch (priority) {
      case OrderPriority.low:
        return Colors.grey;
      case OrderPriority.normal:
        return Colors.blue;
      case OrderPriority.high:
        return Colors.orange;
      case OrderPriority.urgent:
        return Colors.red;
    }
  }

  int get daysUntilEvent {
    return eventDate.difference(DateTime.now()).inDays;
  }

  bool get isUrgent {
    return daysUntilEvent <= 3 && 
           status != OrderStatus.completed && 
           status != OrderStatus.cancelled;
  }

  bool get needsMenuValidation {
    return isTraiteur && menuId != null && !menuValidated;
  }

  double get remainingAmount {
    return totalAmount - (paidAmount ?? 0);
  }

  double get paymentProgress {
    if (totalAmount == 0) return 0;
    return (paidAmount ?? 0) / totalAmount;
  }

  String get paymentStatusDisplayName {
    switch (paymentStatus) {
      case PaymentStatus.pending:
        return 'En attente';
      case PaymentStatus.partial:
        return 'Partiel';
      case PaymentStatus.paid:
        return 'Payé';
      case PaymentStatus.refunded:
        return 'Remboursé';
    }
  }

  OrderStatus? get nextStatus {
    switch (status) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.inProgress;
      case OrderStatus.inProgress:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.delivered;
      case OrderStatus.delivered:
        return OrderStatus.completed;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return null;
    }
  }

  String? get nextActionLabel {
    switch (status) {
      case OrderStatus.pending:
        return 'Confirmer';
      case OrderStatus.confirmed:
        return 'Démarrer';
      case OrderStatus.inProgress:
        return 'Marquer prêt';
      case OrderStatus.ready:
        return 'Livrer';
      case OrderStatus.delivered:
        return 'Terminer';
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return null;
    }
  }

  WeddingOrder copyWith({
    String? id,
    String? offerId,
    String? offerTitle,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    String? providerId,
    String? providerName,
    DateTime? orderDate,
    DateTime? eventDate,
    String? eventLocation,
    OrderStatus? status,
    OrderPriority? priority,
    PaymentStatus? paymentStatus,
    Map<String, dynamic>? orderData,
    double? totalAmount,
    double? paidAmount,
    String? notes,
    List<OrderTimeline>? timeline,
    bool? isTraiteur,
    String? menuId,
    bool? menuValidated,
    bool? menuPublic,
    Map<String, dynamic>? specificFields,
  }) {
    return WeddingOrder(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      offerTitle: offerTitle ?? this.offerTitle,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      orderDate: orderDate ?? this.orderDate,
      eventDate: eventDate ?? this.eventDate,
      eventLocation: eventLocation ?? this.eventLocation,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderData: orderData ?? this.orderData,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      notes: notes ?? this.notes,
      timeline: timeline ?? this.timeline,
      isTraiteur: isTraiteur ?? this.isTraiteur,
      menuId: menuId ?? this.menuId,
      menuValidated: menuValidated ?? this.menuValidated,
      menuPublic: menuPublic ?? this.menuPublic,
      specificFields: specificFields ?? this.specificFields,
    );
  }

  WeddingOrder addTimelineEvent({
    required String action,
    required String performedBy,
    String? performedByRole,
    String? notes,
  }) {
    final newEvent = OrderTimeline(
      action: action,
      timestamp: DateTime.now(),
      performedBy: performedBy,
      performedByRole: performedByRole,
      notes: notes,
    );
    return copyWith(timeline: [...timeline, newEvent]);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'offer_id': offerId,
      'offer_title': offerTitle,
      'client_id': clientId,
      'client_name': clientName,
      'client_email': clientEmail,
      'client_phone': clientPhone,
      'provider_id': providerId,
      'provider_name': providerName,
      'order_date': orderDate.toIso8601String(),
      'event_date': eventDate.toIso8601String(),
      'event_location': eventLocation,
      'status': status.name,
      'priority': priority.name,
      'payment_status': paymentStatus.name,
      'order_data': orderData,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'notes': notes,
      'timeline': timeline.map((t) => t.toJson()).toList(),
      'is_traiteur': isTraiteur,
      'menu_id': menuId,
      'menu_validated': menuValidated,
      'menu_public': menuPublic,
      'specific_fields': specificFields,
    };
  }

  factory WeddingOrder.fromJson(Map<String, dynamic> json) {
    return WeddingOrder(
      id: json['id'] as String,
      offerId: json['offer_id'] as String,
      offerTitle: json['offer_title'] as String,
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String,
      clientEmail: json['client_email'] as String,
      clientPhone: json['client_phone'] as String?,
      providerId: json['provider_id'] as String,
      providerName: json['provider_name'] as String,
      orderDate: DateTime.parse(json['order_date'] as String),
      eventDate: DateTime.parse(json['event_date'] as String),
      eventLocation: json['event_location'] as String?,
      status: OrderStatus.values.firstWhere((e) => e.name == json['status']),
      priority: OrderPriority.values.firstWhere((e) => e.name == json['priority']),
      paymentStatus: PaymentStatus.values.firstWhere((e) => e.name == json['payment_status']),
      orderData: json['order_data'] as Map<String, dynamic>,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      timeline: (json['timeline'] as List?)
              ?.map((t) => OrderTimeline.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      isTraiteur: json['is_traiteur'] as bool? ?? false,
      menuId: json['menu_id'] as String?,
      menuValidated: json['menu_validated'] as bool? ?? false,
      menuPublic: json['menu_public'] as bool? ?? false,
      specificFields: json['specific_fields'] as Map<String, dynamic>?,
    );
  }
}

class OrderTimeline {
  final String action;
  final DateTime timestamp;
  final String? notes;
  final String performedBy;
  final String? performedByRole;

  const OrderTimeline({
    required this.action,
    required this.timestamp,
    this.notes,
    required this.performedBy,
    this.performedByRole,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'performed_by': performedBy,
      'performed_by_role': performedByRole,
    };
  }

  factory OrderTimeline.fromJson(Map<String, dynamic> json) {
    return OrderTimeline(
      action: json['action'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String?,
      performedBy: json['performed_by'] as String,
      performedByRole: json['performed_by_role'] as String?,
    );
  }
}
