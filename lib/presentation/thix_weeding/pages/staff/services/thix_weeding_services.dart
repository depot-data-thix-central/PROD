// lib/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';

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
    await _c
        .from('thix_weeding_weddings')
        .update({'invitation_published': true}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_weddings').delete().eq('id', id);
  }
}

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
}

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
}

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
}

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

  /// Upload compatible Web + Mobile (pas de dart:io)
  Future<String> uploadBytes({
    required String weddingId,
    required Uint8List bytes,
    String fileName = 'photo.jpg',
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final safeExt =
        (ext == 'png' || ext == 'webp' || ext == 'jpg' || ext == 'jpeg')
            ? ext
            : 'jpg';
    final path =
        '\( weddingId/ \){DateTime.now().millisecondsSinceEpoch}.$safeExt';

    await _c.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: safeExt == 'png'
                ? 'image/png'
                : (safeExt == 'webp' ? 'image/webp' : 'image/jpeg'),
          ),
        );

    return _c.storage.from(_bucket).getPublicUrl(path);
  }

  Future<GalleryModel> createRecord(Map<String, dynamic> data) async {
    final res =
        await _c.from('thix_weeding_gallery').insert(data).select().single();
    return GalleryModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    await _c.from('thix_weeding_gallery').delete().eq('id', id);
  }
}

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
}

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
}

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
}

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
}
