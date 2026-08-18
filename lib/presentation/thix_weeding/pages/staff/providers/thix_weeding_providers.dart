// lib/presentation/thix_weeding/staff/providers/thix_weeding_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/thix_weeding_models.dart';
import '../services/thix_weeding_services.dart';

// ================= SERVICES (Singleton) =================
final weddingServiceProvider = Provider((ref) => WeddingService());
final guestServiceProvider = Provider((ref) => GuestService());
final vendorServiceProvider = Provider((ref) => VendorService());
final budgetServiceProvider = Provider((ref) => BudgetService());
final checklistServiceProvider = Provider((ref) => ChecklistService());
final galleryServiceProvider = Provider((ref) => GalleryService());
final guestbookServiceProvider = Provider((ref) => GuestbookService());
final messageServiceProvider = Provider((ref) => MessageService());
final paymentServiceProvider = Provider((ref) => PaymentService());

// ================= WEDDING =================
final weddingProvider = FutureProvider.autoDispose.family<WeddingModel, String>((ref, weddingId) async {
  return ref.read(weddingServiceProvider).getById(weddingId);
});
final myWeddingsProvider = FutureProvider.autoDispose.family<List<WeddingModel>, String>((ref, ownerId) async {
  return ref.read(weddingServiceProvider).getByOwner(ownerId);
});

// ================= GUESTS =================
final guestsProvider = FutureProvider.autoDispose.family<List<GuestModel>, String>((ref, weddingId) async {
  return ref.read(guestServiceProvider).getByWedding(weddingId);
});
final guestDetailProvider = FutureProvider.autoDispose.family<GuestModel, String>((ref, guestId) async {
  return ref.read(guestServiceProvider).getById(guestId);
});

// ================= VENDORS =================
final vendorsProvider = FutureProvider.autoDispose.family<List<VendorModel>, String>((ref, weddingId) async {
  return ref.read(vendorServiceProvider).getByWedding(weddingId);
});

// ================= BUDGET / EXPENSES =================
final budgetProvider = FutureProvider.autoDispose.family<BudgetModel?, String>((ref, weddingId) async {
  return ref.read(budgetServiceProvider).getBudget(weddingId);
});
final expensesProvider = FutureProvider.autoDispose.family<List<ExpenseModel>, String>((ref, weddingId) async {
  return ref.read(budgetServiceProvider).getExpenses(weddingId);
});

// ================= CHECKLIST =================
final checklistProvider = FutureProvider.autoDispose.family<List<ChecklistModel>, String>((ref, weddingId) async {
  return ref.read(checklistServiceProvider).getByWedding(weddingId);
});

// ================= GALLERY =================
final galleryProvider = FutureProvider.autoDispose.family<List<GalleryModel>, String>((ref, weddingId) async {
  return ref.read(galleryServiceProvider).getByWedding(weddingId);
});

// ================= GUESTBOOK =================
final guestbookProvider = FutureProvider.autoDispose.family<List<GuestbookModel>, String>((ref, weddingId) async {
  return ref.read(guestbookServiceProvider).getByWedding(weddingId);
});

// ================= MESSAGES =================
final messagesProvider = FutureProvider.autoDispose.family<List<MessageModel>, String>((ref, weddingId) async {
  return ref.read(messageServiceProvider).getByWedding(weddingId);
});

// ================= PAYMENTS =================
final paymentsProvider = FutureProvider.autoDispose.family<List<PaymentModel>, String>((ref, weddingId) async {
  return ref.read(paymentServiceProvider).getByWedding(weddingId);
});
final paymentDetailProvider = FutureProvider.autoDispose.family<PaymentModel, String>((ref, paymentId) async {
  return ref.read(paymentServiceProvider).getById(paymentId);
});

// ================= SUMMARY (PROD: 1 seul appel DB si possible, sinon calcul local) =================
final paymentsSummaryProvider = FutureProvider.autoDispose.family<Map<String, double>, String>((ref, weddingId) async {
  // on watch pour que ça se refresh quand payments/expenses/budget changent
  final budget = await ref.watch(budgetProvider(weddingId).future);
  final expenses = await ref.watch(expensesProvider(weddingId).future);
  final payments = await ref.watch(paymentsProvider(weddingId).future);
  
  final totalBudget = budget?.totalBudget ?? 0.0;
  final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  final totalPaid = payments.where((p) => p.status == 'completed').fold<double>(0.0, (sum, p) => sum + p.amount);
      
  return {
    'budget': totalBudget,
    'spent': totalSpent,
    'paid': totalPaid,
    'remaining': totalBudget - totalSpent,
  };
});

final dashboardStatsProvider = FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final guests = await ref.watch(guestsProvider(weddingId).future);
  final vendors = await ref.watch(vendorsProvider(weddingId).future);
  final tasks = await ref.watch(checklistProvider(weddingId).future);
  
  return {
    'guests': guests.length,
    'present': guests.where((g) => g.isPresent).length,
    'vendors': vendors.length,
    'pendingTasks': tasks.where((t) => !t.isDone).length,
  };
});
