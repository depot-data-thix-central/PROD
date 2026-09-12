// lib/providers/downloads_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/news_article.dart';
import '../services/thix_downloader.dart';

class DownloadsNotifier extends ChangeNotifier {
  final List<DownloadItem> _items = [];
  bool _isLoading = false;

  // ─── GETTERS EXPOSÉS DIRECTEMENT (API simple) ───
  List<DownloadItem> get items => _items;
  bool get isLoading => _isLoading;

  List<DownloadItem> get active =>
      _items.where((i) =>
          i.status == DownloadStatus.downloading ||
          i.status == DownloadStatus.pending).toList();

  List<DownloadItem> get completed =>
      _items.where((i) => i.status == DownloadStatus.completed).toList();

  List<DownloadItem> get failed =>
      _items.where((i) => i.status == DownloadStatus.failed).toList();

  bool isDownloading(String id) =>
      _items.any((i) => i.id == id && i.status == DownloadStatus.downloading);

  bool isDownloaded(String id) =>
      _items.any((i) => i.id == id && i.status == DownloadStatus.completed);

  DownloadItem? findById(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── ACTIONS ───
  Future<void> downloadArticle(NewsArticle article) async {
    if (isDownloading(article.id) || isDownloaded(article.id)) return;

    final mediaType = article.videoUrl != null ? 'video' : 'podcast';
    final url = article.videoUrl ?? '';
    if (url.isEmpty) return;

    final ext = _extensionFromUrl(url);
    final fileName = '${article.id}.$ext';

    final item = DownloadItem(
      id: article.id,
      title: article.title,
      url: url,
      fileName: fileName,
      imageUrl: article.imageUrl,
      mediaType: mediaType,
      categoryId: article.category,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
    );

    _items.add(item);
    notifyListeners();

    final result = await ThixDownloader.instance.download(
      item: item,
      onProgress: (received, total) {
        final idx = _items.indexWhere((i) => i.id == article.id);
        if (idx == -1) return;
        _items[idx] = _items[idx].copyWith(
          downloadedBytes: received,
          totalBytes: total,
        );
        notifyListeners();
      },
    );

    final idx = _items.indexWhere((i) => i.id == article.id);
    if (idx != -1) {
      _items[idx] = result;
      notifyListeners();
    }
  }

  Future<void> deleteDownload(String id) async {
    final item = findById(id);
    if (item == null) return;
    if (item.localPath != null) {
      await ThixDownloader.instance.delete(item.localPath!);
    }
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Future<void> retry(String id) async {
    final item = findById(id);
    if (item == null) return;
    final idx = _items.indexOf(item);
    _items[idx] = item.copyWith(status: DownloadStatus.downloading, error: null);
    notifyListeners();

    final result = await ThixDownloader.instance.download(item: item);
    final i2 = _items.indexWhere((i) => i.id == id);
    if (i2 != -1) {
      _items[i2] = result;
      notifyListeners();
    }
  }

  String _extensionFromUrl(String url) {
    final u = url.toLowerCase().split('?').first;
    if (u.endsWith('.mp3')) return 'mp3';
    if (u.endsWith('.wav')) return 'wav';
    if (u.endsWith('.m4a')) return 'm4a';
    if (u.endsWith('.ogg')) return 'ogg';
    if (u.endsWith('.mp4')) return 'mp4';
    if (u.endsWith('.m3u8')) return 'mp4';
    return 'mp4';
  }
}

final downloadsProvider =
    ChangeNotifierProvider<DownloadsNotifier>((ref) => DownloadsNotifier());
