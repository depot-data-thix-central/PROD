//lib/data/offline/home_offline_cache.dart
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class HomeOfflineCache {
  HomeOfflineCache._();
  static final HomeOfflineCache instance = HomeOfflineCache._();

  static const boxName = 'offline_home';
  static const _key = 'snapshot_v1';
  static const schemaVersion = 1;
  static const maxSnapshotBytes = 80 * 1024; // 80 KB
  static const maxBanners = 8;
  static const maxString = 200;
  static const ttl = Duration(days: 7);

  Box<dynamic> get _box => Hive.box(boxName);

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Future<void> save({
    required String uid,
    String? displayName,
    String? thixId,
    String? certificationTier,
    String? certificationStatus,
    required List<HomeBannerSnap> banners,
  }) async {
    if (!_isUid(uid)) return;

    final snap = <String, dynamic>{
      'v': schemaVersion,
      'uid': uid,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'display_name': _plain(displayName),
      'thix_id': _plain(thixId, max: 64),
      'certification_tier': _token(certificationTier),
      'certification_status': _token(certificationStatus),
      'banners': banners
          .take(maxBanners)
          .map((b) => b.toJson())
          .where((m) => m.isNotEmpty)
          .toList(),
    };

    final encoded = utf8.encode(jsonEncode(snap));
    if (encoded.length > maxSnapshotBytes) return;

    await _box.put(_key, snap);
  }

  HomeSnapshot? read({required String uid}) {
    if (!_isUid(uid)) return null;
    final raw = _box.get(_key);
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    if (map['v'] != schemaVersion) return null;
    if (map['uid']?.toString() != uid) return null;

    final savedAt = DateTime.tryParse('${map['saved_at'] ?? ''}');
    if (savedAt == null) return null;
    if (DateTime.now().toUtc().difference(savedAt) > ttl) return null;

    final banners = <HomeBannerSnap>[];
    final list = map['banners'];
    if (list is List) {
      for (final item in list.take(maxBanners)) {
        if (item is Map) {
          final b = HomeBannerSnap.fromJson(Map<String, dynamic>.from(item));
          if (b != null) banners.add(b);
        }
      }
    }

    return HomeSnapshot(
      uid: uid,
      savedAt: savedAt,
      displayName: _plain(map['display_name']?.toString()),
      thixId: _plain(map['thix_id']?.toString(), max: 64),
      certificationTier: _token(map['certification_tier']?.toString()),
      certificationStatus: _token(map['certification_status']?.toString()),
      banners: banners,
    );
  }

  Future<void> clear() => _box.delete(_key);

  Future<void> clearIfOtherUser(String uid) async {
    final raw = _box.get(_key);
    if (raw is Map && raw['uid']?.toString() != uid) {
      await clear();
    }
  }
}

class HomeSnapshot {
  const HomeSnapshot({
    required this.uid,
    required this.savedAt,
    this.displayName,
    this.thixId,
    this.certificationTier,
    this.certificationStatus,
    this.banners = const [],
  });

  final String uid;
  final DateTime savedAt;
  final String? displayName;
  final String? thixId;
  final String? certificationTier;
  final String? certificationStatus;
  final List<HomeBannerSnap> banners;

  bool get isStale =>
      DateTime.now().toUtc().difference(savedAt) > const Duration(hours: 24);
}

class HomeBannerSnap {
  const HomeBannerSnap({
    required this.imageUrl,
    this.title,
    this.tag,
  });

  final String imageUrl;
  final String? title;
  final String? tag;

  Map<String, dynamic> toJson() {
    if (!_safeHttps(imageUrl)) return {};
    return {
      'image_url': imageUrl,
      'title': _plain(title),
      'tag': _plain(tag, max: 40),
    };
  }

  static HomeBannerSnap? fromJson(Map<String, dynamic> json) {
    final url = json['image_url']?.toString() ?? '';
    if (!_safeHttps(url)) return null;
    return HomeBannerSnap(
      imageUrl: url,
      title: _plain(json['title']?.toString()),
      tag: _plain(json['tag']?.toString(), max: 40),
    );
  }
}

bool _isUid(String uid) =>
    RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(uid);

String? _token(String? raw) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  const allowed = {
    'gratuit',
    'free',
    'standard',
    'premium',
    'entreprise',
    'enterprise',
    'officiel',
    'official',
    'none',
    'pending',
    'approved',
    'rejected',
    'generated',
  };
  return allowed.contains(v) ? v : null;
}

String? _plain(String? raw, {int max = HomeOfflineCache.maxString}) {
  if (raw == null) return null;
  var s = raw
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
      .replaceAll(RegExp(r'[<>]'), '')
      .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
      .replaceAll(RegExp(r'data:', caseSensitive: false), '')
      .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
      .trim();
  if (s.isEmpty) return null;
  if (s.length > max) s = s.substring(0, max);
  return s;
}

bool _safeHttps(String url) {
  final u = Uri.tryParse(url);
  if (u == null || !u.hasScheme || !u.hasAuthority) return false;
  if (u.scheme != 'https') return false;
  if (u.host.isEmpty || u.host.contains(' ')) return false;
  if (u.userInfo.isNotEmpty) return false;
  return true;
}
