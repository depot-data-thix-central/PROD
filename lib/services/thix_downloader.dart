// lib/services/thix_downloader.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 📥 Statut d'un téléchargement
enum DownloadStatus { pending, downloading, completed, failed, paused }

/// 📦 Métadonnées d'un téléchargement
class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String fileName;
  final String? imageUrl;
  final String mediaType; // podcast | video | magazine
  final String? categoryId;
  final DownloadStatus status;
  final int totalBytes;
  final int downloadedBytes;
  final String? localPath;
  final String? error;
  final DateTime createdAt;

  const DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.fileName,
    this.imageUrl,
    required this.mediaType,
    this.categoryId,
    required this.status,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.localPath,
    this.error,
    required this.createdAt,
  });

  double get progress =>
      totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  String get progressLabel {
    if (totalBytes == 0) return '…';
    final mb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final total = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mb / $total MB';
  }

  String get sizeLabel {
    if (totalBytes == 0) return '';
    final mb = totalBytes / (1024 * 1024);
    return mb < 1
        ? '${(totalBytes / 1024).toStringAsFixed(0)} KB'
        : '${mb.toStringAsFixed(1)} MB';
  }

  DownloadItem copyWith({
    DownloadStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    String? localPath,
    String? error,
  }) {
    return DownloadItem(
      id: id,
      title: title,
      url: url,
      fileName: fileName,
      imageUrl: imageUrl,
      mediaType: mediaType,
      categoryId: categoryId,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
      createdAt: createdAt,
    );
  }
}

/// 📥 Service de téléchargement de médias (audio/vidéo)
class ThixDownloader {
  ThixDownloader._();
  static final ThixDownloader instance = ThixDownloader._();

  /// Répertoire racine des téléchargements THIX
  Future<Directory> _baseDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/thix_downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Dossier spécifique par type de média
  Future<Directory> _mediaDir(String mediaType) async {
    final base = await _baseDir();
    final dir = Directory('${base.path}/$mediaType');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Télécharge un fichier avec progression
  /// Retourne le chemin local en cas de succès, null sinon
  Future<DownloadItem> download({
    required DownloadItem item,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await _mediaDir(item.mediaType);
      final file = File('${dir.path}/${item.fileName}');

      final req = http.Request('GET', Uri.parse(item.url));
      final client = http.Client();
      final streamed = await client.send(req);

      if (streamed.statusCode != 200) {
        return item.copyWith(
          status: DownloadStatus.failed,
          error: 'HTTP ${streamed.statusCode}',
        );
      }

      final total = streamed.contentLength ?? 0;
      var received = 0;

      final sink = file.openWrite();
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();

      return item.copyWith(
        status: DownloadStatus.completed,
        totalBytes: total,
        downloadedBytes: received,
        localPath: file.path,
      );
    } catch (e) {
      debugPrint('❌ [ThixDownloader] $e');
      return item.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
    }
  }

  /// Supprime un fichier téléchargé
  Future<bool> delete(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si un fichier est déjà téléchargé
  Future<bool> exists(String fileName, String mediaType) async {
    try {
      final dir = await _mediaDir(mediaType);
      final file = File('${dir.path}/$fileName');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  Future<String?> getPath(String fileName, String mediaType) async {
    final dir = await _mediaDir(mediaType);
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return file.path;
    return null;
  }
}
