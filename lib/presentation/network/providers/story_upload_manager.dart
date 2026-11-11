// lib/presentation/network/providers/story_upload_manager.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:thix_id/features/network/data/network_service_provider.dart';

// ============================================================================
// MODÈLE DE TÂCHE D'UPLOAD STORY
// ============================================================================
enum StoryUploadType { text, image, audio, video }

enum StoryUploadStatus { queued, uploading, success, failed }

class StoryUploadTask {
  StoryUploadTask({
    required this.id,
    required this.type,
    this.text,
    this.bgColor,
    this.filePath,
    this.fileBytes,
    this.fileExt,
    this.mediaType,
    this.status = StoryUploadStatus.queued,
    this.errorMessage,
  });

  final String id;
  final StoryUploadType type;
  final String? text;
  final String? bgColor;
  final String? filePath;
  final Uint8List? fileBytes;
  final String? fileExt;
  final String? mediaType; // 'text', 'image', 'audio', 'video'
  final StoryUploadStatus status;
  final String? errorMessage;

  bool get isFinished =>
      status == StoryUploadStatus.success || status == StoryUploadStatus.failed;

  StoryUploadTask copyWith({StoryUploadStatus? status, String? errorMessage}) {
    return StoryUploadTask(
      id: id,
      type: type,
      text: text,
      bgColor: bgColor,
      filePath: filePath,
      fileBytes: fileBytes,
      fileExt: fileExt,
      mediaType: mediaType,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

// ============================================================================
// GESTIONNAIRE D'UPLOAD STORY (FILE D'ATTENTE GLOBALE)
// ============================================================================
class StoryUploadManager extends Notifier<List<StoryUploadTask>> {
  static const _kUploadTimeout = Duration(seconds: 45);
  bool _isProcessing = false;

  @override
  List<StoryUploadTask> build() => const [];

  bool get isBusy => state.any((t) => !t.isFinished);

  void enqueueText(String text, {String? bgColor}) {
    _add(StoryUploadTask(
      id: _newId(),
      type: StoryUploadType.text,
      text: text,
      bgColor: bgColor,
      mediaType: 'text',
    ));
  }

  void enqueueImage(Uint8List bytes, String ext) {
    _add(StoryUploadTask(
      id: _newId(),
      type: StoryUploadType.image,
      fileBytes: bytes,
      fileExt: ext,
      mediaType: 'image',
    ));
  }

  void enqueueAudio(Uint8List bytes) {
    _add(StoryUploadTask(
      id: _newId(),
      type: StoryUploadType.audio,
      fileBytes: bytes,
      fileExt: 'm4a',
      mediaType: 'audio',
    ));
  }

  void enqueueVideo(Uint8List bytes, String ext) {
    _add(StoryUploadTask(
      id: _newId(),
      type: StoryUploadType.video,
      fileBytes: bytes,
      fileExt: ext,
      mediaType: 'video',
    ));
  }

  void retry(String id) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(status: StoryUploadStatus.queued, errorMessage: null)
        else
          t,
    ];
    _processQueue();
  }

  void clearFinished() {
    state = state.where((t) => !t.isFinished).toList();
  }

  String _newId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${state.length}';

  void _add(StoryUploadTask task) {
    state = [...state, task];
    _processQueue();
  }

  void _update(String id, StoryUploadStatus status, {String? errorMessage}) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(status: status, errorMessage: errorMessage)
        else
          t,
    ];
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      while (true) {
        StoryUploadTask? next;
        for (final t in state) {
          if (t.status == StoryUploadStatus.queued) {
            next = t;
            break;
          }
        }
        if (next == null) break;
        await _upload(next);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _upload(StoryUploadTask task) async {
    _update(task.id, StoryUploadStatus.uploading);
    debugPrint('[StoryUpload] ⬆️ Upload ${task.type.name} (${task.id})...');

    String? uploadedPath; // pour rollback
    try {
      final service = ref.read(networkServiceProvider);
      String? mediaUrl;

      // ── IMAGE ──
      if (task.type == StoryUploadType.image && task.fileBytes != null) {
        mediaUrl = await service
            .uploadImageBytes(
              task.fileBytes!,
              fileExtension: task.fileExt ?? 'jpg',
              bucket: 'stories',
            )
            .timeout(_kUploadTimeout);
      }

      // ── AUDIO : upload storage direct ──
      if (task.type == StoryUploadType.audio && task.fileBytes != null) {
        uploadedPath = 'audio/${const Uuid().v4()}.m4a';
        await Supabase.instance.client.storage
            .from('stories')
            .uploadBinary(
              uploadedPath,
              task.fileBytes!,
              fileOptions: const FileOptions(
                contentType: 'audio/mp4',
                cacheControl: '31536000',
                upsert: false,
              ),
            )
            .timeout(_kUploadTimeout);
        mediaUrl = Supabase.instance.client.storage
            .from('stories')
            .getPublicUrl(uploadedPath);
      }

      // ── VIDÉO : upload storage direct ──
      if (task.type == StoryUploadType.video && task.fileBytes != null) {
        uploadedPath = 'video/${const Uuid().v4()}.${task.fileExt ?? 'mp4'}';
        await Supabase.instance.client.storage
            .from('stories')
            .uploadBinary(
              uploadedPath,
              task.fileBytes!,
              fileOptions: FileOptions(
                contentType: 'video/${task.fileExt ?? 'mp4'}',
                cacheControl: '31536000',
                upsert: false,
              ),
            )
            .timeout(_kUploadTimeout);
        mediaUrl = Supabase.instance.client.storage
            .from('stories')
            .getPublicUrl(uploadedPath);
      }

      // ── CREATE STORY (commun à tous les types) ──
      await service.createStory(
        mediaUrl,
        text: task.text ?? '',
        duration: 24,
        mediaType: task.mediaType ?? 'text',
        bgColor: task.bgColor,
      );

      debugPrint('[StoryUpload] ✓ Upload terminé (${task.id})');
      _update(task.id, StoryUploadStatus.success);
    } catch (e) {
      debugPrint('[StoryUpload] ❌ Erreur: $e');

      // Rollback storage si l'upload a réussi mais createStory a échoué
      try {
        if (uploadedPath != null) {
          await Supabase.instance.client.storage
              .from('stories')
              .remove([uploadedPath]);
        }
      } catch (clean) {
        debugPrint('[StoryUpload] cleanup: $clean');
      }

      _update(task.id, StoryUploadStatus.failed, errorMessage: e.toString());
    }
  }
}

final storyUploadManagerProvider =
    NotifierProvider<StoryUploadManager, List<StoryUploadTask>>(
  StoryUploadManager.new,
);

// ============================================================================
// LISTENER GLOBAL (SNACKBARS SUCCÈS / ÉCHEC + RETRY)
// ============================================================================
class StoryUploadListener extends ConsumerWidget {
  const StoryUploadListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<List<StoryUploadTask>>(storyUploadManagerProvider, (prev, next) {
      final prevMap = {
        for (final t in (prev ?? const <StoryUploadTask>[])) t.id: t.status,
      };

      for (final task in next) {
        final old = prevMap[task.id];
        if (old == null || old == task.status) continue;

        if (task.status == StoryUploadStatus.success) {
          _showSnack(context, '✓ Story publiée', const Color(0xFF16A34A), null, ref);
        } else if (task.status == StoryUploadStatus.failed) {
          _showSnack(
            context,
            '❌ Échec de la publication',
            const Color(0xFFDC2626),
            task.id,
            ref,
          );
        }
      }
    });

    return child;
  }

  void _showSnack(
    BuildContext context,
    String message,
    Color color,
    String? taskId,
    WidgetRef ref,
  ) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          action: taskId == null
              ? null
              : SnackBarAction(
                  label: 'Réessayer',
                  textColor: Colors.white,
                  onPressed: () =>
                      ref.read(storyUploadManagerProvider.notifier).retry(taskId),
                ),
        ),
      );
  }
}
