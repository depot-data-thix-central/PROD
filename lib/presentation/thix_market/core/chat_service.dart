// lib/presentation/thix_market/core/chat_service.dart
// ============================================================================
// CHAT SERVICE — Production
// ----------------------------------------------------------------------------
//  • Création / récupération de conversation acheteur <-> vendeur
//  • Envoi texte + carte produit (référence produit)
//  • Temps réel (stream), lecture, indicateur de saisie
//  • Tolérant au schéma : colonne message/content, participant_ids ou
//    conversation_participants
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Duration _kTimeout = Duration(seconds: 15);
final RegExp _uuidLike = RegExp(r'^[0-9a-fA-F-]{8,}$');

class ChatException implements Exception {
  /// not_logged_in | self_chat | no_seller | failed
  final String code;
  final String message;
  const ChatException(this.code, [this.message = '']);

  @override
  String toString() => 'ChatException($code): $message';
}

/// Référence produit embarquée dans un message.
class ProductRef {
  final String id;
  final String title;
  final double? price;
  final String currencyCode;
  final String? imageUrl;
  final String? shopId;

  const ProductRef({
    required this.id,
    this.title = '',
    this.price,
    this.currencyCode = 'CDF',
    this.imageUrl,
    this.shopId,
  });

  factory ProductRef.fromContext(Map<String, dynamic> c) {
    return ProductRef(
      id: c['id']?.toString() ?? '',
      title: c['title']?.toString() ?? '',
      price: (c['price'] as num?)?.toDouble(),
      currencyCode: (c['currency_code'] ?? c['currency'] ?? 'CDF').toString(),
      imageUrl: c['image_url']?.toString(),
      shopId: c['shop_id']?.toString(),
    );
  }

  String toToken() {
    final title80 = title.length > 80 ? title.substring(0, 80) : title;
    final img = (imageUrl != null && imageUrl!.length <= 400) ? imageUrl : null;
    final map = <String, dynamic>{
      'i': id,
      't': title80,
      if (price != null) 'p': price,
      'c': currencyCode,
      if (img != null) 'm': img,
      if (shopId != null) 's': shopId,
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
    return '[PRODUCT_REF:$encoded]';
  }

  static ProductRef? tryParseToken(String token) {
    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(token)));
      final json = jsonDecode(decoded);
      if (json is Map && json['i'] != null) {
        return ProductRef(
          id: json['i'].toString(),
          title: json['t']?.toString() ?? '',
          price: (json['p'] as num?)?.toDouble(),
          currencyCode: json['c']?.toString() ?? 'CDF',
          imageUrl: json['m']?.toString(),
          shopId: json['s']?.toString(),
        );
      }
    } catch (_) {
      // ancien format : [PRODUCT_REF:<uuid>]
    }
    if (_uuidLike.hasMatch(token)) return ProductRef(id: token);
    return null;
  }
}

class ParsedMessage {
  final ProductRef? product;
  final String text;
  const ParsedMessage(this.product, this.text);
}

class ChatService {
  ChatService(this._db);
  final SupabaseClient _db;

  static int _variant = 0;
  static final RegExp _tokenRegex = RegExp(r'^\s*\[PRODUCT_REF:([A-Za-z0-9_\-]+)\]\s*');

  String? get currentUserId => _db.auth.currentUser?.id;

  // ───────────────────────── HELPERS STATIQUES ─────────────────────────

  /// Sépare la référence produit éventuelle du texte (à appeler AVANT sanitisation).
  static ParsedMessage parse(String raw) {
    final m = _tokenRegex.firstMatch(raw);
    if (m == null) return ParsedMessage(null, raw);
    final ref = ProductRef.tryParseToken(m.group(1)!);
    return ParsedMessage(ref, raw.substring(m.end));
  }

  /// Retrouve l'id utilisateur du vendeur depuis la boutique / le produit.
  /// Si ta colonne propriétaire a un autre nom, ajoute-la dans cette liste.
  static String? sellerIdFrom(Map<String, dynamic> product, Map<String, dynamic>? shop) {
    final candidates = <dynamic>[
      shop?['owner_id'],
      shop?['user_id'],
      shop?['seller_id'],
      shop?['owner'],
      product['seller_id'],
      product['owner_id'],
      product['user_id'],
    ];
    for (final c in candidates) {
      final s = c?.toString();
      if (s != null && _uuidLike.hasMatch(s)) return s;
    }
    return null;
  }

  static bool _isSchemaError(PostgrestException e) {
    final code = e.code ?? '';
    return code == '42703' || code == '42P01' || code == 'PGRST204' || code == 'PGRST205';
  }

  // ───────────────────────── CONVERSATION ─────────────────────────

  Future<String> getOrCreateConversation({required String otherUserId}) async {
    final me = currentUserId;
    if (me == null) throw const ChatException('not_logged_in');
    if (otherUserId.isEmpty) throw const ChatException('no_seller');
    if (otherUserId == me) throw const ChatException('self_chat');

    try {
      return await _viaParticipantIds(me, otherUserId);
    } on PostgrestException catch (e) {
      debugPrint('[ChatService] participant_ids path: ${e.code} ${e.message}');
      if (!_isSchemaError(e)) throw ChatException('failed', e.message);
    }

    try {
      return await _viaParticipantsTable(me, otherUserId);
    } on PostgrestException catch (e) {
      debugPrint('[ChatService] participants table path: ${e.code} ${e.message}');
      throw ChatException('failed', e.message);
    }
  }

  Future<String> _viaParticipantIds(String me, String other) async {
    final rows = await _db
        .from('conversations')
        .select('id, participant_ids')
        .contains('participant_ids', [me, other])
        .limit(10)
        .timeout(_kTimeout);

    for (final r in List<Map<String, dynamic>>.from(rows)) {
      final ids = r['participant_ids'];
      if (ids is List && ids.length == 2) return r['id'].toString();
    }

    final created = await _db
        .from('conversations')
        .insert({
          'participant_ids': [me, other],
        })
        .select('id')
        .single()
        .timeout(_kTimeout);
    return created['id'].toString();
  }

  Future<String> _viaParticipantsTable(String me, String other) async {
    final mine = await _db
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', me)
        .timeout(_kTimeout);
    final myIds = List<Map<String, dynamic>>.from(mine)
        .map((r) => r['conversation_id'].toString())
        .toList();

    if (myIds.isNotEmpty) {
      final shared = await _db
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', other)
          .inFilter('conversation_id', myIds)
          .limit(1)
          .timeout(_kTimeout);
      if (shared.isNotEmpty) return shared.first['conversation_id'].toString();
    }

    final conv = await _db.from('conversations').insert({}).select('id').single().timeout(_kTimeout);
    final id = conv['id'].toString();
    await _db.from('conversation_participants').insert([
      {'conversation_id': id, 'user_id': me},
      {'conversation_id': id, 'user_id': other},
    ]).timeout(_kTimeout);
    return id;
  }

  // ───────────────────────── MESSAGES ─────────────────────────

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(150);
  }

  Future<void> sendText(String conversationId, String text) {
    return _insert(conversationId, text, preview: text);
  }

  Future<void> sendProduct(String conversationId, ProductRef ref) {
    final preview = ref.title.isEmpty ? '📦 Produit' : '📦 ${ref.title}';
    return _insert(conversationId, ref.toToken(), preview: preview);
  }

  Future<void> _insert(String conversationId, String content, {required String preview}) async {
    final uid = currentUserId;
    if (uid == null) throw const ChatException('not_logged_in');

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final variants = <Map<String, dynamic>>[
      {'message': content},
      {'content': content},
      {'content': content, 'type': 'text'},
    ];

    Object? last;
    var sent = false;
    for (var i = 0; i < variants.length; i++) {
      final idx = (_variant + i) % variants.length;
      try {
        await _db.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': uid,
          'created_at': nowIso,
          ...variants[idx],
        }).timeout(_kTimeout);
        _variant = idx;
        sent = true;
        break;
      } on PostgrestException catch (e) {
        last = e;
        if (!_isSchemaError(e)) throw ChatException('failed', e.message);
      }
    }
    if (!sent) throw ChatException('failed', last?.toString() ?? '');

    // Aperçu dans la liste des conversations (best effort : un trigger peut déjà le faire)
    try {
      final p = preview.length > 120 ? preview.substring(0, 120) : preview;
      await _db
          .from('conversations')
          .update({'last_message': p, 'last_message_time': nowIso}).eq('id', conversationId);
    } catch (e) {
      debugPrint('[ChatService] last_message update skipped: $e');
    }
  }

  Future<void> markRead(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _db
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', uid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[ChatService] markRead(messages) skipped: $e');
    }
    try {
      await _db
          .from('conversation_participants')
          .update({'unread_count': 0, 'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .match({'conversation_id': conversationId, 'user_id': uid});
    } catch (e) {
      debugPrint('[ChatService] markRead(participants) skipped: $e');
    }
  }

  // ───────────────────────── SAISIE (broadcast) ─────────────────────────

  RealtimeChannel subscribeTyping(
    String conversationId,
    void Function(String userId, bool isTyping) onTyping,
  ) {
    final channel = _db.channel('typing:$conversationId');
    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final data = payload['payload'] is Map ? Map<String, dynamic>.from(payload['payload'] as Map) : payload;
        final uid = data['user_id']?.toString();
        if (uid == null) return;
        onTyping(uid, data['is_typing'] == true);
      },
    ).subscribe();
    return channel;
  }

  Future<void> sendTyping(RealtimeChannel channel, bool isTyping) async {
    try {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': currentUserId, 'is_typing': isTyping},
      );
    } catch (e) {
      debugPrint('[ChatService] typing send skipped: $e');
    }
  }

  Future<void> disposeChannel(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      await _db.removeChannel(channel);
    } catch (_) {}
  }
}
