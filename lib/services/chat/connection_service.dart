
// ============================================================
// lib/services/chat/connection_service.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── MODÈLES ──────────────────────────────────────────────────

class ConnectionRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final Map<String, dynamic>? sender;
  final Map<String, dynamic>? receiver;

  ConnectionRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.message,
    required this.createdAt,
    this.respondedAt,
    this.sender,
    this.receiver,
  });

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    return ConnectionRequest(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      status: json['status'] ?? 'pending',
      message: json['message'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
      sender: json['sender'],
      receiver: json['receiver'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}

class Connection {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;

  Connection({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] ?? '',
      user1Id: json['user1_id'] ?? '',
      user2Id: json['user2_id'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// ─── SERVICE ──────────────────────────────────────────────────

class ConnectionService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ConnectionRequest> _sentRequests = [];
  List<ConnectionRequest> _receivedRequests = [];
  List<Map<String, dynamic>> _connections = [];
  bool _isLoading = false;
  String? _error;

  // ─── GETTERS ────────────────────────────────────────────────

  List<ConnectionRequest> get sentRequests => _sentRequests;
  List<ConnectionRequest> get receivedRequests => _receivedRequests;
  List<Map<String, dynamic>> get connections => _connections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── CHARGEMENT & PAGINATION ────────────────────────────────

  Future<void> loadData(String userId, {int limit = 20, int offset = 0}) async {
    _setLoading(true);
    _error = null;

    try {
      final sent = await _getSentRequests(userId);
      final received = await _getPendingRequests(userId);
      final active = await _getActiveConnections(userId, limit: limit, offset: offset);

      _sentRequests = sent;
      _receivedRequests = received;
      
      if (offset == 0) {
        _connections = active;
      } else {
        _connections.addAll(active);
      }
      
      _setLoading(false);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> loadMoreConnections(String userId, {required int offset, required int limit}) async {
    try {
      final moreActive = await _getActiveConnections(userId, limit: limit, offset: offset);
      _connections.addAll(moreActive);
      notifyListeners();
      return moreActive;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // ─── REQUÊTES PRIVÉES ───────────────────────────────────────

  Future<List<ConnectionRequest>> _getPendingRequests(String userId) async {
    final response = await _supabase
        .from('connection_requests')
        .select('*, sender:profiles!sender_id(id, display_name, username, avatar_url)')
        .eq('receiver_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return response.map((json) => ConnectionRequest.fromJson(json)).toList();
  }

  Future<List<ConnectionRequest>> _getSentRequests(String userId) async {
    final response = await _supabase
        .from('connection_requests')
        .select('*, receiver:profiles!receiver_id(id, display_name, username, avatar_url)')
        .eq('sender_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return response.map((json) => ConnectionRequest.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> _getActiveConnections(String userId, {int limit = 20, int offset = 0}) async {
    final response = await _supabase
        .from('connections')
        .select('''
          id,
          user1_id,
          user2_id,
          user1:profiles!connections_user1_id_fkey(id, display_name, username, avatar_url),
          user2:profiles!connections_user2_id_fkey(id, display_name, username, avatar_url)
        ''')
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .range(offset, offset + limit - 1); // Pagination Supabase

    final List<Map<String, dynamic>> connectionsList = [];
    for (var row in response) {
      final isUser1 = row['user1_id'] == userId;
      final other = isUser1 ? row['user2'] : row['user1'];
      if (other != null) {
        connectionsList.add({
          'id': row['id'],
          'user_id': other['id'],
          'display_name': other['display_name'] ?? 'Inconnu',
          'username': other['username'],
          'avatar_url': other['avatar_url'],
        });
      }
    }
    return connectionsList;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ─── MÉTHODES PUBLIQUES ────────────────────────────────────

  Future<bool> sendRequest({
    required String senderId,
    required String receiverId,
    String? message,
  }) async {
    if (senderId == receiverId) {
      _error = 'Impossible de s\'envoyer une demande à soi-même';
      notifyListeners();
      return false;
    }
    try {
      final existing1 = await _supabase
          .from('connection_requests')
          .select()
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId)
          .maybeSingle();

      final existing2 = await _supabase
          .from('connection_requests')
          .select()
          .eq('sender_id', receiverId)
          .eq('receiver_id', senderId)
          .maybeSingle();

      final existing = existing1 ?? existing2;

      if (existing != null) {
        await _supabase
            .from('connection_requests')
            .update({
              'status': 'pending',
              'message': message,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
        await loadData(senderId);
        return true;
      }

      final data = {
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message': message,
        'status': 'pending',
      };
      await _supabase
          .from('connection_requests')
          .insert(data)
          .select()
          .single();
      await loadData(senderId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('❌ sendRequest error: $e');
      return false;
    }
  }

  Future<bool> acceptRequest(String requestId, String userId) async {
    try {
      final request = await _supabase
          .from('connection_requests')
          .select()
          .eq('id', requestId)
          .single();

      await _supabase
          .from('connection_requests')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      final ids = [request['sender_id'], request['receiver_id']]..sort();
      await _supabase
          .from('connections')
          .insert({
            'user1_id': ids[0],
            'user2_id': ids[1],
          });

      await loadData(userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRequest(String requestId, String userId) async {
    try {
      await _supabase
          .from('connection_requests')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      await loadData(userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId, String userId) async {
    try {
      await _supabase
          .from('connection_requests')
          .delete()
          .eq('id', requestId);
      await loadData(userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ NOUVEAU : Supprimer une connexion du réseau
  Future<bool> removeConnection(String currentUserId, String otherUserId) async {
    try {
      await _supabase
          .from('connections')
          .delete()
          .or('and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)');
      
      await loadData(currentUserId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('❌ Erreur removeConnection: $e');
      return false;
    }
  }

  // ✅ NOUVEAU : Bloquer un utilisateur
  Future<bool> blockUser(String currentUserId, String otherUserId) async {
    try {
      // Appel de la fonction SQL intelligente
      await _supabase.rpc(
        'block_user_and_clean',
        params: {
          'blocker': currentUserId,
          'blocked': otherUserId,
        },
      );
      
      await loadData(currentUserId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('❌ Erreur blockUser: $e');
      return false;
    }
  }

  Future<bool> checkConnection(String userId1, String userId2) async {
    if (userId1 == userId2) return false;
    try {
      final response1 = await _supabase
          .from('connections')
          .select('id')
          .eq('user1_id', userId1)
          .eq('user2_id', userId2)
          .maybeSingle();

      if (response1 != null) return true;

      final response2 = await _supabase
          .from('connections')
          .select('id')
          .eq('user1_id', userId2)
          .eq('user2_id', userId1)
          .maybeSingle();

      return response2 != null;
    } catch (e) {
      debugPrint('❌ checkConnection error: $e');
      return false;
    }
  }

  Future<String> getStatusBetween(String userId1, String userId2) async {
    if (userId1 == userId2) return 'self';
    try {
      // 1. Vérifier si un blocage existe (dans les deux sens)
      final blockCheck = await _supabase
          .from('blocked_users')
          .select('id')
          .or('and(blocker_id.eq.$userId1,blocked_id.eq.$userId2),and(blocker_id.eq.$userId2,blocked_id.eq.$userId1)')
          .maybeSingle();
      if (blockCheck != null) return 'blocked';

      final conn1 = await _supabase
          .from('connections')
          .select('id')
          .eq('user1_id', userId1)
          .eq('user2_id', userId2)
          .maybeSingle();
      if (conn1 != null) return 'connected';

      final conn2 = await _supabase
          .from('connections')
          .select('id')
          .eq('user1_id', userId2)
          .eq('user2_id', userId1)
          .maybeSingle();
      if (conn2 != null) return 'connected';

      final pending1 = await _supabase
          .from('connection_requests')
          .select('status')
          .eq('sender_id', userId1)
          .eq('receiver_id', userId2)
          .eq('status', 'pending')
          .maybeSingle();
      if (pending1 != null) return 'pending';

      final pending2 = await _supabase
          .from('connection_requests')
          .select('status')
          .eq('sender_id', userId2)
          .eq('receiver_id', userId1)
          .eq('status', 'pending')
          .maybeSingle();
      if (pending2 != null) return 'pending';

      final rejected1 = await _supabase
          .from('connection_requests')
          .select('status')
          .eq('sender_id', userId1)
          .eq('receiver_id', userId2)
          .eq('status', 'rejected')
          .maybeSingle();
      if (rejected1 != null) return 'rejected';

      final rejected2 = await _supabase
          .from('connection_requests')
          .select('status')
          .eq('sender_id', userId2)
          .eq('receiver_id', userId1)
          .eq('status', 'rejected')
          .maybeSingle();
      if (rejected2 != null) return 'rejected';

      return 'none';
    } catch (e) {
      debugPrint('❌ getStatusBetween error: $e');
      return 'none';
    }
  }
}
