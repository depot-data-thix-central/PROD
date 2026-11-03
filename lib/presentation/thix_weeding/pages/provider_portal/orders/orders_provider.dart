// lib/presentation/thix_weeding/pages/provider_portal/orders/orders_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_models.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — PROVIDER COMMANDES (Riverpod + Supabase)
/// ═══════════════════════════════════════════════════════════════════════

final supabaseClient = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final ordersProvider = AsyncNotifierProvider.autoDispose.family<OrdersNotifier, List<WeddingOrder>, String>(
  OrdersNotifier.new,
);

class OrdersNotifier extends AutoDisposeFamilyAsyncNotifier<List<WeddingOrder>, String> {
  SupabaseClient get _client => ref.read(supabaseClient);

  @override
  Future<List<WeddingOrder>> build(String providerId) async {
    return _fetchOrders(providerId);
  }

  Future<List<WeddingOrder>> _fetchOrders(String providerId) async {
    try {
      final response = await _client
          .from('wedding_orders')
          .select()
          .eq('provider_id', providerId)
          .order('event_date', ascending: true);

      return response
          .map((json) => WeddingOrder.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des commandes: $e');
    }
  }

  Future<WeddingOrder?> createOrder({
    required String offerId,
    required String offerTitle,
    required String clientId,
    required String clientName,
    required String clientEmail,
    String? clientPhone,
    required String providerId,
    required String providerName,
    required DateTime eventDate,
    String? eventLocation,
    required Map<String, dynamic> orderData,
    required double totalAmount,
    String? notes,
    bool isTraiteur = false,
    Map<String, dynamic>? specificFields,
  }) async {
    try {
      final order = WeddingOrder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        offerId: offerId,
        offerTitle: offerTitle,
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        clientPhone: clientPhone,
        providerId: providerId,
        providerName: providerName,
        orderDate: DateTime.now(),
        eventDate: eventDate,
        eventLocation: eventLocation,
        status: OrderStatus.pending,
        priority: _calculatePriority(eventDate),
        orderData: orderData,
        totalAmount: totalAmount,
        notes: notes,
        isTraiteur: isTraiteur,
        specificFields: specificFields,
      );

      final response = await _client
          .from('wedding_orders')
          .insert(order.toJson())
          .select()
          .single();

      final newOrder = WeddingOrder.fromJson(response as Map<String, dynamic>);
      
      state = AsyncValue.data([...state.value ?? [], newOrder]);
      
      return newOrder;
    } catch (e) {
      throw Exception('Erreur lors de la création de la commande: $e');
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? notes,
    required String performedBy,
    String? performedByRole,
  }) async {
    try {
      // Récupérer la commande actuelle
      final order = state.value?.firstWhere((o) => o.id == orderId);
      if (order == null) return;

      // Ajouter l'événement à la timeline
      final updatedOrder = order.copyWith(
        status: newStatus,
        timeline: [
          ...order.timeline,
          OrderTimeline(
            action: 'Statut changé: ${order.statusDisplayName} → ${newStatus.name}',
            timestamp: DateTime.now(),
            performedBy: performedBy,
            performedByRole: performedByRole,
            notes: notes,
          ),
        ],
      );

      await _client
          .from('wedding_orders')
          .update({
            'status': newStatus.name,
            'timeline': updatedOrder.timeline.map((t) => t.toJson()).toList(),
          })
          .eq('id', orderId);

      // Mettre à jour l'état local
      final updatedList = state.value!.map((o) {
        if (o.id == orderId) return updatedOrder;
        return o;
      }).toList();

      state = AsyncValue.data(updatedList);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  Future<void> updatePayment({
    required String orderId,
    required double amount,
    required PaymentStatus status,
  }) async {
    try {
      final order = state.value?.firstWhere((o) => o.id == orderId);
      if (order == null) return;

      final updatedOrder = order.copyWith(
        paidAmount: amount,
        paymentStatus: status,
      );

      await _client
          .from('wedding_orders')
          .update({
            'paid_amount': amount,
            'payment_status': status.name,
          })
          .eq('id', orderId);

      final updatedList = state.value!.map((o) {
        if (o.id == orderId) return updatedOrder;
        return o;
      }).toList();

      state = AsyncValue.data(updatedList);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du paiement: $e');
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _client.from('wedding_orders').delete().eq('id', orderId);
      
      final updatedList = state.value!.where((o) => o.id != orderId).toList();
      state = AsyncValue.data(updatedList);
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }

  OrderPriority _calculatePriority(DateTime eventDate) {
    final daysUntil = eventDate.difference(DateTime.now()).inDays;
    if (daysUntil <= 3) return OrderPriority.urgent;
    if (daysUntil <= 7) return OrderPriority.high;
    if (daysUntil <= 14) return OrderPriority.normal;
    return OrderPriority.low;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final orders = await _fetchOrders(arg);
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROVIDERS DÉRIVÉS (filtres et statistiques)
// ═══════════════════════════════════════════════════════════════════════

final pendingOrdersProvider = Provider.autoDispose.family<List<WeddingOrder>, String>((ref, providerId) {
  final ordersAsync = ref.watch(ordersProvider(providerId));
  return ordersAsync.value?.where((o) => o.status == OrderStatus.pending).toList() ?? [];
});

final urgentOrdersProvider = Provider.autoDispose.family<List<WeddingOrder>, String>((ref, providerId) {
  final ordersAsync = ref.watch(ordersProvider(providerId));
  return ordersAsync.value?.where((o) => o.isUrgent).toList() ?? [];
});

final ordersByStatusProvider = Provider.autoDispose.family<List<WeddingOrder>, (String, OrderStatus)>((ref, params) {
  final (providerId, status) = params;
  final ordersAsync = ref.watch(ordersProvider(providerId));
  return ordersAsync.value?.where((o) => o.status == status).toList() ?? [];
});

final orderStatsProvider = Provider.autoDispose.family<OrderStats, String>((ref, providerId) {
  final ordersAsync = ref.watch(ordersProvider(providerId));
  final orders = ordersAsync.value ?? [];

  return OrderStats(
    total: orders.length,
    pending: orders.where((o) => o.status == OrderStatus.pending).length,
    confirmed: orders.where((o) => o.status == OrderStatus.confirmed).length,
    inProgress: orders.where((o) => o.status == OrderStatus.inProgress).length,
    ready: orders.where((o) => o.status == OrderStatus.ready).length,
    completed: orders.where((o) => o.status == OrderStatus.completed).length,
    cancelled: orders.where((o) => o.status == OrderStatus.cancelled).length,
    urgent: orders.where((o) => o.isUrgent).length,
    totalRevenue: orders.fold(0.0, (sum, o) => sum + o.totalAmount),
    pendingRevenue: orders.where((o) => o.status == OrderStatus.pending).fold(0.0, (sum, o) => sum + o.totalAmount),
  );
});

class OrderStats {
  final int total;
  final int pending;
  final int confirmed;
  final int inProgress;
  final int ready;
  final int completed;
  final int cancelled;
  final int urgent;
  final double totalRevenue;
  final double pendingRevenue;

  const OrderStats({
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.inProgress,
    required this.ready,
    required this.completed,
    required this.cancelled,
    required this.urgent,
    required this.totalRevenue,
    required this.pendingRevenue,
  });
}
