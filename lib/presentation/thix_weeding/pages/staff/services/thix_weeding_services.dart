// lib/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart
// ============================================================================
// THIX WEDDING & EVENTS — SERVICES (PRODUCTION)
// Tous les services CRUD + Upload Web-compatible + Méthodes manquantes
// ⚠️ PAS de dart:io → uploadBinary uniquement pour compatibilité Web/WASM
// ============================================================================
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';

// ============================================================================
// WEDDING SERVICE
// ============================================================================
class WeddingService {
  final _c = Supabase.instance.client;

  Future<WeddingModel> getById(String id) async {
    final res = await _c
        .from('thix_weeding_weddings')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (res == null) {
      throw Exception('Mariage introuvable ($id)');
    }
    return WeddingModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<List<WeddingModel>> getByOwner(String ownerId) async {
    final res = await _c
        .from('thix_weeding_weddings')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res)
        .map((e) => WeddingModel.fromJson(e))
        .toList();
  }

  Future<WeddingModel> create(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_weddings').insert(data).select().single();
    return WeddingModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _c.from('thix_weeding_weddings').update(data).eq('id', id);
  }

  Future<void> publish(String id) async {
    await _c.from('thix_weeding_weddings').update({
      'invitation_published': true,
      'invitation_activated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> unpublish(String id) async {
    await _c
        .from('thix_weeding_weddings')
        .update({'invitation_published': false}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_weddings').delete().eq('id', id);
  }
}

// ============================================================================
// GUEST SERVICE
// ============================================================================
class GuestService {
  final _c = Supabase.instance.client;

  Future<List<GuestModel>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_guests')
        .select()
        .eq('wedding_id', weddingId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(res)
        .map((e) => GuestModel.fromJson(e))
        .toList();
  }

  Future<GuestModel> getById(String id) async {
    final res =
        await _c.from('thix_weeding_guests').select().eq('id', id).single();
    return GuestModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<GuestModel> create(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_guests').insert(data).select().single();
    return GuestModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _c.from('thix_weeding_guests').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_guests').delete().eq('id', id);
  }

  Future<void> togglePresent(String id, bool v) async {
    await _c
        .from('thix_weeding_guests')
        .update({'is_present': v}).eq('id', id);
  }

  Future<void> updateRsvp(String id, String status) async {
    await _c
        .from('thix_weeding_guests')
        .update({'rsvp_status': status}).eq('id', id);
  }

  Future<void> assignTable(String id, int? tableNumber) async {
    await _c
        .from('thix_weeding_guests')
        .update({'table_number': tableNumber}).eq('id', id);
  }

  Future<int> getCountByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_guests')
        .select('id')
        .eq('wedding_id', weddingId);
    return (res as List).length;
  }
}

// ============================================================================
// VENDOR SERVICE
// ============================================================================
class VendorService {
  final _c = Supabase.instance.client;

  Future<List<VendorModel>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_vendors')
        .select('*, thix_weeding_vendor_packages(*)')
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res)
        .map((e) => VendorModel.fromJson(e))
        .toList();
  }

  Future<VendorModel> getById(String id) async {
    final res = await _c
        .from('thix_weeding_vendors')
        .select('*, thix_weeding_vendor_packages(*)')
        .eq('id', id)
        .single();
    return VendorModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<VendorModel> create(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_vendors').insert(data).select().single();
    return VendorModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _c.from('thix_weeding_vendors').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_vendors').delete().eq('id', id);
  }

  Future<void> toggleBooked(String id, bool booked) async {
    await _c
        .from('thix_weeding_vendors')
        .update({'is_booked': booked}).eq('id', id);
  }

  Future<void> updateStatus(String id, String status) async {
    await _c
        .from('thix_weeding_vendors')
        .update({'status': status}).eq('id', id);
  }
}

// ============================================================================
// CHECKLIST SERVICE — MIS À JOUR avec getById + nouvelles méthodes
// ============================================================================
class ChecklistService {
  final _c = Supabase.instance.client;

  Future<List<ChecklistModel>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_checklist')
        .select()
        .eq('wedding_id', weddingId)
        .order('order_index');

    return List<Map<String, dynamic>>.from(res)
        .map((e) => ChecklistModel.fromJson(e))
        .toList();
  }

  /// ✅ AJOUTÉ — Manquait dans le code original
  Future<ChecklistModel> getById(String id) async {
    final res = await _c
        .from('thix_weeding_checklist')
        .select()
        .eq('id', id)
        .single();
    return ChecklistModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<ChecklistModel> create(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_checklist').insert(data).select().single();
    return ChecklistModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> toggle(String id, bool done) async {
    await _c
        .from('thix_weeding_checklist')
        .update({'is_done': done}).eq('id', id);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _c.from('thix_weeding_checklist').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_checklist').delete().eq('id', id);
  }

  /// ✅ AJOUTÉ — Réordonner les tâches
  Future<void> reorder(String id, int orderIndex) async {
    await _c
        .from('thix_weeding_checklist')
        .update({'order_index': orderIndex}).eq('id', id);
  }

  /// ✅ AJOUTÉ — Compter les tâches par statut
  Future<Map<String, int>> getStats(String weddingId) async {
    final all = await getByWedding(weddingId);
    final total = all.length;
    final done = all.where((t) => t.isDone).length;
    final overdue = all
        .where((t) =>
            !t.isDone && t.dueDate != null && t.dueDate!.isBefore(DateTime.now()))
        .length;
    return {
      'total': total,
      'done': done,
      'pending': total - done,
      'overdue': overdue,
    };
  }
}

// ============================================================================
// GALLERY SERVICE — CORRIGÉ uploadBytes (interpolation + vidéos)
// ============================================================================
class GalleryService {
  final _c = Supabase.instance.client;
  static const _bucket = 'thix-weeding-gallery';

  Future<List<GalleryModel>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_gallery')
        .select()
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res)
        .map((e) => GalleryModel.fromJson(e))
        .toList();
  }

  /// ✅ CORRIGÉ — Interpolation Dart correcte + support vidéo + Web compatible
  Future<String> uploadBytes({
    required String weddingId,
    required Uint8List bytes,
    String fileName = 'photo.jpg',
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';

    // Extensions supportées
    final imageExts = ['png', 'webp', 'jpg', 'jpeg'];
    final videoExts = ['mp4', 'mov', 'avi', 'mkv'];
    final allExts = [...imageExts, ...videoExts];

    final safeExt = allExts.contains(ext) ? ext : 'jpg';
    final isVideo = videoExts.contains(safeExt);

    // ✅ CORRECTION CRITIQUE : interpolation Dart correcte
    // AVANT (cassé) : '\( weddingId/ \){DateTime.now()...}'
    // APRÈS (correct) : '$weddingId/${DateTime.now()...}'
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$weddingId/$timestamp.$safeExt';

    // Content-Type correct selon le type de fichier
    final String contentType;
    if (isVideo) {
      contentType = 'video/$safeExt';
    } else if (safeExt == 'png') {
      contentType = 'image/png';
    } else if (safeExt == 'webp') {
      contentType = 'image/webp';
    } else {
      contentType = 'image/jpeg';
    }

    await _c.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: contentType,
          ),
        );

    return _c.storage.from(_bucket).getPublicUrl(path);
  }

  Future<GalleryModel> createRecord(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_gallery').insert(data).select().single();
    return GalleryModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> updateCaption(String id, String? caption) async {
    await _c
        .from('thix_weeding_gallery')
        .update({'caption': caption}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_gallery').delete().eq('id', id);
  }

  /// ✅ AJOUTÉ — Supprimer le fichier du storage aussi
  Future<void> deleteWithStorage(String id, String imageUrl) async {
    // Extraire le path depuis l'URL publique
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // Le path est typiquement: /storage/v1/object/public/thix-weeding-gallery/weddingId/timestamp.ext
      final bucketIndex = pathSegments.indexOf(_bucket);
      if (bucketIndex >= 0 && bucketIndex + 1 < pathSegments.length) {
        final storagePath =
            pathSegments.sublist(bucketIndex + 1).join('/');
        await _c.storage.from(_bucket).remove([storagePath]);
      }
    } catch (_) {
      // Ignorer les erreurs de suppression storage (le record DB sera quand même supprimé)
    }

    await _c.from('thix_weeding_gallery').delete().eq('id', id);
  }

  /// ✅ AJOUTÉ — Compter les médias
  Future<int> getCount(String weddingId) async {
    final res = await _c
        .from('thix_weeding_gallery')
        .select('id')
        .eq('wedding_id', weddingId);
    return (res as List).length;
  }
}

// ============================================================================
// GUESTBOOK SERVICE
// ============================================================================
class GuestbookService {
  final _c = Supabase.instance.client;

  Future<List<GuestbookModel>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_guestbook')
        .select()
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res)
        .map((e) => GuestbookModel.fromJson(e))
        .toList();
  }

  Future<void> toggleApproval(String id, bool v) async {
    await _c
        .from('thix_weeding_guestbook')
        .update({'is_approved': v}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_guestbook').delete().eq('id', id);
  }

  /// ✅ AJOUTÉ — Approuver tous les messages en attente
  Future<void> approveAll(String weddingId) async {
    await _c
        .from('thix_weeding_guestbook')
        .update({'is_approved': true})
        .eq('wedding_id', weddingId)
        .eq('is_approved', false);
  }
}

// ============================================================================
// MESSAGE SERVICE
// ============================================================================
class MessageService {
  final _c = Supabase.instance.client;

  Future<List<MessageModel>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_messages')
        .select()
        .eq('wedding_id', weddingId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(res)
        .map((e) => MessageModel.fromJson(e))
        .toList();
  }

  Future<MessageModel> send(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_messages').insert(data).select().single();
    return MessageModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> markAllRead(String weddingId) async {
    await _c
        .from('thix_weeding_messages')
        .update({'is_read': true})
        .eq('wedding_id', weddingId)
        .eq('is_read', false);
  }

  /// ✅ AJOUTÉ — Marquer un seul message comme lu
  Future<void> markAsRead(String id) async {
    await _c
        .from('thix_weeding_messages')
        .update({'is_read': true}).eq('id', id);
  }

  /// ✅ AJOUTÉ — Compter les messages non lus
  Future<int> getUnreadCount(String weddingId) async {
    final res = await _c
        .from('thix_weeding_messages')
        .select('id')
        .eq('wedding_id', weddingId)
        .eq('is_read', false);
    return (res as List).length;
  }
}

// ============================================================================
// PAYMENT SERVICE
// ============================================================================
class PaymentService {
  final _c = Supabase.instance.client;

  Future<List<PaymentModel>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_payments')
        .select('*, thix_weeding_vendors(name), thix_weeding_expenses(title)')
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res)
        .map((e) => PaymentModel.fromJson(e))
        .toList();
  }

  Future<PaymentModel> getById(String id) async {
    final res = await _c
        .from('thix_weeding_payments')
        .select('*, thix_weeding_vendors(name), thix_weeding_expenses(title)')
        .eq('id', id)
        .single();
    return PaymentModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<PaymentModel> create(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_payments').insert(data).select().single();
    return PaymentModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _c.from('thix_weeding_payments').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_payments').delete().eq('id', id);
  }

  /// ✅ AJOUTÉ — Mettre à jour le statut d'un paiement
  Future<void> updateStatus(String id, String status) async {
    await _c
        .from('thix_weeding_payments')
        .update({'status': status}).eq('id', id);
  }
}

// ============================================================================
// BUDGET SERVICE
// ============================================================================
class BudgetService {
  final _c = Supabase.instance.client;

  Future<BudgetModel?> getBudget(String weddingId) async {
    try {
      final res = await _c
          .from('thix_weeding_budgets')
          .select()
          .eq('wedding_id', weddingId)
          .maybeSingle();
      if (res == null) return null;
      return BudgetModel.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(String weddingId, double amount) async {
    await _c.from('thix_weeding_budgets').upsert({
      'wedding_id': weddingId,
      'total_budget': amount,
    }, onConflict: 'wedding_id');
  }

  Future<List<ExpenseModel>> getExpenses(String weddingId) async {
    try {
      final res = await _c
          .from('thix_weeding_expenses')
          .select()
          .eq('wedding_id', weddingId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res)
          .map((e) => ExpenseModel.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// ✅ AJOUTÉ — Créer une dépense
  Future<ExpenseModel> createExpense(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_expenses').insert(data).select().single();
    return ExpenseModel.fromJson(Map<String, dynamic>.from(res));
  }

  /// ✅ AJOUTÉ — Supprimer une dépense
  Future<void> deleteExpense(String id) async {
    await _c.from('thix_weeding_expenses').delete().eq('id', id);
  }

  /// ✅ AJOUTÉ — Mettre à jour une dépense
  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    await _c.from('thix_weeding_expenses').update(data).eq('id', id);
  }

  /// ✅ AJOUTÉ — Toggle is_paid sur une dépense
  Future<void> toggleExpensePaid(String id, bool isPaid) async {
    await _c
        .from('thix_weeding_expenses')
        .update({'is_paid': isPaid}).eq('id', id);
  }
}

// ============================================================================
// SEATING SERVICE — Plan de table 3D
// Tables: thix_weeding_tables + thix_weeding_seating_layout
// ============================================================================
class SeatingService {
  final _c = Supabase.instance.client;

  Future<List<SeatingTableModel>> getTables(String weddingId) async {
    final res = await _c
        .from('thix_weeding_tables')
        .select()
        .eq('wedding_id', weddingId)
        .order('order_index');
    return List<Map<String, dynamic>>.from(res)
        .map((e) => SeatingTableModel.fromJson(e))
        .toList();
  }

  Future<SeatingLayoutModel> getLayout(String weddingId) async {
    final tables = await getTables(weddingId);
    final row = await _c
        .from('thix_weeding_seating_layout')
        .select()
        .eq('wedding_id', weddingId)
        .maybeSingle();
    if (row == null) {
      return SeatingLayoutModel(weddingId: weddingId, tables: tables);
    }
    return SeatingLayoutModel.fromJson(Map<String, dynamic>.from(row), tables);
  }

  Future<SeatingTableModel> createTable(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_tables').insert(data).select().single();
    return SeatingTableModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> updateTable(String id, Map<String, dynamic> data) async {
    await _c.from('thix_weeding_tables').update(data).eq('id', id);
  }

  Future<void> deleteTable(String id) async {
    await _c.from('thix_weeding_tables').delete().eq('id', id);
  }

  Future<void> saveLayout(String weddingId, Map<String, dynamic> data) async {
    final existing = await _c
        .from('thix_weeding_seating_layout')
        .select('id')
        .eq('wedding_id', weddingId)
        .maybeSingle();
    final payload = {...data, 'wedding_id': weddingId};
    if (existing == null) {
      await _c.from('thix_weeding_seating_layout').insert(payload);
    } else {
      await _c
          .from('thix_weeding_seating_layout')
          .update(payload)
          .eq('wedding_id', weddingId);
    }
  }

  Future<void> assignGuestToTable({
    required String guestId,
    required int? tableNumber,
    String? seatId,
  }) async {
    await _c.from('thix_weeding_guests').update({
      'table_number': tableNumber,
      'seat_id': seatId,
    }).eq('id', guestId);
  }
}

// ============================================================================
// PROFILE / THIX HUB SEARCH
// ============================================================================
class ThixProfileService {
  final _c = Supabase.instance.client;

  Future<ThixProfileLite?> findByThixId(String thixId) async {
    final clean = thixId.trim().toUpperCase();
    if (clean.length < 4) return null;
    final res = await _c
        .from('profiles')
        .select(
            'id, thix_id, display_name, full_name, contact_phone, phone_number, avatar_url, photo_url, username')
        .eq('thix_id', clean)
        .maybeSingle();
    if (res == null) return null;
    return ThixProfileLite.fromJson(Map<String, dynamic>.from(res));
  }
}
