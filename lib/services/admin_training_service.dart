import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/admin_audit_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class AdminTrainingService {
  AdminTrainingService({SupabaseClient? client, AdminAuditService? audit})
      : _client = client ?? SupabaseConfig.client,
        _audit = audit ?? AdminAuditService();

  final SupabaseClient _client;
  final AdminAuditService _audit;

  static const String trainingsTable = 'thix_trainings';
  static const String trainingsStatusView = 'thix_trainings_status';
  static const String lessonsTable = 'thix_training_lessons';
  static const String enrollmentsTable = 'thix_training_enrollments';
  static const String certificatesTable = 'thix_training_certificates';

  static const String coverBucketDefault = 'thix-trainings';

  /// Liste toutes les formations (pour l'admin)
  Future<List<Map<String, dynamic>>> listTrainings({int limit = 300}) async {
    try {
      final res = await _client
          .from(trainingsTable)  // ← Utilise trainingsTable directement
          .select('*')
          .order('updated_at', ascending: false)
          .limit(limit);
      if (res is List) return res.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('AdminTrainingService.listTrainings failed err=$e');
      rethrow;
    }
  }

  /// Crée ou met à jour une formation
  Future<String> upsertTraining({
    String? id,
    required String title,
    String? tagline,
    String? description,
    required String category,
    required String level,
    required String language,
    required String deliveryMode,
    int? durationMinutes,
    bool isFree = false,
    num? priceAmount,
    String currency = 'USD',
    bool certificationIncluded = true,
    bool isFeatured = false,
    bool isPublished = true,
    String? instructorName,
    String? instructorTitle,
    String? instructorAvatarUrl,
    String? institutionName,
    String? institutionLogoUrl,
    String? requirements,
    List<String>? skills,
    DateTime? startDate,
    String? coverImageBucket,
    String? coverImagePath,
    String? actorRole,
  }) async {
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      if (id != null && id.trim().isNotEmpty) 'id': id.trim(),
      'title': title.trim(),
      'tagline': (tagline ?? '').trim().isEmpty ? null : tagline!.trim(),
      'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'level': level.trim().isEmpty ? 'Beginner' : level.trim(),
      'language': language.trim().isEmpty ? 'FR' : language.trim(),
      'delivery_mode': deliveryMode.trim().isEmpty ? 'online' : deliveryMode.trim(),
      'duration_minutes': durationMinutes,
      'is_free': isFree,
      'price_amount': priceAmount,
      'currency': currency.trim().isEmpty ? 'USD' : currency.trim(),
      'certification_included': certificationIncluded,
      'is_featured': isFeatured,
      'is_published': isPublished,
      'instructor_name': (instructorName ?? '').trim().isEmpty ? null : instructorName!.trim(),
      'instructor_title': (instructorTitle ?? '').trim().isEmpty ? null : instructorTitle!.trim(),
      'instructor_avatar_url': (instructorAvatarUrl ?? '').trim().isEmpty ? null : instructorAvatarUrl!.trim(),
      'institution_name': (institutionName ?? '').trim().isEmpty ? null : institutionName!.trim(),
      'institution_logo_url': (institutionLogoUrl ?? '').trim().isEmpty ? null : institutionLogoUrl!.trim(),
      'requirements': (requirements ?? '').trim().isEmpty ? null : requirements!.trim(),
      'skills': (skills ?? []).where((s) => s.trim().isNotEmpty).toList(),
      'start_date': startDate?.toUtc().toIso8601String(),
      if (coverImageBucket != null && coverImageBucket.trim().isNotEmpty) 'cover_image_bucket': coverImageBucket.trim(),
      if (coverImagePath != null && coverImagePath.trim().isNotEmpty) 'cover_image_path': coverImagePath.trim(),
      'updated_at': now.toIso8601String(),
    };

    try {
      final res = await _client
          .from(trainingsTable)
          .upsert(payload)
          .select('id')
          .maybeSingle();
      final trainingId = (res?['id'] ?? id ?? '').toString();
      
      await _audit.log(
        action: (id == null || id.trim().isEmpty) ? 'training_create' : 'training_update',
        entityType: trainingsTable,
        entityId: trainingId.isEmpty ? null : trainingId,
        actorRole: actorRole,
        metadata: {
          'title': payload['title'],
          'category': payload['category'],
          'level': payload['level'],
          'language': payload['language'],
          'delivery_mode': payload['delivery_mode'],
          'is_free': payload['is_free'],
          'price_amount': payload['price_amount'],
          'is_featured': payload['is_featured'],
          'is_published': payload['is_published'],
        },
      );
      return trainingId;
    } catch (e) {
      debugPrint('AdminTrainingService.upsertTraining failed err=$e');
      rethrow;
    }
  }

  /// Met à jour l'image de couverture
  Future<void> updateCoverImage({
    required String trainingId,
    required String bucket,
    required String storagePath,
    String? actorRole,
  }) async {
    final id = trainingId.trim();
    if (id.isEmpty) return;
    try {
      await _client
          .from(trainingsTable)
          .update({
            'cover_image_bucket': bucket.trim().isEmpty ? coverBucketDefault : bucket.trim(),
            'cover_image_path': storagePath.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
          
      await _audit.log(
        action: 'training_cover_update',
        entityType: trainingsTable,
        entityId: id,
        actorRole: actorRole,
        metadata: {'cover_image_bucket': bucket, 'cover_image_path': storagePath},
      );
    } catch (e) {
      debugPrint('AdminTrainingService.updateCoverImage failed err=$e');
      rethrow;
    }
  }

  /// Supprime une formation
  Future<void> deleteTraining({
    required String id,
    String? actorRole,
  }) async {
    final tid = id.trim();
    if (tid.isEmpty) return;
    try {
      await _client.from(trainingsTable).delete().eq('id', tid);
      await _audit.log(
        action: 'training_delete',
        entityType: trainingsTable,
        entityId: tid,
        actorRole: actorRole,
      );
    } catch (e) {
      debugPrint('AdminTrainingService.deleteTraining failed err=$e');
      rethrow;
    }
  }
}
