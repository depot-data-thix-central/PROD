// lib/presentation/thix_sante/patient/services/health_record_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health_record_model.dart';

class HealthRecordService {
  HealthRecordService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;
  static const String _bucket = 'health_docs';
  static const String _table = 'health_records';

  Future<List<HealthRecordModel>> getMyRecords({RecordType? filterType}) async {
    final String uid = _db.auth.currentUser!.id;
    // eq AVANT order, sinon erreur PostgrestTransformBuilder
    final PostgrestFilterBuilder<List<Map<String, dynamic>>> base =
        _db.from(_table).select().eq('patient_uid', uid);

    final List<dynamic> data;
    if (filterType != null) {
      data = await base.eq('type', filterType.name).order('created_at', ascending: false);
    } else {
      data = await base.order('created_at', ascending: false);
    }
    return data.map((e) => HealthRecordModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Stream<List<HealthRecordModel>> watchMyRecords() {
    final String uid = _db.auth.currentUser!.id;
    return _db.from(_table).stream(primaryKey: ['id']).eq('patient_uid', uid).map((rows) {
      final List<Map<String, dynamic>> filtered = rows.map((e) => e as Map<String, dynamic>).toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return filtered.map(HealthRecordModel.fromJson).toList();
    });
  }

  Future<String> uploadMedicalFile({required String fileName, required Uint8List bytes, required String mimeType}) async {
    final String uid = _db.auth.currentUser!.id;
    final String path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _db.storage.from(_bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType, upsert: false));
    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  Future<HealthRecordModel> createRecord({
    required String title,
    required RecordType type,
    String? description,
    String? fileName,
    Uint8List? fileBytes,
    String? mimeType,
    DateTime? examDate,
  }) async {
    final user = _db.auth.currentUser!;
    final myProfile = await _db.from('profiles').select('thix_id').eq('uid', user.id).single();

    String? fileUrl;
    int? fileSize;
    if (fileBytes != null && fileName != null && mimeType != null) {
      fileUrl = await uploadMedicalFile(fileName: fileName, bytes: fileBytes, mimeType: mimeType);
      fileSize = fileBytes.length;
    }

    final payload = {
      'patient_uid': user.id,
      'patient_thix_id': myProfile['thix_id'],
      'title': title,
      'type': type.name,
      'description': description,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'created_by_uid': user.id,
      'exam_date': examDate?.toIso8601String(),
    };
    final inserted = await _db.from(_table).insert(payload).select().single();
    return HealthRecordModel.fromJson(inserted);
  }

  Future<String> getSignedDownloadUrl(String filePath) async {
    return await _db.storage.from(_bucket).createSignedUrl(filePath, 3600);
  }

  Future<void> deleteRecord(String id) async {
    final String uid = _db.auth.currentUser!.id;
    
    // 1. Récupération de l'enregistrement pour identifier s'il y a un fichier associé dans le Storage
    final data = await _db.from(_table).select('file_url').eq('id', id).eq('patient_uid', uid).maybeSingle();

    // 2. Suppression du fichier dans le Storage (s'il existe)
    if (data != null && data['file_url'] != null) {
      try {
        final String fileUrl = data['file_url'] as String;
        final String path = fileUrl.split('$_bucket/').last.replaceFirst('/', '');
        await _db.storage.from(_bucket).remove([path]);
      } catch (_) {
        // Silencieux : on ignore si la suppression du fichier échoue
      }
    }
    
    // 3. Suppression de la ligne correspondante dans la base de données
    await _db.from(_table).delete().eq('id', id).eq('patient_uid', uid);
  }

  Future<Map<RecordType, int>> getStats() async {
    final String uid = _db.auth.currentUser!.id;
    final List data = await _db.from(_table).select('type').eq('patient_uid', uid);
    final Map<RecordType, int> counts = {};
    for (final row in data) {
      final t = RecordType.fromString(row['type'] as String?);
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts;
  }
}
