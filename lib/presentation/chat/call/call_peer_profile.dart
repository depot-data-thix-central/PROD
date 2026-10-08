// lib/presentation/chat/call/call_peer_profile.dart
//
// Récupère le NOM et la PHOTO d'un interlocuteur d'appel depuis `profiles`.
// Utilisé par l'écran d'appel entrant ET par le contrôleur d'appel.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

class CallPeer {
  final String name;
  final String? avatarUrl;
  const CallPeer({required this.name, this.avatarUrl});
}

const Duration _kProfileTimeout = Duration(seconds: 6);
const int _kCacheMax = 60;
final Map<String, CallPeer> _peerCache = <String, CallPeer>{};

final RegExp _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

// Colonnes testées dans l'ordre (adaptées à plusieurs schémas courants)
const List<String> _nameKeys = ['display_name', 'full_name', 'name', 'username', 'thix_chat'];
const List<String> _avatarKeys = [
  'avatar_url', 'photo_url', 'profile_photo_url', 'profile_image_url', 'avatar', 'picture',
];

String _cleanName(dynamic v) {
  final s = (v?.toString() ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .trim();
  return s.length > 100 ? s.substring(0, 100) : s;
}

String? _safeUrl(dynamic v) {
  final t = (v?.toString() ?? '').trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  if (t.isEmpty || t.length > 2048) return null;
  final u = Uri.tryParse(t);
  if (u == null || !u.hasAuthority || (u.scheme != 'http' && u.scheme != 'https')) return null;
  return t;
}

/// Charge nom + photo d'un utilisateur. Retourne null si introuvable.
Future<CallPeer?> fetchCallPeer(SupabaseClient db, String? userId) async {
  if (userId == null || !_uuidRe.hasMatch(userId)) return null;

  final cached = _peerCache[userId];
  if (cached != null) return cached;

  try {
    final row = await db.from('profiles').select().eq('id', userId).maybeSingle().timeout(_kProfileTimeout);
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row as Map);

    var name = '';
    for (final k in _nameKeys) {
      name = _cleanName(map[k]);
      if (name.isNotEmpty) break;
    }

    String? avatar;
    for (final k in _avatarKeys) {
      avatar = _safeUrl(map[k]);
      if (avatar != null) break;
    }

    if (name.isEmpty && avatar == null) return null;

    final peer = CallPeer(name: name, avatarUrl: avatar);
    if (_peerCache.length >= _kCacheMax) _peerCache.remove(_peerCache.keys.first);
    _peerCache[userId] = peer;
    return peer;
  } catch (e) {
    if (kDebugMode) debugPrint('[CallPeer] ⚠️ fetch failed: $e');
    return null;
  }
}

/// Provider pour l'écran d'appel entrant (nom + photo de l'appelant).
final callPeerProvider = FutureProvider.autoDispose.family<CallPeer?, String>((ref, userId) {
  return fetchCallPeer(ref.read(supabaseClientProvider), userId);
});
