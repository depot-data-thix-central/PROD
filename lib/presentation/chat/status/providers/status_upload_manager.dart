// lib/presentation/chat/status/providers/status_upload_manager.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/services/chat/status_service.dart';

enum UploadType { text, image, video }
enum UploadStatus { queued, uploading, success, failed }

class UploadTask {
  UploadTask({
    required this.id,
    required this.type,
    this.text,
    this.background,
    this.bytes,
    this.ext,
    this.caption,
    this.status = UploadStatus.queued,
    this.errorMessage,
  });

  final String id;
  final UploadType type;
  final String? text;
  final String? background;
  final Uint8List? bytes;
  final String? ext;
  final String? caption;
  final UploadStatus status;
  final String? errorMessage;

  bool get isFinished =>
      status == UploadStatus.success || status == UploadStatus.failed;

  UploadTask copyWith({UploadStatus? status, String? errorMessage}) {
    return UploadTask(
      id: id,
      type: type,
      text: text,
      background: background,
      bytes: bytes,
      ext: ext,
      caption: caption,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class StatusUploadManager extends Notifier<List<UploadTask>> {
  bool _isProcessing = false;

  @override
  List<UploadTask> build() => const [];

  bool get isBusy => state.any((t) => !t.isFinished);

  void enqueueText(String text, {required String background}) {
    _add(UploadTask(
      id: _newId(),
      type: UploadType.text,
      text: text,
      background: background,
    ));
  }

  void enqueueImage(Uint8List bytes, String ext, {String? caption}) {
    _add(UploadTask(
      id: _newId(),
      type: UploadType.image,
      bytes: bytes,
      ext: ext,
      caption: caption,
    ));
  }

  void enqueueVideo(Uint8List bytes, String ext, {String? caption}) {
    _add(UploadTask(
      id: _newId(),
      type: UploadType.video,
      bytes: bytes,
      ext: ext,
      caption: caption,
    ));
  }

  void retry(String id) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(status: UploadStatus.queued, errorMessage: null)
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

  void _add(UploadTask task) {
    state = [...state, task];
    _processQueue();
  }

  void _update(String id, UploadStatus status, {String? errorMessage}) {
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
        UploadTask? next;
        for (final t in state) {
          if (t.status == UploadStatus.queued) {
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

  Future<void> _upload(UploadTask task) async {
    _update(task.id, UploadStatus.uploading);
    debugPrint('[UploadManager] ⬆️ Upload ${task.type.name} (${task.id})...');

    try {
      bool ok = false;

      switch (task.type) {
        case UploadType.text:
          ok = await ref.read(statusProvider.notifier).createText(
                task.text ?? '',
                background: task.background ?? '#000000',
              );
          break;

        case UploadType.image:
        case UploadType.video:
          final bytes = task.bytes;
          if (bytes == null || bytes.isEmpty) {
            throw Exception('Fichier introuvable');
          }

          final isImage = task.type == UploadType.image;
          final ext = (task.ext ?? (isImage ? 'jpg' : 'mp4')).toLowerCase();
          final service = ref.read(statusServiceProvider);

          final id = isImage
              ? await service.createImageStatus(
                  bytes: bytes,
                  extension: ext,
                  caption: task.caption,
                )
              : await service.createVideoStatus(
                  bytes: bytes,
                  extension: ext,
                  caption: task.caption,
                );

          ok = id != null;
          break;
      }

      if (ok) {
        debugPrint('[UploadManager] ✓ Upload terminé (${task.id})');
        _update(task.id, UploadStatus.success);
        await ref.read(statusProvider.notifier).refresh();
      } else {
        _update(task.id, UploadStatus.failed,
            errorMessage: 'Échec de la publication');
      }
    } catch (e) {
      debugPrint('[UploadManager] ❌ Erreur upload: $e');
      _update(task.id, UploadStatus.failed, errorMessage: e.toString());
    }
  }
}

final statusUploadManagerProvider =
    NotifierProvider<StatusUploadManager, List<UploadTask>>(
  StatusUploadManager.new,
);

class StatusUploadListener extends ConsumerWidget {
  const StatusUploadListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<List<UploadTask>>(statusUploadManagerProvider, (prev, next) {
      final prevMap = {
        for (final t in (prev ?? const <UploadTask>[])) t.id: t.status,
      };

      for (final task in next) {
        final old = prevMap[task.id];
        if (old == null || old == task.status) continue;

        if (task.status == UploadStatus.success) {
          _showSnack(context, '✓ Statut publié', const Color(0xFF16A34A), null, ref);
        } else if (task.status == UploadStatus.failed) {
          _showSnack(
            context,
            '❌ ${task.errorMessage ?? 'Échec de la publication'}',
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
                      ref.read(statusUploadManagerProvider.notifier).retry(taskId),
                ),
        ),
      );
  }
}

class StatusUploadBanner extends ConsumerWidget {
  const StatusUploadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(statusUploadManagerProvider);
    final active = tasks
        .where((t) =>
            t.status == UploadStatus.queued ||
            t.status == UploadStatus.uploading)
        .toList();

    if (active.isEmpty) return const SizedBox.shrink();

    final uploading = active.first.status == UploadStatus.uploading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black87,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              uploading
                  ? 'Publication en cours…'
                  : 'En attente de publication…',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          if (active.length > 1)
            Text('+${active.length - 1}',
                style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
