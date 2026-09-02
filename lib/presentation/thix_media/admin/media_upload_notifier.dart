/// Media Upload Notifier (Production Enterprise)
/// ✅ i18n + logs structurés + timeouts + mounted checks
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kUploadTimeout = Duration(minutes: 10);
const int _kMaxCoverSizeBytes = 5 * 1024 * 1024;  // 5 MB
const int _kMaxVideoSizeBytes = 500 * 1024 * 1024; // 500 MB

// ============================================================================
// LOGGING
// ============================================================================

class _UploadLogger {
  static const _tag = 'MediaUpload';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// STATE
// ============================================================================

class MediaUploadState {
  final bool saving;
  final double progress;
  final String statusKey; // i18n key
  final Map<String, String> statusArgs;
  final String? errorKey;
  final Map<String, String> errorArgs;

  const MediaUploadState({
    this.saving = false,
    this.progress = 0,
    this.statusKey = '',
    this.statusArgs = const {},
    this.errorKey,
    this.errorArgs = const {},
  });

  MediaUploadState copyWith({
    bool? saving,
    double? progress,
    String? statusKey,
    Map<String, String>? statusArgs,
    String? errorKey,
    Map<String, String>? errorArgs,
    bool clearError = false,
  }) {
    return MediaUploadState(
      saving: saving ?? this.saving,
      progress: progress ?? this.progress,
      statusKey: statusKey ?? this.statusKey,
      statusArgs: statusArgs ?? this.statusArgs,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      errorArgs: clearError ? const {} : (errorArgs ?? this.errorArgs),
    );
  }
}

// ============================================================================
// VALIDATOR
// ============================================================================

class _UploadValidator {
  static void validateCover(PlatformFile? file) {
    if (file == null) return;
    if (file.bytes == null) {
      throw _UploadException('upload_cover_too_large_browser');
    }
    if (file.size > _kMaxCoverSizeBytes) {
      throw _UploadException(
        'upload_file_too_large',
        args: {
          'maxMB': '${(_kMaxCoverSizeBytes / 1024 / 1024).toInt()}',
        },
      );
    }
  }

  static void validateVideo(PlatformFile? file) {
    if (file == null) return;
    if (file.bytes == null) {
      throw _UploadException('upload_video_too_large_browser');
    }
    if (file.size > _kMaxVideoSizeBytes) {
      throw _UploadException(
        'upload_file_too_large',
        args: {
          'maxMB': '${(_kMaxVideoSizeBytes / 1024 / 1024).toInt()}',
        },
      );
    }
  }
}

class _UploadException implements Exception {
  final String key;
  final Map<String, String> args;
  _UploadException(this.key, {this.args = const {}});
}

// ============================================================================
// NOTIFIER
// ============================================================================

final mediaFormUploadProvider = StateNotifierProvider.autoDispose<
    MediaUploadNotifier, MediaUploadState>((ref) {
  return MediaUploadNotifier(ref);
});

class MediaUploadNotifier extends StateNotifier<MediaUploadState> {
  MediaUploadNotifier(this.ref) : super(const MediaUploadState());
  final Ref ref;

  Future<void> save({
    required MediaContent base,
    PlatformFile? coverFile,
    PlatformFile? videoFile,
    required bool isNew,
    required VoidCallback onSaved,
  }) async {
    _UploadLogger.info('Save started', {
      'isNew': isNew,
      'title': base.title,
    });

    // Validation
    try {
      _UploadValidator.validateCover(coverFile);
      _UploadValidator.validateVideo(videoFile);
    } on _UploadException catch (e) {
      _UploadLogger.error('Validation failed', {'key': e.key});
      state = state.copyWith(
        saving: false,
        errorKey: e.key,
        errorArgs: e.args,
      );
      return;
    }

    state = state.copyWith(
      saving: true,
      progress: 0,
      statusKey: 'upload_status_preparing',
      clearError: true,
    );

    try {
      final service = MediaService(client: Supabase.instance.client);
      state = state.copyWith(
        statusKey: 'upload_status_uploading',
        progress: 0.2,
      );

      final operation = isNew
          ? service.insertWithFiles(
              base,
              coverFile: coverFile,
              videoFile: videoFile,
              onProgress: (p) {
                state = state.copyWith(
                  progress: 0.2 + p * 0.7,
                  statusKey: 'upload_status_upload_percent',
                  statusArgs: {'percent': '${(p * 100).toInt()}'},
                );
              },
            )
          : service.updateWithFiles(
              base,
              newCoverFile: coverFile,
              newVideoFile: videoFile,
              onProgress: (p) {
                state = state.copyWith(
                  progress: 0.2 + p * 0.7,
                  statusKey: 'upload_status_update_percent',
                  statusArgs: {'percent': '${(p * 100).toInt()}'},
                );
              },
            );

      await operation.timeout(_kUploadTimeout);

      state = state.copyWith(
        progress: 1,
        statusKey: 'upload_status_finalizing',
      );

      _UploadLogger.info('Save successful', {'id': base.id});
      onSaved();
    } on TimeoutException {
      _UploadLogger.error('Upload timeout');
      state = state.copyWith(
        saving: false,
        errorKey: 'upload_error_timeout',
      );
    } catch (e) {
      _UploadLogger.error('Save failed', {'error': '$e'});
      state = state.copyWith(
        saving: false,
        errorKey: 'upload_error_generic',
        errorArgs: {'error': e.toString()},
      );
    } finally {
      state = state.copyWith(saving: false);
    }
  }
}
