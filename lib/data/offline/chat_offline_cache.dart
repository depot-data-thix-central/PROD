//lib/data/offline/chat_offline_cache.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class ChatOfflineCache {
  ChatOfflineCache._();
  static final instance = ChatOfflineCache._();

  static const boxName = 'offline_chat';
  static const schema = 1;
  static const maxConversations = 40;
  static const maxMessagesPerConv = 80;
  static const maxBytes = 400 * 1024;
  static const ttl = Duration(days: 7);

  Box get _box => Hive.box(boxName);

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) await Hive.openBox(boxName);
  }

  String _listKey(String uid) => 'list_$uid';
  String _msgKey(String uid, String convId) => 'msg_${uid}_$convId';

  Future<void> saveConversations(String uid, List<Map<String, dynamic>> rows) async {
    if (!_uid(uid)) return;
    final safe = rows.take(maxConversations).map(_plainConv).toList();
    final payload = {
      'v': schema,
      'uid': uid,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'items': safe,
    };
    if (utf8.encode(jsonEncode(payload)).length > maxBytes) return;
    await _box.put(_listKey(uid), payload);
  }

  List<Map<String, dynamic>> readConversations(String uid) {
    final raw = _box.get(_listKey(uid));
    if (raw is! Map) return const [];
    if (raw['uid'] != uid || raw['v'] != schema) return const [];
    final at = DateTime.tryParse('${raw['saved_at']}');
    if (at == null || DateTime.now().toUtc().difference(at) > ttl) return const [];
    final items = raw['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveMessages(
    String uid,
    String convId,
    List<Map<String, dynamic>> rows,
  ) async {
    if (!_uid(uid) || convId.isEmpty) return;
    final safe = rows.take(maxMessagesPerConv).map(_plainMsg).toList();
    await _box.put(_msgKey(uid, convId), {
      'v': schema,
      'uid': uid,
      'conv': convId,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'items': safe,
    });
  }

  List<Map<String, dynamic>> readMessages(String uid, String convId) {
    final raw = _box.get(_msgKey(uid, convId));
    if (raw is! Map) return const [];
    if (raw['uid'] != uid || raw['conv'] != convId) return const [];
    final items = raw['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> clear() async => _box.clear();

  Map<String, dynamic> _plainConv(Map<String, dynamic> c) => {
        'id': '${c['id'] ?? ''}',
        'title': _plain(c['title'] ?? c['name']),
        'last_message': _plain(c['last_message'] ?? c['lastMessage']),
        'updated_at': '${c['updated_at'] ?? c['updatedAt'] ?? ''}',
        'unread_count': c['unread_count'] ?? 0,
      };

  Map<String, dynamic> _plainMsg(Map<String, dynamic> m) => {
        'id': '${m['id'] ?? ''}',
        'conversation_id': '${m['conversation_id'] ?? m['conversationId'] ?? ''}',
        'sender_id': '${m['sender_id'] ?? m['senderId'] ?? ''}',
        'content': _plain(m['content'], max: 2000),
        'type': _plain(m['type'] ?? m['message_type'], max: 24) ?? 'text',
        'created_at': '${m['created_at'] ?? m['createdAt'] ?? ''}',
        'is_deleted': m['is_deleted'] == true,
      };

  static bool _uid(String u) =>
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(u);

  static String? _plain(Object? raw, {int max = 200}) {
    if (raw == null) return null;
    var s = raw.toString()
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .replaceAll(RegExp(r'[<>]'), '')
        .trim();
    if (s.isEmpty) return null;
    if (s.length > max) s = s.substring(0, max);
    return s;
  }
}
