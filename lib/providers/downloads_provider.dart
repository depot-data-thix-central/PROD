// lib/providers/downloads_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/news_article.dart';
import '../services/thix_downloader.dart';

@immutable
class DownloadsState {
  final List<DownloadItem> items;
  final bool isLoading;

  const DownloadsState({this.items = const [], this.isLoading = false});

  DownloadsState copyWith({List<DownloadItem>? items, bool? isLoading}) {
    return DownloadsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<DownloadItem> get active =>
      items.where((i) => i.status == DownloadStatus.downloading || i.status == DownloadStatus.pending).toList();

  List<DownloadItem> get completed =>
      items.where((i) => i.status == DownloadStatus.completed).toList();

  List<DownloadItem> get failed =>
      items.where((i) => i.status == DownloadStatus.failed).toList();

  bool isDownloading(String id) =>
      items.any((i) => i.id == id && i.status == DownloadStatus.downloading);

  bool isDownloaded(String id) =>
      items.any((i) => i.id == id && i.status == DownloadStatus.completed);
}

class DownloadsNotifier extends ChangeNotifier {
  DownloadsState _state = const DownloadsState();
  DownloadsState get state => _state;

  /// Lance le téléchargement d'un article (podcast ou vidéo)
  Future<void> downloadArticle(NewsArticle article) async {
    if (_state.isDownloading(article.id) || _state.isDownloaded(article.id)) {
      return;
    }

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

    _state = _state.copyWith(items: [..._state.items, item]);
    notifyListeners();

    final result = await ThixDownloader.instance.download(
      item: item,
      onProgress: (received, total) {
        final idx = _state.items.indexWhere((i) => i.id == article.id);
        if (idx == -1) return;
        final updated = List<DownloadItem>.from(_state.items);
        updated[idx] = updated[idx].copyWith(
          downloadedBytes: received,
          totalBytes: total,
        );
        _state = _state.copyWith(items: updated);
        notifyListeners();
      },
    );

    final idx = _state.items.indexWhere((i) => i.id == article.id);
    if (idx != -1) {
      final updated = List<DownloadItem>.from(_state.items);
      updated[idx] = result;
      _state = _state.copyWith(items: updated);
      notifyListeners();
    }
  }

  Future<void> deleteDownload(String id) async {
    final item = _state.items.firstWhere((i) => i.id == id, orElse: () => throw Exception());
    if (item.localPath != null) {
      await ThixDownloader.instance.delete(item.localPath!);
    }
    _state = _state.copyWith(
      items: _state.items.where((i) => i.id != id).toList(),
    );
    notifyListeners();
  }

  Future<void> retry(String id) async {
    final item = _state.items.firstWhere((i) => i.id == id, orElse: () => throw Exception());
    final idx = _state.items.indexOf(item);
    final updated = List<DownloadItem>.from(_state.items);
    updated[idx] = item.copyWith(status: DownloadStatus.downloading, error: null);
    _state = _state.copyWith(items: updated);
    notifyListeners();

    final result = await ThixDownloader.instance.download(item: item);
    final i2 = _state.items.indexWhere((i) => i.id == id);
    if (i2 != -1) {
      final u2 = List<DownloadItem>.from(_state.items);
      u2[i2] = result;
      _state = _state.copyWith(items: u2);
      notifyListeners();
    }
  }

  String _extensionFromUrl(String url) {
    final u = url.toLowerCase().split('?').first;
    if (u.endsWith('.mp4')) return 'mp4';
    if (u.endsWith('.m3u8')) return 'mp4';
    if (u.endsWith('.mp3')) return 'mp3';
    if (u.endsWith('.wav')) return 'wav';
    if (u.endsWith('.m4a')) return 'm4a';
    if (u.endsWith('.ogg')) return 'ogg';
    return 'mp4'; // default vidéo
  }
}

final downloadsProvider =
    ChangeNotifierProvider<DownloadsNotifier>((ref) => DownloadsNotifier());
