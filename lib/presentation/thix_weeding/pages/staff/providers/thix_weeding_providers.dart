// lib/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart
// ============================================================================
// THIX WEDDING & EVENTS — PROVIDERS (PRODUCTION) — CORRIGÉ
// ✅ expensesProvider(weddingId) corrigé avec argument
// ✅ Tous les providers family passent correctement le weddingId
// ============================================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thix_weeding_models.dart';
import '../services/thix_weeding_services.dart';

// ============================================================================
// SERVICES (Singleton via Provider)
// ============================================================================
final weddingServiceProvider = Provider((ref) => WeddingService());
final guestServiceProvider = Provider((ref) => GuestService());
final vendorServiceProvider = Provider((ref) => VendorService());
final budgetServiceProvider = Provider((ref) => BudgetService());
final checklistServiceProvider = Provider((ref) => ChecklistService());
final galleryServiceProvider = Provider((ref) => GalleryService());
final guestbookServiceProvider = Provider((ref) => GuestbookService());
final messageServiceProvider = Provider((ref) => MessageService());
final paymentServiceProvider = Provider((ref) => PaymentService());

// ============================================================================
// WEDDING
// ============================================================================
final weddingProvider =
    FutureProvider.autoDispose.family<WeddingModel, String>((ref, weddingId) async {
  return ref.read(weddingServiceProvider).getById(weddingId);
});

final myWeddingsProvider =
    FutureProvider.autoDispose.family<List<WeddingModel>, String>((ref, ownerId) async {
  return ref.read(weddingServiceProvider).getByOwner(ownerId);
});

// ============================================================================
// GUESTS
// ============================================================================
final guestsProvider =
    FutureProvider.autoDispose.family<List<GuestModel>, String>((ref, weddingId) async {
  return ref.read(guestServiceProvider).getByWedding(weddingId);
});

final guestDetailProvider =
    FutureProvider.autoDispose.family<GuestModel, String>((ref, guestId) async {
  return ref.read(guestServiceProvider).getById(guestId);
});

// ============================================================================
// VENDORS
// ============================================================================
final vendorsProvider =
    FutureProvider.autoDispose.family<List<VendorModel>, String>((ref, weddingId) async {
  return ref.read(vendorServiceProvider).getByWedding(weddingId);
});

final vendorDetailProvider =
    FutureProvider.autoDispose.family<VendorModel, String>((ref, vendorId) async {
  return ref.read(vendorServiceProvider).getById(vendorId);
});

// ============================================================================
// BUDGET / EXPENSES
// ============================================================================
final budgetProvider =
    FutureProvider.autoDispose.family<BudgetModel?, String>((ref, weddingId) async {
  return ref.read(budgetServiceProvider).getBudget(weddingId);
});

final expensesProvider =
    FutureProvider.autoDispose.family<List<ExpenseModel>, String>((ref, weddingId) async {
  return ref.read(budgetServiceProvider).getExpenses(weddingId);
});

final expenseDetailProvider =
    FutureProvider.autoDispose.family<ExpenseModel, String>((ref, expenseId) async {
  // Recherche par ID dans toutes les dépenses du wedding
  // Le provider est appelé avec l'expenseId, on cherche via Supabase direct
  try {
    final res = await Supabase.instance.client
        .from('thix_weeding_expenses')
        .select()
        .eq('id', expenseId)
        .single();
    return ExpenseModel.fromJson(Map<String, dynamic>.from(res));
  } catch (_) {
    throw Exception('Dépense introuvable ($expenseId)');
  }
});

// ============================================================================
// CHECKLIST
// ============================================================================
final checklistProvider =
    FutureProvider.autoDispose.family<List<ChecklistModel>, String>((ref, weddingId) async {
  return ref.read(checklistServiceProvider).getByWedding(weddingId);
});

final checklistDetailProvider =
    FutureProvider.autoDispose.family<ChecklistModel, String>((ref, taskId) async {
  return ref.read(checklistServiceProvider).getById(taskId);
});

// ============================================================================
// GALLERY
// ============================================================================
final galleryProvider =
    FutureProvider.autoDispose.family<List<GalleryModel>, String>((ref, weddingId) async {
  return ref.read(galleryServiceProvider).getByWedding(weddingId);
});

// ============================================================================
// GUESTBOOK
// ============================================================================
final guestbookProvider =
    FutureProvider.autoDispose.family<List<GuestbookModel>, String>((ref, weddingId) async {
  return ref.read(guestbookServiceProvider).getByWedding(weddingId);
});

// ============================================================================
// MESSAGES
// ============================================================================
final messagesProvider =
    FutureProvider.autoDispose.family<List<MessageModel>, String>((ref, weddingId) async {
  return ref.read(messageServiceProvider).getByWedding(weddingId);
});

final unreadMessagesCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, weddingId) async {
  final messages = await ref.watch(messagesProvider(weddingId)).future;
  return messages.where((m) => !m.isRead && m.senderType == 'guest').length;
});

// ============================================================================
// PAYMENTS
// ============================================================================
final paymentsProvider =
    FutureProvider.autoDispose.family<List<PaymentModel>, String>((ref, weddingId) async {
  return ref.read(paymentServiceProvider).getByWedding(weddingId);
});

final paymentDetailProvider =
    FutureProvider.autoDispose.family<PaymentModel, String>((ref, paymentId) async {
  return ref.read(paymentServiceProvider).getById(paymentId);
});

// ============================================================================
// SUMMARY & STATS
// ============================================================================

/// ✅ CORRIGÉ : expensesProvider(weddingId) au lieu de expensesProvider
final paymentsSummaryProvider =
    FutureProvider.autoDispose.family<Map<String, double>, String>((ref, weddingId) async {
  final budget = await ref.watch(budgetProvider(weddingId)).future;
  final expenses = await ref.watch(expensesProvider(weddingId)).future;
  final payments = await ref.watch(paymentsProvider(weddingId)).future;

  final totalBudget = budget?.totalBudget ?? 0.0;
  final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  final totalPaid = payments
      .where((p) => p.status == 'completed')
      .fold<double>(0.0, (sum, p) => sum + p.amount);

  return {
    'budget': totalBudget,
    'spent': totalSpent,
    'paid': totalPaid,
    'remaining': totalBudget - totalSpent,
  };
});

final dashboardStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final guests = await ref.watch(guestsProvider(weddingId)).future;
  final vendors = await ref.watch(vendorsProvider(weddingId)).future;
  final tasks = await ref.watch(checklistProvider(weddingId)).future;

  return {
    'guests': guests.length,
    'present': guests.where((g) => g.isPresent).length,
    'vendors': vendors.length,
    'pendingTasks': tasks.where((t) => !t.isDone).length,
  };
});

final rsvpStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final guests = await ref.watch(guestsProvider(weddingId)).future;

  final confirmed = guests
      .where((g) =>
          g.rsvpStatus.toLowerCase() == 'confirmed' ||
          g.rsvpStatus.toLowerCase() == 'accepted')
      .length;
  final declined = guests
      .where((g) =>
          g.rsvpStatus.toLowerCase() == 'declined' ||
          g.rsvpStatus.toLowerCase() == 'no')
      .length;
  final pending = guests
      .where((g) =>
          g.rsvpStatus.isEmpty || g.rsvpStatus.toLowerCase() == 'pending')
      .length;
  final maybe = guests
      .where((g) => g.rsvpStatus.toLowerCase() == 'maybe')
      .length;

  return {
    'total': guests.length,
    'confirmed': confirmed,
    'declined': declined,
    'pending': pending,
    'maybe': maybe,
  };
});

final checklistStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final tasks = await ref.watch(checklistProvider(weddingId)).future;
  final now = DateTime.now();

  final total = tasks.length;
  final done = tasks.where((t) => t.isDone).length;
  final overdue = tasks
      .where((t) => !t.isDone && t.dueDate != null && t.dueDate!.isBefore(now))
      .length;
  final urgent = tasks
      .where((t) => !t.isDone && t.priority == 'urgent')
      .length;

  return {
    'total': total,
    'done': done,
    'pending': total - done,
    'overdue': overdue,
    'urgent': urgent,
  };
});

final galleryStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final gallery = await ref.watch(galleryProvider(weddingId)).future;
  return {'total': gallery.length};
});

final guestbookStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final entries = await ref.watch(guestbookProvider(weddingId)).future;
  final approved = entries.where((e) => e.isApproved).length;
  return {
    'total': entries.length,
    'approved': approved,
    'pending': entries.length - approved,
  };
});
