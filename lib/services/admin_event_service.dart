import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/admin_audit_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class AdminEventService {
  AdminEventService({SupabaseClient? client, AdminAuditService? audit})
      : _client = client ?? SupabaseConfig.client,
        _audit = audit ?? AdminAuditService();

  final SupabaseClient _client;
  final AdminAuditService _audit;

  static const String eventsTable = 'thix_events';
  static const String registrationsTable = 'thix_event_registrations';
  static const String eventsStatusView = 'thix_events_status';
  static const String coverBucketDefault = 'thix-events';

  Future<List<Map<String, dynamic>>> listEvents({int limit = 200}) async {
    try {
      // Prefer the status view (registrations count + places remaining + sold-out).
      final res = await _client
          .from(eventsStatusView)
          .select('*')
          .order('starts_at', ascending: false)
          .limit(limit);
      if (res is List) return res.cast<Map<String, dynamic>>();
      return const [];
    } catch (e) {
      debugPrint('AdminEventService.listEvents failed err=$e');
      rethrow;
    }
  }

  Future<int> countRegistrations({required String eventId}) async {
    try {
      final res = await _client.from(registrationsTable).select('id').eq('event_id', eventId);
      if (res is List) return res.length;
      return 0;
    } catch (e) {
      debugPrint('AdminEventService.countRegistrations failed err=$e');
      return 0;
    }
  }

  /// Creates or updates an event. Returns the event id.
  Future<String> upsertEvent({
    String? id,
    required String title,
    required DateTime startsAt,
    required String place,
    String? virtualLink,
    String status = 'published',
    // New fields (optional; safe when columns don't exist yet, but will fail if
    // you call this before applying SQL migrations).
    bool? isFeatured,
    String? quickHook,
    String? category,
    int? maxParticipants,
    bool? isFree,
    num? price,
    String? eventType,
    String? meetingLink,
    String? organizer,
    String? coverImageBucket,
    String? coverImagePath,
    DateTime? endsAt,
    String? description,
    List<String>? highlights,
    List<Map<String, dynamic>>? speakers,
    List<Map<String, dynamic>>? sponsors,
    List<Map<String, dynamic>>? agenda,
    String? actorRole,
  }) async {
    final payload = <String, dynamic>{
      if (id != null && id.trim().isNotEmpty) 'id': id.trim(),
      'title': title.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
      'place': place.trim(),
      'virtual_link': (virtualLink ?? '').trim().isEmpty ? null : virtualLink!.trim(),
      'status': status,
      if (isFeatured != null) 'is_featured': isFeatured,
      if (quickHook != null) 'quick_hook': quickHook.trim().isEmpty ? null : quickHook.trim(),
      if (category != null) 'category': category.trim().isEmpty ? null : category.trim(),
      if (maxParticipants != null) 'max_participants': maxParticipants,
      if (isFree != null) 'is_free': isFree,
      if (price != null) 'price': price,
      if (eventType != null) 'event_type': eventType,
      if (meetingLink != null) 'meeting_link': meetingLink.trim().isEmpty ? null : meetingLink.trim(),
      if (organizer != null) 'organizer': organizer.trim().isEmpty ? null : organizer.trim(),
      if (coverImageBucket != null) 'cover_image_bucket': coverImageBucket.trim().isEmpty ? null : coverImageBucket.trim(),
      if (coverImagePath != null) 'cover_image_path': coverImagePath.trim().isEmpty ? null : coverImagePath.trim(),
      if (description != null) 'description': description.trim().isEmpty ? null : description.trim(),
      if (highlights != null) 'highlights': highlights,
      if (speakers != null) 'speakers': speakers,
      if (sponsors != null) 'sponsors': sponsors,
      if (agenda != null) 'agenda': agenda,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res = await _client.from(eventsTable).upsert(payload).select('id').maybeSingle();
      final eventId = (res?['id'] ?? id ?? '').toString();
      await _audit.log(
        action: (id == null || id.trim().isEmpty) ? 'event_create' : 'event_update',
        entityType: eventsTable,
        entityId: eventId.isEmpty ? null : eventId,
        actorRole: actorRole,
        metadata: {
          'title': title.trim(),
          'starts_at': payload['starts_at'],
          'place': place.trim(),
          'virtual_link': payload['virtual_link'],
          'status': status,
          if (isFeatured != null) 'is_featured': isFeatured,
          if (category != null) 'category': category,
          if (maxParticipants != null) 'max_participants': maxParticipants,
          if (isFree != null) 'is_free': isFree,
          if (price != null) 'price': price,
          if (eventType != null) 'event_type': eventType,
          if (endsAt != null) 'ends_at': payload['ends_at'],
        },
      );
      return eventId;
    } catch (e) {
      debugPrint('AdminEventService.upsertEvent failed err=$e');
      rethrow;
    }
  }

  Future<void> updateCoverImage({
    required String eventId,
    required String bucket,
    required String storagePath,
    String? actorRole,
  }) async {
    final id = eventId.trim();
    if (id.isEmpty) return;
    try {
      await _client.from(eventsTable).update({
        'cover_image_bucket': bucket.trim().isEmpty ? coverBucketDefault : bucket.trim(),
        'cover_image_path': storagePath.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await _audit.log(
        action: 'event_cover_update',
        entityType: eventsTable,
        entityId: id,
        actorRole: actorRole,
        metadata: {'cover_image_bucket': bucket, 'cover_image_path': storagePath},
      );
    } catch (e) {
      debugPrint('AdminEventService.updateCoverImage failed err=$e');
      rethrow;
    }
  }

  Future<void> deleteEvent({required String id, String? actorRole}) async {
    try {
      await _client.from(eventsTable).delete().eq('id', id);
      await _audit.log(action: 'event_delete', entityType: eventsTable, entityId: id, actorRole: actorRole);
    } catch (e) {
      debugPrint('AdminEventService.deleteEvent failed err=$e');
      rethrow;
    }
  }
}
