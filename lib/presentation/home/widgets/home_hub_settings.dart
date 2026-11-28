// lib/presentation/home/widgets/home_hub_settings.dart
//
// THIX HUB — réglages globaux de l'accueil (photos de fond, couleurs, vitesse,
// couleur du voile). Table : home_hub_settings (1 ligne, id = 1)
// Bucket : hub_backgrounds · Lecture : tout le monde · Écriture : admin (RLS).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/l10n/app_localizations.dart';

import 'home_theme.dart';

const String kHubBucket = 'hub_backgrounds';
const String kHubTable = 'home_hub_settings';
const int kHubMaxImages = 12;
const int kHubMaxImageBytes = 6 * 1024 * 1024;

/// Traduction avec fallback si la clé n'existe pas.
String hubTr(AppLocalizations l10n, String key, String fallback) {
  final v = l10n.t(key);
  return (v.trim().isEmpty || v == key) ? fallback : v;
}

Color _parseHex(String? s, Color fallback) {
  if (s == null) return fallback;
  var h = s.trim().replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

String _hex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

@immutable
class HubSettings {
  final List<String> images;
  final Color primary;
  final Color accent;
  final Color veilColor; // couleur du voile (blanc par défaut)
  final int intervalSeconds;
  final double veil; // 0..1 : intensité du voile sur la photo
  final bool autoScroll;

  const HubSettings({
    required this.images,
    required this.primary,
    required this.accent,
    required this.veilColor,
    required this.intervalSeconds,
    required this.veil,
    required this.autoScroll,
  });

  static const HubSettings defaults = HubSettings(
    images: <String>[],
    primary: Color(0xFF1746A2),
    accent: Color(0xFFFFB800),
    veilColor: Color(0xFFFFFFFF),
    intervalSeconds: 6,
    veil: 0.55,
    autoScroll: true,
  );

  /// Voile sombre → les textes passent en blanc automatiquement.
  bool get darkVeil => veilColor.computeLuminance() < 0.45;

  /// Couleur des libellés et textes posés sur le voile.
  Color get textColor => darkVeil ? Colors.white : HomeTheme.ink;

  HubSettings copyWith({
    List<String>? images,
    Color? primary,
    Color? accent,
    Color? veilColor,
    int? intervalSeconds,
    double? veil,
    bool? autoScroll,
  }) {
    return HubSettings(
      images: images ?? this.images,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      veilColor: veilColor ?? this.veilColor,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      veil: veil ?? this.veil,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }

  factory HubSettings.fromMap(Map<String, dynamic> m) {
    final raw = m['images'];
    final images = raw is List
        ? raw
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.startsWith('https://'))
            .toList()
        : <String>[];
    final interval =
        ((m['interval_seconds'] as num?)?.toInt() ?? defaults.intervalSeconds)
            .clamp(3, 30)
            .toInt();
    final veil = ((m['veil'] as num?)?.toDouble() ?? defaults.veil)
        .clamp(0.0, 1.0)
        .toDouble();
    return HubSettings(
      images: images,
      primary: _parseHex(m['primary_color'] as String?, defaults.primary),
      accent: _parseHex(m['accent_color'] as String?, defaults.accent),
      veilColor: _parseHex(m['veil_color'] as String?, defaults.veilColor),
      intervalSeconds: interval,
      veil: veil,
      autoScroll: (m['auto_scroll'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': 1,
        'images': images,
        'primary_color': _hex(primary),
        'accent_color': _hex(accent),
        'veil_color': _hex(veilColor),
        'interval_seconds': intervalSeconds,
        'veil': double.parse(veil.toStringAsFixed(2)),
        'auto_scroll': autoScroll,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class HomeHubController extends ChangeNotifier {
  HubSettings _saved = HubSettings.defaults;
  HubSettings? _preview;
  bool _isAdmin = false;

  SupabaseClient get _db => Supabase.instance.client;

  /// Réglages affichés (aperçu en direct si l'admin est en train de modifier).
  HubSettings get settings => _preview ?? _saved;
  HubSettings get saved => _saved;
  bool get isAdmin => _isAdmin;

  Future<void> loadSettings() async {
    try {
      final row = await _db
          .from(kHubTable)
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (row != null) {
        _saved = HubSettings.fromMap(Map<String, dynamic>.from(row));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[HubSettings] ⚠️ load failed (non-critical): $e');
    }
  }

  /// Admin strict : role (ou account_type) == 'admin'.
  Future<void> refreshAdmin() async {
    final user = _db.auth.currentUser;
    var next = false;
    if (user != null) {
      try {
        final data = await _db
            .from('profiles')
            .select('role, account_type')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 15));
        if (data != null) {
          final role = (data['role'] ?? data['account_type'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          next = role == 'admin';
        }
      } catch (e) {
        debugPrint('[HubSettings] ⚠️ admin check failed (non-critical): $e');
      }
    }
    if (next != _isAdmin) {
      _isAdmin = next;
      notifyListeners();
    }
  }

  void setPreview(HubSettings s) {
    _preview = s;
    notifyListeners();
  }

  void clearPreview() {
    if (_preview == null) return;
    _preview = null;
    notifyListeners();
  }

  Future<String> uploadImage(Uint8List bytes, String ext) async {
    final e = ext.toLowerCase();
    final contentType = e == 'png'
        ? 'image/png'
        : e == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    final path = 'bg_${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.$e';
    await _db.storage
        .from(kHubBucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType))
        .timeout(const Duration(seconds: 60));
    return _db.storage.from(kHubBucket).getPublicUrl(path);
  }

  Future<void> save(HubSettings next) async {
    await _db
        .from(kHubTable)
        .upsert(next.toMap())
        .timeout(const Duration(seconds: 20));

    final removed = _saved.images.where((u) => !next.images.contains(u)).toList();
    _saved = next;
    _preview = null;
    notifyListeners();

    final paths = removed.map(_storagePath).whereType<String>().toList();
    if (paths.isNotEmpty) {
      try {
        await _db.storage.from(kHubBucket).remove(paths);
      } catch (e) {
        debugPrint('[HubSettings] ⚠️ storage cleanup failed (non-critical): $e');
      }
    }
  }

  String? _storagePath(String url) {
    const marker = '/$kHubBucket/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    final p = url.substring(i + marker.length).split('?').first;
    return Uri.decodeComponent(p);
  }
}
