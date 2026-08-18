import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class DocumentService {
  static const String table = 'documents';
  static const String bucket = 'documents';
  static const String sharesTable = 'document_shares';
  static const String screenshotsTable = 'document_share_screenshots';
  static const String foldersTable = 'document_folders';
  static const String transactionsTable = 'document_transactions';
  static const String vaultLocksTable = 'vault_locks';

  final SupabaseClient _client;
  DocumentService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  static final Map<String, _UrlCache> _urlCache = {};
  SupabaseClient get _db => _client;

  // ---------------------------------------------------------------------------
  // Helpers internes
  // ---------------------------------------------------------------------------

  Future<T> _retry<T>(Future<T> Function() fn) async {
    for (int i = 0; i < 3; i++) {
      try {
        return await fn();
      } catch (_) {
        if (i == 2) rethrow;
        await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
      }
    }
    throw StateError('retry failed');
  }

  static bool isBucketNotFound(Object e) {
    if (e is! StorageException) return false;
    return e.statusCode == 404 && e.message.toLowerCase().contains('bucket');
  }

  static String _mime(PlatformFile f) {
    const m = {
      'pdf': 'application/pdf',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
    };
    return m[(f.extension ?? '').toLowerCase()] ?? 'application/octet-stream';
  }

  Future<void> _logTransaction({
    required String uid,
    String? documentId,
    String? docId,
    required String action,
    String? detail,
  }) async {
    try {
      await _db.from(transactionsTable).insert({
        'user_id': uid,
        'document_id': documentId,
        'doc_id': docId,
        'action': action,
        'detail': detail,
      });
    } catch (e) {
      debugPrint('DocumentService: log transaction failed → $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Upload de base (Storage)
  // ---------------------------------------------------------------------------

  Future<String> uploadPickedFileToBucket({
    required String bucketName,
    required String uid,
    required String objectPath,
    required PlatformFile file,
    bool upsert = true,
  }) async {
    final mime = _mime(file);
    return _retry(() async {
      final st = _db.storage.from(bucketName);
      if (kIsWeb) {
        return await st.uploadBinary(
          objectPath,
          file.bytes!,
          fileOptions: FileOptions(upsert: upsert, contentType: mime),
        );
      } else {
        return await st.upload(
          objectPath,
          fileFromPath(file.path!) as dynamic,
          fileOptions: FileOptions(upsert: upsert, contentType: mime),
        );
      }
    });
  }

  Future<void> deleteObjectFromBucket({
    required String bucketName,
    required String storagePath,
  }) async {
    await _db.storage.from(bucketName).remove([storagePath]);
  }

  // ---------------------------------------------------------------------------
  // Génération d'identifiant unique
  // ---------------------------------------------------------------------------

  Future<String> generateDocumentId(String uid) async {
    final res = await _db.rpc('generate_thix_doc_id', params: {'p_user_id': uid});
    final id = (res as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw Exception('Impossible de générer l\'identifiant du document');
    }
    return id;
  }

  // ---------------------------------------------------------------------------
  // Dossiers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchFolders(String uid) async {
    final res = await _db
        .from(foldersTable)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: true);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Stream<List<Map<String, dynamic>>> streamFolders(String uid) {
    return _db
        .from(foldersTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: true)
        .map((rows) => rows.cast<Map<String, dynamic>>().toList());
  }

  Future<String> createFolder({
    required String uid,
    required String name,
    String icon = 'folder',
    String color = '#2D6CDF',
  }) async {
    final res = await _db
        .from(foldersTable)
        .insert({'user_id': uid, 'name': name.trim(), 'icon': icon, 'color': color})
        .select('id')
        .single();
    final id = res['id'].toString();
    await _logTransaction(uid: uid, action: 'folder_create', detail: name.trim());
    return id;
  }

  Future<void> deleteFolder({required String uid, required String folderId}) async {
    await _db.from(foldersTable).delete().eq('id', folderId).eq('user_id', uid);
  }

  // ---------------------------------------------------------------------------
  // Upload simplifié
  // ---------------------------------------------------------------------------

  Future<String> uploadPickedFileSimple({
    required String uid,
    required PlatformFile file,
    required String docType,
    DateTime? expiresAt,
    String? title,
    String? folderId,
    bool isPublic = false,
  }) async {
    if (file.size > 15 * 1024 * 1024) {
      throw Exception('Fichier trop volumineux (> 15 Mo)');
    }

    final generatedId = await generateDocumentId(uid);
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'users/$uid/$generatedId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await uploadPickedFileToBucket(
      bucketName: bucket,
      uid: uid,
      objectPath: path,
      file: file,
    );

    String? insertedId;
    try {
      final row = await _db.from(table).insert({
        'user_id': uid,
        'doc_id': generatedId,
        'generated_doc_id': generatedId,
        'title': (title?.trim().isNotEmpty == true) ? title!.trim() : file.name,
        'doc_type': docType,
        'status': 'uploaded',
        'file_name': file.name,
        'mime_type': _mime(file),
        'size_bytes': file.size,
        'storage_path': path,
        'expires_at': expiresAt?.toIso8601String(),
        'country_code': generatedId.contains('/') ? generatedId.split('/').last : null,
        'folder_id': folderId,
        'is_public': isPublic,
      }).select('id').single();
      insertedId = row['id'].toString();
    } catch (e) {
      await _db.storage.from(bucket).remove([path]).catchError((_) => []);
      rethrow;
    }

    await _logTransaction(
      uid: uid,
      documentId: insertedId,
      docId: generatedId,
      action: 'upload',
      detail: file.name,
    );

    return generatedId;
  }

  // ---------------------------------------------------------------------------
  // Ancienne méthode (compatibilité)
  // ---------------------------------------------------------------------------

  Future<String> uploadPickedFile({
    required String uid,
    required String docId,
    required String title,
    required PlatformFile file,
    String? docType,
    DateTime? expiresAt,
  }) async {
    if (file.size > 15 * 1024 * 1024) throw Exception('Fichier > 15 Mo');

    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final p = 'users/$uid/${docId.toUpperCase()}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await uploadPickedFileToBucket(
      bucketName: bucket,
      uid: uid,
      objectPath: p,
      file: file,
    );

    try {
      await _db.from(table).insert({
        'user_id': uid,
        'doc_id': docId.toUpperCase(),
        'title': title.trim().isEmpty ? file.name : title.trim(),
        'doc_type': docType,
        'status': 'uploaded',
        'file_name': file.name,
        'mime_type': _mime(file),
        'size_bytes': file.size,
        'storage_path': p,
        'expires_at': expiresAt?.toIso8601String(),
      });
    } catch (e) {
      await _db.storage.from(bucket).remove([p]).catchError((_) => []);
      rethrow;
    }
    return p;
  }

  // ---------------------------------------------------------------------------
  // Lecture / Stream / Suppression
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchDocumentsPaginated(
    String uid, {
    int limit = 20,
    int offset = 0,
    String? folderId,
  }) =>
      _retry(() async {
        var q = _db
            .from(table)
            .select(
              'id,doc_id,generated_doc_id,title,doc_type,status,file_name,mime_type,size_bytes,storage_path,created_at,expires_at,country_code,folder_id,is_public',
            )
            .eq('user_id', uid);
        if (folderId != null) q = q.eq('folder_id', folderId);
        final res = await q.order('created_at', ascending: false).range(offset, offset + limit - 1);
        return (res as List).cast<Map<String, dynamic>>();
      });

  Future<List<Map<String, dynamic>>> fetchDocuments(String uid, {int limit = 20}) =>
      fetchDocumentsPaginated(uid, limit: limit, offset: 0);

  Stream<List<Map<String, dynamic>>> streamDocuments(String uid) {
    return _db
        .from(table)
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.cast<Map<String, dynamic>>().toList());
  }

  Future<Map<String, dynamic>?> fetchDocumentById(String documentId) async {
    final res = await _db.from(table).select().eq('id', documentId).maybeSingle();
    return res == null ? null : (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> fetchLatestDocumentRowByDocId({
    required String uid,
    required String docId,
  }) async {
    final r = await _db
        .from(table)
        .select()
        .eq('user_id', uid)
        .eq('doc_id', docId.toUpperCase())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return r == null ? null : (r as Map).cast<String, dynamic>();
  }

  Future<void> deleteDocument({
    required String uid,
    required String documentId,
    String? storagePath,
    String? docId,
  }) async {
    await _db.from(table).delete().eq('id', documentId).eq('user_id', uid);
    if (storagePath != null && storagePath.isNotEmpty) {
      await _db.storage.from(bucket).remove([storagePath]).catchError((_) => []);
    }
    await _logTransaction(uid: uid, documentId: documentId, docId: docId, action: 'delete');
  }

  Future<void> deleteLatestDocumentByDocId({
    required String uid,
    required String docId,
  }) async {
    final r = await fetchLatestDocumentRowByDocId(uid: uid, docId: docId);
    if (r != null) {
      await deleteDocument(
        uid: uid,
        documentId: r['id'].toString(),
        storagePath: r['storage_path']?.toString(),
        docId: docId,
      );
    }
  }

  Future<void> updateDocumentStatus({
    required String uid,
    required String documentId,
    required String status,
  }) async {
    await _db.from(table).update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', documentId).eq('user_id', uid);
  }

  Future<void> togglePublic({
    required String uid,
    required String documentId,
    required String? docId,
    required bool isPublic,
  }) async {
    await _db.from(table).update({
      'is_public': isPublic,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', documentId).eq('user_id', uid);
    await _logTransaction(
      uid: uid,
      documentId: documentId,
      docId: docId,
      action: 'public_toggle',
      detail: isPublic ? 'public' : 'privé',
    );
  }

  // ---------------------------------------------------------------------------
  // Recherche publique
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> searchPublicDocument(String docId) async {
    if (docId.trim().isEmpty) return null;
    final res = await _db.rpc('search_public_document', params: {'p_doc_id': docId.trim()});
    if (res == null) return null;
    final list = (res as List);
    if (list.isEmpty) return null;
    return (list.first as Map).cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // Vérification THIX ID
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> verifyThixId(String thixId) async {
    final clean = thixId.trim().toUpperCase();
    if (clean.isEmpty) return null;
    final res = await _db
        .from('profiles')
        .select('id, thix_id, full_name')
        .eq('thix_id', clean)
        .maybeSingle();
    return res == null ? null : (res as Map).cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // URLs signées
  // ---------------------------------------------------------------------------

  Future<String> createDownloadUrl({
    required String storagePath,
    Duration expiresIn = const Duration(minutes: 18),
    String bucketName = bucket,
  }) async {
    final key = '$bucketName::$storagePath';
    if (_urlCache[key]?.isValid == true) return _urlCache[key]!.url;

    final url = await _retry(() => _db.storage
        .from(bucketName)
        .createSignedUrl(storagePath.trim(), expiresIn.inSeconds.clamp(60, 3600)));

    _urlCache[key] = _UrlCache(url);
    return url;
  }

  Future<String> resolveRowDownloadUrl(Map<String, dynamic> row) async {
    final sp = (row['storage_path'] ?? '').toString().trim();
    if (sp.isEmpty) return (row['download_url'] ?? '').toString();
    return createDownloadUrl(storagePath: sp);
  }

  // ---------------------------------------------------------------------------
  // Hash / Verify (local pour Vault + Edge Function pour partages)
  // ---------------------------------------------------------------------------

  Future<String?> _hashSecret(String action, String secret) async {
    // Vault → hash local (SHA-256)
    if (action == 'vault') {
      final bytes = utf8.encode('${secret}THIX_VAULT_SALT_v1');
      return sha256.convert(bytes).toString();
    }

    // Partages → Edge Function
    try {
      final res = await _db.functions.invoke(
        'vault-share-password',
        body: {'action': 'hash', 'password': secret},
      );
      return res.data?['hash'] as String?;
    } catch (e) {
      debugPrint('DocumentService: hash failed ($action) → $e');
      return null;
    }
  }

  Future<bool> verifyPassword({
    required String password,
    required String hash,
  }) async {
    // Hash local (SHA-256 = 64 caractères hex, sans ":")
    if (hash.length == 64 && !hash.contains(':')) {
      final bytes = utf8.encode('${password}THIX_VAULT_SALT_v1');
      final computed = sha256.convert(bytes).toString();
      return computed == hash;
    }

    // Hash Edge Function
    try {
      final res = await _db.functions.invoke(
        'vault-share-password',
        body: {'action': 'verify', 'password': password, 'hash': hash},
      );
      return res.data?['valid'] == true;
    } catch (e) {
      debugPrint('DocumentService: verify password failed → $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PARTAGE / ENVOI DE DOCUMENTS
  // ---------------------------------------------------------------------------

  Future<void> shareDocument({
    required String senderId,
    required String documentId,
    String? docId,
    required List<String> recipientThixIds,
    String? subject,
    String? body,
    String? password,
    DateTime? availableFrom,
    Duration? autoDestructIn,
  }) async {
    final cleanIds = recipientThixIds
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (cleanIds.isEmpty) {
      throw Exception('Aucun destinataire valide');
    }

    final profiles = await _db
        .from('profiles')
        .select('id, thix_id')
        .inFilter('thix_id', cleanIds);

    final mapThixToUid = <String, String>{};
    for (final p in (profiles as List)) {
      final tid = (p['thix_id'] as String?)?.toUpperCase();
      if (tid != null) mapThixToUid[tid] = p['id'] as String;
    }

    String? passwordHash;
    if (password != null && password.trim().isNotEmpty) {
      passwordHash = await _hashSecret('share', password.trim());
    }

    final now = DateTime.now().toUtc();
    final autoDestructAt = autoDestructIn != null ? now.add(autoDestructIn) : null;
    final rows = <Map<String, dynamic>>[];

    for (final thix in cleanIds) {
      final status = (availableFrom != null && availableFrom.isAfter(now))
          ? 'pending'
          : 'available';

      rows.add({
        'document_id': documentId,
        'sender_id': senderId,
        'recipient_user_id': mapThixToUid[thix],
        'recipient_thix_id': thix,
        'subject': subject?.trim(),
        'body': body?.trim(),
        'password_hash': passwordHash,
        'available_from': availableFrom?.toUtc().toIso8601String(),
        'auto_destruct_at': autoDestructAt?.toIso8601String(),
        'auto_destruct_seconds': autoDestructIn?.inSeconds,
        'status': status,
      });
    }

    await _db.from(sharesTable).insert(rows);
    await _logTransaction(
      uid: senderId,
      documentId: documentId,
      docId: docId,
      action: 'send',
      detail: '${cleanIds.length} destinataire(s)',
    );
  }

  // ---------------------------------------------------------------------------
  // Streams des partages
  // ---------------------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamReceivedShares(String uid, String thixId) {
    return _db
        .from(sharesTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
      final list = rows.cast<Map<String, dynamic>>();
      final upperThix = thixId.toUpperCase();
      return list.where((r) {
        final rid = (r['recipient_user_id'] as String?) ?? '';
        final rthix = ((r['recipient_thix_id'] as String?) ?? '').toUpperCase();
        return rid == uid || rthix == upperThix;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamSentShares(String uid) {
    return _db
        .from(sharesTable)
        .stream(primaryKey: ['id'])
        .eq('sender_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.cast<Map<String, dynamic>>().toList());
  }

  // ---------------------------------------------------------------------------
  // Actions sur les partages
  // ---------------------------------------------------------------------------

  Future<void> markShareOpened(String shareId, {String? uid, String? docId}) async {
    await _db.from(sharesTable).update({
      'status': 'opened',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', shareId);
    if (uid != null) {
      await _logTransaction(uid: uid, docId: docId, action: 'open');
    }
  }

  Future<void> markShareDestroyed(String shareId) async {
    await _db.from(sharesTable).update({
      'status': 'destroyed',
      'destroyed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', shareId);
  }

  Future<void> markShareExpired(String shareId) async {
    await _db.from(sharesTable).update({
      'status': 'expired',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', shareId);
  }

  // ---------------------------------------------------------------------------
  // Captures d'écran
  // ---------------------------------------------------------------------------

  Future<void> reportScreenshot({
    required String shareId,
    required String capturedBy,
    String? storagePath,
  }) async {
    await _db.from(screenshotsTable).insert({
      'share_id': shareId,
      'captured_by': capturedBy,
      'storage_path': storagePath,
    });

    try {
      await _db.rpc('increment_screenshot_count', params: {'p_share_id': shareId});
    } catch (_) {
      final current = await _db
          .from(sharesTable)
          .select('screenshot_count')
          .eq('id', shareId)
          .maybeSingle();

      final count = ((current?['screenshot_count'] as num?)?.toInt() ?? 0) + 1;

      await _db.from(sharesTable).update({
        'screenshot_count': count,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', shareId);
    }
    await _logTransaction(uid: capturedBy, action: 'screenshot');
  }

  // ---------------------------------------------------------------------------
  // Historique
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchTransactions(String uid, {int limit = 50}) async {
    final res = await _db
        .from(transactionsTable)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Stream<List<Map<String, dynamic>>> streamTransactions(String uid) {
    return _db
        .from(transactionsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.cast<Map<String, dynamic>>().toList());
  }

  // ---------------------------------------------------------------------------
  // Verrou du panneau THIX VAULT (PIN)
  // ---------------------------------------------------------------------------

  Future<bool> hasVaultLock(String uid) async {
    final res = await _db.from(vaultLocksTable).select('user_id').eq('user_id', uid).maybeSingle();
    return res != null;
  }

  Future<void> setVaultPin({required String uid, required String pin}) async {
    final hash = await _hashSecret('vault', pin);
    if (hash == null) throw Exception('Impossible de sécuriser le code');
    await _db.from(vaultLocksTable).upsert({
      'user_id': uid,
      'pin_hash': hash,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<bool> verifyVaultPin({required String uid, required String pin}) async {
    final res = await _db.from(vaultLocksTable).select('pin_hash').eq('user_id', uid).maybeSingle();
    final hash = res?['pin_hash'] as String?;
    if (hash == null) return false;
    return verifyPassword(password: pin, hash: hash);
  }
}

// ---------------------------------------------------------------------------
// Cache URL signée
// ---------------------------------------------------------------------------

class _UrlCache {
  final String url;
  final DateTime at = DateTime.now();
  _UrlCache(this.url);
  bool get isValid => DateTime.now().difference(at).inMinutes < 15;
}
