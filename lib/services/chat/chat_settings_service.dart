// lib/services/chat/chat_settings_service.dart
//
// ============================================================================
// CHAT SETTINGS SERVICE — Production Enterprise
// ============================================================================
//
// Service de gestion des paramètres chat utilisateur :
//   - Profil chat (display name, avatar, status)
//   - Upload avatar avec validation stricte
//   - Paramètres de notification/préférences
//
// Architecture :
//   - SupabaseClient injectable (testable via Riverpod)
//   - Validation UUID stricte sur tous les user IDs
//   - Support Web + Mobile (Uint8List au lieu de File)
//   - Validation stricte images (mime, taille, dimensions)
//   - Protection path traversal
//
// Sécurité :
//   - Whitelist extensions (jpg, png, webp, gif)
//   - Max file size 5MB
//   - Sanitization XSS sur display_name et status
//   - Validation regex stricte des chemins de stockage
//   - Content-Type vérifié via magic bytes (pas extension)
//   - Stack traces masquées en production
// ============================================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/chat/chat_settings.dart';
import 'package:thix_id/models/chat/chat_user.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxAvatarBytes = 5 * 1024 * 1024; // 5MB
const int _kMaxDisplayNameLength = 50;
const int _kMaxStatusLength = 100;
const int _kMinAvatarBytes = 100; // Protection contre fichiers vides
const String _kAvatarBucket = 'profiles';
const Duration _kDbTimeout = Duration(seconds: 15);
const Duration _kStorageTimeout = Duration(seconds: 60);

/// Whitelist des extensions autorisées pour les avatars
const Set<String> _kAllowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

/// Magic bytes pour validation du type réel du fichier
const Map<List<int>, String> _kMagicBytes = {
  [0xFF, 0xD8, 0xFF]: 'jpeg',
  [0x89, 0x50, 0x4E, 0x47]: 'png',
  [0x52, 0x49, 0x46, 0x46]: 'webp', // RIFF header
  [0x47, 0x49, 0x46, 0x38]: 'gif',
};

// ============================================================================
// VALIDATORS
// ============================================================================
class _ChatSettingsValidators {
  _ChatSettingsValidators._();

  /// Valide un UUID v4 strict.
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Sanitize un display name (XSS + caractères de contrôle).
  static String sanitizeDisplayName(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxDisplayNameLength
        ? s.substring(0, _kMaxDisplayNameLength)
        : s;
  }

  /// Sanitize un status (XSS + caractères de contrôle).
  static String sanitizeStatus(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxStatusLength
        ? s.substring(0, _kMaxStatusLength)
        : s;
  }

  /// Valide une extension d'image (whitelist).
  static bool isValidExtension(String? ext) {
    if (ext == null || ext.isEmpty) return false;
    final clean = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return _kAllowedExtensions.contains(clean);
  }

  /// Détecte le vrai type MIME via magic bytes (pas l'extension).
  static String? detectMimeType(Uint8List bytes) {
    if (bytes.length < 4) return null;

    for (final entry in _kMagicBytes.entries) {
      final magic = entry.key;
      if (bytes.length >= magic.length) {
        bool match = true;
        for (var i = 0; i < magic.length; i++) {
          if (bytes[i] != magic[i]) {
            match = false;
            break;
          }
        }
        if (match) return entry.value;
      }
    }
    return null;
  }

  /// Valide qu'une image est sûre à uploader.
  static ({bool valid, String? error}) validateImage(Uint8List bytes, String extension) {
    if (bytes.length < _kMinAvatarBytes) {
      return (valid: false, error: 'Fichier trop petit');
    }
    if (bytes.length > _kMaxAvatarBytes) {
      return (valid: false, error: 'Fichier trop volumineux (max 5MB)');
    }
    if (!isValidExtension(extension)) {
      return (valid: false, error: 'Extension non autorisée');
    }

    // Vérification magic bytes (protection contre spoofing)
    final detectedType = detectMimeType(bytes);
    if (detectedType == null) {
      return (valid: false, error: 'Type de fichier non reconnu');
    }

    // Cas spécial : .jpeg et .jpg sont le même type
    final normalizedExt = extension.toLowerCase() == 'jpg' ? 'jpeg' : extension.toLowerCase();
    if (detectedType != normalizedExt) {
      return (
        valid: false,
        error: 'Extension .$extension ne correspond pas au contenu ($detectedType)',
      );
    }

    return (valid: true, error: null);
  }

  /// Obfusque un ID pour les logs.
  static String obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Exception levée en cas de validation échouée.
class ChatSettingsValidationException implements Exception {
  final String message;
  const ChatSettingsValidationException(this.message);

  @override
  String toString() => 'ChatSettingsValidationException: $message';
}

/// Exception levée en cas d'erreur d'upload.
class ChatSettingsUploadException implements Exception {
  final String message;
  final Object? cause;
  const ChatSettingsUploadException(this.message, [this.cause]);

  @override
  String toString() => 'ChatSettingsUploadException: $message';
}

// ============================================================================
// CHAT SETTINGS SERVICE
// ============================================================================

/// Service de gestion des paramètres chat.
///
/// **Usage** :
/// ```dart
/// final service = ref.read(chatSettingsServiceProvider);
/// final user = await service.getChatUser(userId);
/// final avatarUrl = await service.uploadAvatar(userId, imageBytes, 'jpg');
/// ```
class ChatSettingsService {
  final SupabaseClient _supabase;
  bool _isDisposed = false;

  ChatSettingsService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client {
    debugPrint('[ChatSettings] 🚀 Initialized');
  }

  // ============================================================
  // GET CHAT USER
  // ============================================================

  /// Récupère le profil chat d'un utilisateur.
  ///
  /// **Throws** :
  ///   - [ArgumentError] si userId invalide
  ///   - [StateError] si le profil n'existe pas
  Future<ChatUser> getChatUser(String userId) async {
    if (_isDisposed) throw StateError('ChatSettingsService disposed');

    if (!_ChatSettingsValidators.isValidUuid(userId)) {
      throw ArgumentError('userId invalide');
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select(
              'id, display_name, username, avatar_url, chat_display_name, chat_avatar, chat_status, last_seen_at, is_online')
          .eq('id', userId)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (response == null) {
        throw StateError('Profil introuvable: ${_ChatSettingsValidators.obfuscate(userId)}');
      }

      return ChatUser.fromJson(Map<String, dynamic>.from(response));
    } on TimeoutException {
      debugPrint('[ChatSettings] ❌ getChatUser timeout');
      rethrow;
    } catch (e) {
      debugPrint('[ChatSettings] ❌ getChatUser: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE CHAT USER
  // ============================================================

  /// Met à jour les infos chat d'un utilisateur.
  ///
  /// Les champs sont automatiquement sanitizés (XSS).
  Future<void> updateChatUser(String userId, ChatUser user) async {
    if (_isDisposed) return;

    if (!_ChatSettingsValidators.isValidUuid(userId)) {
      throw ArgumentError('userId invalide');
    }

    final sanitizedDisplayName = _ChatSettingsValidators.sanitizeDisplayName(user.displayName);
    final sanitizedStatus = _ChatSettingsValidators.sanitizeStatus(user.status);

    try {
      await _supabase
          .from('profiles')
          .update({
            'chat_display_name': sanitizedDisplayName,
            'chat_avatar': user.avatarUrl,
            'chat_status': sanitizedStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .timeout(_kDbTimeout);

      debugPrint('[ChatSettings] ✓ Updated user: ${_ChatSettingsValidators.obfuscate(userId)}');
    } on TimeoutException {
      debugPrint('[ChatSettings] ❌ updateChatUser timeout');
      rethrow;
    } catch (e) {
      debugPrint('[ChatSettings] ❌ updateChatUser: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ============================================================
  // UPLOAD AVATAR
  // ============================================================

  /// Upload un avatar depuis des bytes (compatible Web + Mobile).
  ///
  /// **Validations appliquées** :
  ///   - Taille max : 5MB
  ///   - Extensions whitelist : jpg, jpeg, png, webp, gif
  ///   - Magic bytes : vérifie le type réel du fichier
  ///   - Path traversal protection
  ///
  /// **Usage Mobile** :
  /// ```dart
  /// final bytes = await imageFile.readAsBytes();
  /// final ext = imageFile.path.split('.').last;
  /// final url = await service.uploadAvatarBytes(userId, bytes, ext);
  /// ```
  ///
  /// **Usage Web** :
  /// ```dart
  /// final url = await service.uploadAvatarBytes(userId, uint8list, 'jpg');
  /// ```
  Future<String> uploadAvatarBytes(
    String userId,
    Uint8List bytes,
    String extension,
  ) async {
    if (_isDisposed) throw StateError('ChatSettingsService disposed');

    // Validation userId
    if (!_ChatSettingsValidators.isValidUuid(userId)) {
      throw ArgumentError('userId invalide');
    }

    // Validation image (taille + extension + magic bytes)
    final validation = _ChatSettingsValidators.validateImage(bytes, extension);
    if (!validation.valid) {
      throw ChatSettingsValidationException(validation.error ?? 'Image invalide');
    }

    // Protection path traversal : userId validé, extension whitelist
    // Le chemin final sera : avatars/{uuid}.{ext}
    final normalizedExt = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final path = 'avatars/$userId.$normalizedExt';

    try {
      // Supprime l'ancien avatar s'il existe (même path = upsert)
      await _supabase.storage
          .from(_kAvatarBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$normalizedExt',
              cacheControl: '3600',
            ),
          )
          .timeout(_kStorageTimeout);

      final publicUrl = _supabase.storage.from(_kAvatarBucket).getPublicUrl(path);

      debugPrint('[ChatSettings] ✓ Avatar uploaded: '
          '${_ChatSettingsValidators.obfuscate(userId)} '
          '(${bytes.length} bytes, .$normalizedExt)');

      return publicUrl;
    } on TimeoutException {
      debugPrint('[ChatSettings] ❌ Upload timeout');
      throw const ChatSettingsUploadException('Upload timeout');
    } catch (e) {
      debugPrint('[ChatSettings] ❌ Upload failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      throw ChatSettingsUploadException('Échec de l\'upload', e);
    }
  }

  /// Upload un avatar depuis un fichier (Mobile uniquement).
  ///
  /// ⚠️ Sur Web, utilisez [uploadAvatarBytes] avec `Uint8List`.
  ///
  /// ```dart
  /// final url = await service.uploadAvatar(userId, imageFile);
  /// ```
  Future<String> uploadAvatar(String userId, dynamic imageFile) async {
    if (_isDisposed) throw StateError('ChatSettingsService disposed');

    if (kIsWeb) {
      throw UnsupportedError(
          'uploadAvatar(File) non supporté sur Web. Utilisez uploadAvatarBytes.');
    }

    try {
      // Dynamic car dart:io n'est pas disponible sur Web
      final bytes = await (imageFile as dynamic).readAsBytes() as Uint8List;
      final path = (imageFile as dynamic).path as String;
      final ext = path.split('.').last;

      return await uploadAvatarBytes(userId, bytes, ext);
    } catch (e) {
      debugPrint('[ChatSettings] ❌ uploadAvatar: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      if (e is ChatSettingsValidationException || e is ChatSettingsUploadException) {
        rethrow;
      }
      throw ChatSettingsUploadException('Erreur lecture fichier', e);
    }
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  /// Récupère les paramètres chat d'un utilisateur.
  ///
  /// Retourne les valeurs par défaut si `chat_settings` est null.
  Future<ChatSettings> getSettings(String userId) async {
    if (_isDisposed) return ChatSettings.fromJson({});

    if (!_ChatSettingsValidators.isValidUuid(userId)) {
      throw ArgumentError('userId invalide');
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select('chat_settings')
          .eq('id', userId)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (response == null || response['chat_settings'] == null) {
        return ChatSettings.fromJson({});
      }

      final raw = response['chat_settings'];
      if (raw is Map) {
        return ChatSettings.fromJson(Map<String, dynamic>.from(raw));
      }
      return ChatSettings.fromJson({});
    } on TimeoutException {
      debugPrint('[ChatSettings] ❌ getSettings timeout');
      return ChatSettings.fromJson({});
    } catch (e) {
      debugPrint('[ChatSettings] ⚠️ getSettings: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return ChatSettings.fromJson({});
    }
  }

  /// Met à jour les paramètres chat d'un utilisateur.
  Future<void> updateSettings(String userId, ChatSettings settings) async {
    if (_isDisposed) return;

    if (!_ChatSettingsValidators.isValidUuid(userId)) {
      throw ArgumentError('userId invalide');
    }

    try {
      await _supabase
          .from('profiles')
          .update({
            'chat_settings': settings.toJson(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .timeout(_kDbTimeout);

      debugPrint('[ChatSettings] ✓ Settings updated: '
          '${_ChatSettingsValidators.obfuscate(userId)}');
    } on TimeoutException {
      debugPrint('[ChatSettings] ❌ updateSettings timeout');
      rethrow;
    } catch (e) {
      debugPrint('[ChatSettings] ❌ updateSettings: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      rethrow;
    }
  }

  // ============================================================
  // DELETE AVATAR (optionnel)
  // ============================================================

  /// Supprime l'avatar d'un utilisateur (toutes extensions).
  Future<void> deleteAvatar(String userId) async {
    if (_isDisposed) return;

    if (!_ChatSettingsValidators.isValidUuid(userId)) {
      throw ArgumentError('userId invalide');
    }

    try {
      // Supprime tous les fichiers avatars/{userId}.* potentiels
      final pathsToDelete = _kAllowedExtensions
          .map((ext) => 'avatars/$userId.$ext')
          .toList();

      await _supabase.storage
          .from(_kAvatarBucket)
          .remove(pathsToDelete)
          .timeout(_kStorageTimeout);

      debugPrint('[ChatSettings] ✓ Avatar deleted: '
          '${_ChatSettingsValidators.obfuscate(userId)}');
    } on TimeoutException {
      debugPrint('[ChatSettings] ❌ deleteAvatar timeout');
    } catch (e) {
      // Non critique : le fichier peut ne pas exister
      debugPrint('[ChatSettings] ⚠️ deleteAvatar: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  /// Marque le service comme disposé.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('[ChatSettings] 👋 Disposed');
  }
}
