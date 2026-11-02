// lib/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart
// ============================================================================
// THIX WEDDING & EVENTS — PROVIDERS (PRODUCTION) — CORRIGÉ RIVERPOD 2.6.1
// ✅ ref.read(xxx.future) au lieu de ref.watch(xxx).future
// ✅ Import supabase_flutter ajouté pour expenseDetailProvider
// ✅ expensesProvider(weddingId) avec argument correct
// ✅ Seating 3D + invitations actives (badge home) + recherche profiles THIX Hub
// ✅ Menu Service + providers pour gestion traiteur + votes invités
// ============================================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/thix_weeding_models.dart';
import '../services/thix_weeding_services.dart';
import '../services/menu_service.dart'; // ✅ NOUVEAU : MenuService

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
final seatingServiceProvider = Provider((ref) => SeatingService());
final thixProfileServiceProvider = Provider((ref) => ThixProfileService());
final menuServiceProvider = Provider((ref) => MenuService()); // ✅ NOUVEAU

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
  final messages = await ref.read(messagesProvider(weddingId).future);
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

final paymentsSummaryProvider =
    FutureProvider.autoDispose.family<Map<String, double>, String>((ref, weddingId) async {
  final budget = await ref.read(budgetProvider(weddingId).future);
  final expenses = await ref.read(expensesProvider(weddingId).future);
  final payments = await ref.read(paymentsProvider(weddingId).future);

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
  final guests = await ref.read(guestsProvider(weddingId).future);
  final vendors = await ref.read(vendorsProvider(weddingId).future);
  final tasks = await ref.read(checklistProvider(weddingId).future);

  return {
    'guests': guests.length,
    'present': guests.where((g) => g.isPresent).length,
    'vendors': vendors.length,
    'pendingTasks': tasks.where((t) => !t.isDone).length,
  };
});

final rsvpStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final guests = await ref.read(guestsProvider(weddingId).future);

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
  final tasks = await ref.read(checklistProvider(weddingId).future);
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
  final gallery = await ref.read(galleryProvider(weddingId).future);
  return {'total': gallery.length};
});

final guestbookStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, weddingId) async {
  final entries = await ref.read(guestbookProvider(weddingId).future);
  final approved = entries.where((e) => e.isApproved).length;
  return {
    'total': entries.length,
    'approved': approved,
    'pending': entries.length - approved,
  };
});

// ============================================================================
// SEATING / PLAN DE TABLE 3D
// ============================================================================
final seatingTablesProvider =
    FutureProvider.autoDispose.family<List<SeatingTableModel>, String>((ref, weddingId) async {
  return ref.read(seatingServiceProvider).getTables(weddingId);
});

final seatingLayoutProvider =
    FutureProvider.autoDispose.family<SeatingLayoutModel, String>((ref, weddingId) async {
  return ref.read(seatingServiceProvider).getLayout(weddingId);
});

// ============================================================================
// INVITATIONS ACTIVES POUR L'UTILISATEUR CONNECTÉ (badge home)
// Guests liés via user_id + invitation publiée + jusqu'à J+14
// ============================================================================
final myActiveInvitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final res = await Supabase.instance.client
      .from('thix_weeding_guests')
      .select('''
        id,
        wedding_id,
        name,
        thix_id,
        thix_weeding_weddings!inner (
          id,
          bride_name,
          groom_name,
          wedding_date,
          invitation_published,
          unique_code,
          invitation_activated_at
        )
      ''')
      .eq('user_id', user.id)
      .eq('thix_weeding_weddings.invitation_published', true);

  final now = DateTime.now();
  final list = <Map<String, dynamic>>[];

  for (final row in List<Map<String, dynamic>>.from(res)) {
    final wRaw = row['thix_weeding_weddings'];
    if (wRaw is! Map) continue;
    final w = Map<String, dynamic>.from(wRaw);

    final dateStr = w['wedding_date'];
    if (dateStr != null) {
      final weddingDate = DateTime.tryParse(dateStr.toString());
      if (weddingDate != null) {
        final limit = weddingDate.add(const Duration(days: 14));
        if (now.isAfter(limit)) continue;
      }
    }

    list.add({
      'guest_id': row['id'],
      'wedding_id': row['wedding_id'],
      'guest_name': row['name'],
      'bride_name': w['bride_name'],
      'groom_name': w['groom_name'],
      'wedding_date': w['wedding_date'],
      'unique_code': w['unique_code'],
    });
  }

  return list;
});

// ============================================================================
// RECHERCHE PROFIL THIX HUB (table profiles)
// ============================================================================
final thixProfileSearchProvider =
    FutureProvider.autoDispose.family<ThixProfileLite?, String>((ref, thixId) async {
  return ref.read(thixProfileServiceProvider).findByThixId(thixId);
});

// ============================================================================
// ✅ MENU SERVICE & PROVIDERS (traiteurs + votes invités)
// ============================================================================

/// Tous les plats d'un mariage (avec jointure vendor)
/// Utilisé par : staff (page menu traiteur)
final weddingMenuItemsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  return await ref.watch(menuServiceProvider).getByWedding(weddingId);
});

/// Plats PUBLICS d'un mariage (is_public = true)
/// Utilisé par : guests (page préférences repas)
final weddingPublicMenuProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  return await ref.watch(menuServiceProvider).getPublicByWedding(weddingId);
});

/// Compteur de votes par menu_item_id pour un mariage
/// Utilisé par : staff (top plats) + guests (nombre de votes visibles)
final menuVotesCountProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, weddingId) async {
  return await ref.watch(menuServiceProvider).getVoteCounts(weddingId);
});

/// Votes d'un invité spécifique (Set de menu_item_id votés)
/// Utilisé par : guests (savoir quels plats il a déjà cochés)
/// Paramètre : record (weddingId, guestId)
final guestMenuVotesProvider = FutureProvider.autoDispose
    .family<Set<String>, ({String weddingId, String guestId})>((ref, args) async {
  return await ref
      .watch(menuServiceProvider)
      .getGuestVotes(args.weddingId, args.guestId);
});

/// Plat spécifique par ID (pour détails / édition)
final menuItemDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, itemId) async {
  try {
    final res = await Supabase.instance.client
        .from('thix_weeding_menu_items')
        .select('*, vendor:thix_weeding_vendors(id, name, category, contact_name)')
        .eq('id', itemId)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  } catch (_) {
    return null;
  }
});

/// Stats globales du menu d'un mariage (pour dashboard staff)
final menuStatsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, weddingId) async {
  try {
    final items = await ref.watch(menuServiceProvider).getByWedding(weddingId);
    final votes = await ref.watch(menuServiceProvider).getVoteCounts(weddingId);
    
    final total = items.length;
    final validated = items.where((i) => i['is_validated'] == true).length;
    final public = items.where((i) => i['is_public'] == true).length;
    final pending = items.where((i) => i['is_validated'] != true).length;
    final totalVotes = votes.values.fold(0, (sum, v) => sum + v);
    
    return {
      'total': total,
      'validated': validated,
      'public': public,
      'pending': pending,
      'totalVotes': totalVotes,
      'vendors': items.map((i) => i['vendor_id']).toSet().length,
    };
  } catch (_) {
    return {
      'total': 0,
      'validated': 0,
      'public': 0,
      'pending': 0,
      'totalVotes': 0,
      'vendors': 0,
    };
  }
});
