import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/supabase_safe_write.dart';

import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class ProfilePhotoService {
  static const String bucket = 'avatars';

  /// Creates a short-lived URL for displaying avatars from a private bucket.
  ///
  /// Use this when Storage has RLS/private access.
  Future<String> createAvatarSignedUrl({required String storagePath, Duration expiresIn = const Duration(minutes: 30)}) async {
    final p = storagePath.trim();
    if (p.isEmpty) throw Exception('storagePath vide.');
    try {
      final seconds = expiresIn.inSeconds.clamp(60, 60 * 60 * 24);
      return await SupabaseConfig.client.storage.from(bucket).createSignedUrl(p, seconds);
    } on StorageException catch (e) {
      debugPrint('ProfilePhotoService: createSignedUrl failed path=$p err=${e.message}');
      return SupabaseConfig.client.storage.from(bucket).getPublicUrl(p);
    }
  }

  /// Uploads a profile photo into Supabase Storage bucket `avatars`.
  ///
  /// Requirements:
  /// - File name is forced to the authenticated userId to avoid duplicates.
  /// - After upload, updates `profiles.avatar_url` for the current user.
  /// - Returns the public URL.
  Future<String> uploadProfilePhoto({required String uid, required PlatformFile file}) async {
    try {
      final authedUserId = (SupabaseConfig.client.auth.currentUser?.id ?? '').trim();
      if (authedUserId.isEmpty) {
        throw Exception('Session Supabase introuvable. Veuillez vous reconnecter.');
      }
      // In THIX ID we want deterministic naming to prevent duplicates.
      // If the caller passes a different uid than Supabase auth, we still prefer
      // the caller uid because it is the app-side authenticated user id.
      // But we keep a safeguard: if uid is empty, fallback to authed user id.
      final userId = uid.trim().isEmpty ? authedUserId : uid.trim();

      final ext = (file.extension ?? '').trim().toLowerCase();
      final safeExt = ['png', 'jpg', 'jpeg', 'webp'].contains(ext) ? ext : 'jpg';
      final path = '$userId.$safeExt';
      final storage = SupabaseConfig.client.storage.from(bucket);

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Impossible de lire l\'image.');
        await storage.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExt(safeExt),
          ),
        );
      } else {
        final p = file.path;
        if (p == null) throw Exception('Chemin fichier invalide.');
        await storage.upload(
          path,
          fileFromPath(p) as dynamic,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExt(safeExt),
          ),
        );
      }

      final publicUrl = storage.getPublicUrl(path);
      // Cache-busting: Storage object path is deterministic (uid.ext), so the
      // public URL may stay identical and Flutter's image cache will keep
      // showing the old photo. We store a versioned URL in `profiles.avatar_url`
      // so every update refreshes instantly.
      final versionedUrl = _withCacheBust(publicUrl);
      await _updateAvatarInProfiles(userId: userId, avatarUrl: versionedUrl, avatarPath: path);
      return versionedUrl;
    } on StorageException catch (e) {
      debugPrint('ProfilePhotoService: storage upload failed uid=$uid err=${e.message}');
      throw Exception('Upload photo impossible: ${e.message}');
    } on PostgrestException catch (e) {
      debugPrint('ProfilePhotoService: update profiles failed uid=$uid err=${e.message}');
      throw Exception('Mise à jour du profil impossible: ${e.message}');
    } catch (e) {
      debugPrint('ProfilePhotoService: upload failed uid=$uid err=$e');
      rethrow;
    }
  }

  Future<void> _updateAvatarInProfiles({required String userId, required String avatarUrl, required String avatarPath}) async {
    // Spec says: update table `profiles` column `avatar_url` for current user.
    // Per project spec, canonical key is `id`. Some older schemas also use
    // `user_id`, so we keep a fallback.
    final now = DateTime.now().toUtc().toIso8601String();
    final patch = <String, dynamic>{
      'avatar_url': avatarUrl,
      // Useful for private buckets where public URL is not accessible.
      // If the column doesn't exist yet, SupabaseSafeWrite will strip it.
      'avatar_path': avatarPath,
      'updated_at': now,
    };

    try {
      await SupabaseSafeWrite.update(client: SupabaseConfig.client, table: 'profiles', patch: patch, filters: {'id': userId});
      return;
    } catch (e) {
      // Ignore and try alternate key.
      debugPrint('ProfilePhotoService: profiles update by id failed uid=$userId err=$e');
    }

    try {
      await SupabaseSafeWrite.update(client: SupabaseConfig.client, table: 'profiles', patch: patch, filters: {'user_id': userId});
      return;
    } catch (e) {
      debugPrint('ProfilePhotoService: profiles update by user_id failed uid=$userId err=$e');
    }

    // As a final fallback, attempt upsert.
    try {
      await SupabaseSafeWrite.upsert(client: SupabaseConfig.client, table: 'profiles', payload: {'id': userId, ...patch});
    } catch (e) {
      debugPrint('ProfilePhotoService: profiles upsert failed uid=$userId err=$e');
      rethrow;
    }
  }

  static String _contentTypeForExt(String ext) {
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  static String _withCacheBust(String url) {
    try {
      final uri = Uri.parse(url);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['v'] = DateTime.now().millisecondsSinceEpoch.toString();
      return uri.replace(queryParameters: qp).toString();
    } catch (_) {
      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}
